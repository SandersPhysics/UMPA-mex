#include "mex.h"
#include <cmath>
#include <omp.h>

static inline mwSize idx2(mwSize row, mwSize col, mwSize nrows)
{
    return row + col * nrows;
}

static inline mwSize idx3(mwSize row, mwSize col, mwSize page, mwSize nrows, mwSize ncols)
{
    return row + col * nrows + page * nrows * ncols;
}

static inline double clamp_1_3(double x)
{
    return std::fmin(std::fmax(x, 1.0), 3.0);
}

static void require_real_double(const mxArray* arr, const char* name)
{
    if (!mxIsDouble(arr) || mxIsComplex(arr) || mxIsSparse(arr)) {
        mexErrMsgIdAndTxt("umpa_core_mex:InputType",
                          "%s must be a real, full double array.", name);
    }
}

static void require_2d_size(const mxArray* arr, const char* name, mwSize nrows, mwSize ncols)
{
    require_real_double(arr, name);

    if (mxGetM(arr) != nrows || mxGetN(arr) != ncols) {
        mexErrMsgIdAndTxt("umpa_core_mex:ShapeMismatch",
                          "%s must be %zu-by-%zu.", name,
                          static_cast<size_t>(nrows),
                          static_cast<size_t>(ncols));
    }
}

static int get_scalar_int(const mxArray* arr, const char* name)
{
    if (!mxIsNumeric(arr) || mxIsComplex(arr) || mxGetNumberOfElements(arr) != 1) {
        mexErrMsgIdAndTxt("umpa_core_mex:ScalarInput",
                          "%s must be a real numeric scalar.", name);
    }

    return static_cast<int>(mxGetScalar(arr));
}

static double get_scalar_double(const mxArray* arr, const char* name)
{
    if (!mxIsNumeric(arr) || mxIsComplex(arr) || mxGetNumberOfElements(arr) != 1) {
        mexErrMsgIdAndTxt("umpa_core_mex:ScalarInput",
                          "%s must be a real numeric scalar.", name);
    }

    return mxGetScalar(arr);
}

static void minsubpix3x3_core(const double* z, double& loc_col, double& loc_row)
{
    /*
     * z is a 3x3 MATLAB-style column-major loss surface:
     *
     *   z[row + 3*col]
     *
     * This is the C++ version of the fixed 3x3 least-squares quadratic
     * subpixel fit used by the MATLAB path.
     */

    const double z1 = z[0];
    const double z2 = z[1];
    const double z3 = z[2];
    const double z4 = z[3];
    const double z5 = z[4];
    const double z6 = z[5];
    const double z7 = z[6];
    const double z8 = z[7];
    const double z9 = z[8];

    /*
     * Fit:
     *
     *   L(col,row) = a*col^2 + b*row^2 + c*col*row
     *              + d*col + e*row + f
     */

    const double a = ( z1 + z2 + z3
                    - 2.0*z4 - 2.0*z5 - 2.0*z6
                    + z7 + z8 + z9 ) / 6.0;

    const double b = ( z1 - 2.0*z2 + z3
                    + z4 - 2.0*z5 + z6
                    + z7 - 2.0*z8 + z9 ) / 6.0;

    const double c = ( z1 - z3 - z7 + z9 ) / 4.0;

    const double d = (-4.0/3.0)*z1 + (-5.0/6.0)*z2 + (-1.0/3.0)*z3
                   + ( 4.0/3.0)*z4 + ( 4.0/3.0)*z5 + ( 4.0/3.0)*z6
                                      + (-1.0/2.0)*z8 + (-1.0)*z9;

    const double e = (-4.0/3.0)*z1 + ( 4.0/3.0)*z2
                   + (-5.0/6.0)*z4 + ( 4.0/3.0)*z5 + (-1.0/2.0)*z6
                   + (-1.0/3.0)*z7 + ( 4.0/3.0)*z8 + (-1.0)*z9;

    /*
     * Stationary point:
     *
     *   [2a   c ] [col] = [-d]
     *   [ c  2b] [row]   [-e]
     */

    const double det = 4.0*a*b - c*c;

    loc_col = (c*e - 2.0*b*d) / det;
    loc_row = (c*d - 2.0*a*e) / det;
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    /*
     * Inputs:
     *   0 I
     *   1 Io
     *   2 win_I2
     *   3 win_Io2
     *   4 win_IIobar
     *   5 win_IoIobar
     *   6 filter_kern
     *   7 imin
     *   8 imax
     *   9 jmin
     *  10 jmax
     *  11 whalf
     *  12 c2
     *  13 mode_code
     *
     * mode_code:
     *   1 = DF mode
     *   0 = DPC / dark-field-off mode
     *
     * Outputs:
     *   0 attenuation
     *   1 dark-field channel
     *   2 dx_internal
     *   3 dy_internal
     *
     * dx_internal and dy_internal use the internal UMPA sign convention.
     * The MATLAB wrapper applies the final sign flip to match UMPA.m.
     */

    if (nrhs != 14) {
        mexErrMsgIdAndTxt("umpa_core_mex:InputCount",
                          "Expected 14 inputs.");
    }

    if (nlhs != 4) {
        mexErrMsgIdAndTxt("umpa_core_mex:OutputCount",
                          "Expected exactly 4 outputs.");
    }

    require_real_double(prhs[0], "I");
    require_real_double(prhs[1], "Io");

    const mwSize ndI = mxGetNumberOfDimensions(prhs[0]);
    const mwSize* dimsI = mxGetDimensions(prhs[0]);

    if (ndI < 2 || ndI > 3) {
        mexErrMsgIdAndTxt("umpa_core_mex:BadImageShape",
                          "I must be HxW or HxWxK.");
    }

    const mwSize H = dimsI[0];
    const mwSize W = dimsI[1];
    const mwSize K = (ndI >= 3) ? dimsI[2] : 1;

    const mwSize ndIo = mxGetNumberOfDimensions(prhs[1]);
    const mwSize* dimsIo = mxGetDimensions(prhs[1]);
    const mwSize KIo = (ndIo >= 3) ? dimsIo[2] : 1;

    if (ndIo < 2 || ndIo > 3 ||
        dimsIo[0] != H || dimsIo[1] != W || KIo != K) {
        mexErrMsgIdAndTxt("umpa_core_mex:ImageShapeMismatch",
                          "I and Io must have matching HxW or HxWxK dimensions.");
    }

    require_2d_size(prhs[2], "win_I2", H, W);
    require_2d_size(prhs[3], "win_Io2", H, W);
    require_2d_size(prhs[4], "win_IIobar", H, W);
    require_2d_size(prhs[5], "win_IoIobar", H, W);
    require_real_double(prhs[6], "filter_kern");

    const double* I = mxGetPr(prhs[0]);
    const double* Io = mxGetPr(prhs[1]);
    const double* win_I2 = mxGetPr(prhs[2]);
    const double* win_Io2 = mxGetPr(prhs[3]);
    const double* win_IIobar = mxGetPr(prhs[4]);
    const double* win_IoIobar = mxGetPr(prhs[5]);
    const double* filter_kern = mxGetPr(prhs[6]);

    const int imin_1 = get_scalar_int(prhs[7], "imin");
    const int imax_1 = get_scalar_int(prhs[8], "imax");
    const int jmin_1 = get_scalar_int(prhs[9], "jmin");
    const int jmax_1 = get_scalar_int(prhs[10], "jmax");
    const int whalf = get_scalar_int(prhs[11], "whalf");
    const double c2 = get_scalar_double(prhs[12], "c2");
    const int mode_code = get_scalar_int(prhs[13], "mode_code");

    if (mode_code != 0 && mode_code != 1) {
        mexErrMsgIdAndTxt("umpa_core_mex:BadModeCode",
                          "mode_code must be 1 for DF or 0 for DPC.");
    }

    if (whalf < 1) {
        mexErrMsgIdAndTxt("umpa_core_mex:BadWindow",
                          "whalf must be >= 1.");
    }

    const int npad = 1;
    const int N = 2*whalf + 1;

    if (mxGetM(prhs[6]) != static_cast<mwSize>(N) ||
        mxGetN(prhs[6]) != static_cast<mwSize>(N)) {
        mexErrMsgIdAndTxt("umpa_core_mex:FilterSize",
                          "filter_kern must be (2*whalf+1)-by-(2*whalf+1).");
    }

    if (imin_1 < 1 || imax_1 < imin_1 || jmin_1 < 1 || jmax_1 < jmin_1 ||
        imax_1 > static_cast<int>(H) || jmax_1 > static_cast<int>(W)) {
        mexErrMsgIdAndTxt("umpa_core_mex:BadBounds",
                          "Invalid reconstruction bounds.");
    }

    const mwSize imin0 = static_cast<mwSize>(imin_1 - 1);
    const mwSize imax0 = static_cast<mwSize>(imax_1 - 1);
    const mwSize jmin0 = static_cast<mwSize>(jmin_1 - 1);
    const mwSize jmax0 = static_cast<mwSize>(jmax_1 - 1);

    const mwSize outH = static_cast<mwSize>(imax_1 - imin_1 + 1);
    const mwSize outW = static_cast<mwSize>(jmax_1 - jmin_1 + 1);

    plhs[0] = mxCreateDoubleMatrix(outH, outW, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(outH, outW, mxREAL);
    plhs[2] = mxCreateDoubleMatrix(outH, outW, mxREAL);
    plhs[3] = mxCreateDoubleMatrix(outH, outW, mxREAL);

    double* att_out = mxGetPr(plhs[0]);
    double* df_out  = mxGetPr(plhs[1]);
    double* dx_out  = mxGetPr(plhs[2]);
    double* dy_out  = mxGetPr(plhs[3]);

    #pragma omp parallel for schedule(static)
    for (mwSize jj = 0; jj < outW; ++jj) {
        const mwSize j0 = jmin0 + jj;

        for (mwSize ii = 0; ii < outH; ++ii) {
            const mwSize i0 = imin0 + ii;

            const double c1 = win_I2[idx2(i0, j0, H)];
            const double c4 = win_IIobar[idx2(i0, j0, H)];

            double c3[9];
            double c5[9];
            double c6[9];
            double Tau[9];
            double Zeta[9];
            double T[9];
            double S[9];
            double L[9];

            /*
             * For w_shft = 1, the shift/loss surface is 3x3.
             *
             * c5 is computed directly in real space over the local window.
             * This replaces the old per-pixel FFT/crop block while preserving
             * the same valid correlation values for the 3x3 search surface.
             */

            for (int sc = 0; sc < 3; ++sc) {
                for (int sr = 0; sr < 3; ++sr) {
                    const int q = sr + 3*sc;

                    const mwSize wr0 = i0 - npad + sr;
                    const mwSize wc0 = j0 - npad + sc;

                    c3[q] = win_Io2[idx2(wr0, wc0, H)];
                    c6[q] = win_IoIobar[idx2(wr0, wc0, H)];

                    double total = 0.0;

                    for (mwSize k = 0; k < K; ++k) {
                        for (int fc = 0; fc < N; ++fc) {
                            for (int fr = 0; fr < N; ++fr) {
                                const mwSize I_row  = i0 - whalf + fr;
                                const mwSize I_col  = j0 - whalf + fc;

                                const mwSize Io_row = i0 - whalf - npad + sr + fr;
                                const mwSize Io_col = j0 - whalf - npad + sc + fc;

                                const double filt = filter_kern[idx2(fr, fc, N)];
                                const double obj  = I[idx3(I_row, I_col, k, H, W)];
                                const double ref  = Io[idx3(Io_row, Io_col, k, H, W)];

                                total += ref * filt * obj;
                            }
                        }
                    }

                    c5[q] = total;
                }
            }

            for (int q = 0; q < 9; ++q) {
                if (mode_code == 1) {
                    /*
                     * DF mode:
                     *   Solve for Tau and Zeta, then map:
                     *     T = Zeta + Tau
                     *     S = Tau / T
                     */

                    const double denom = c2*c3[q] - c6[q]*c6[q];

                    Tau[q]  = (c2*c5[q] - c4*c6[q]) / denom;
                    Zeta[q] = (c3[q]*c4 - c5[q]*c6[q]) / denom;

                    T[q] = Zeta[q] + Tau[q];
                    S[q] = Tau[q] / T[q];

                    L[q] = c1
                         + c2 * Zeta[q] * Zeta[q]
                         + c3[q] * Tau[q] * Tau[q]
                         - 2.0 * c4 * Zeta[q]
                         - 2.0 * c5[q] * Tau[q]
                         + 2.0 * c6[q] * Zeta[q] * Tau[q];

                } else {
                    /*
                     * DPC / dark-field-off mode:
                     *   Matches the original MATLAB branch:
                     *     c2 = 0
                     *     c4 = 0
                     *     c6 = 0
                     *     Tau = c5 / c3
                     *     Zeta = 0
                     */

                    Tau[q] = c5[q] / c3[q];
                    Zeta[q] = 0.0;

                    T[q] = Tau[q];
                    S[q] = 1.0;

                    L[q] = c1
                         + c3[q] * Tau[q] * Tau[q]
                         - 2.0 * c5[q] * Tau[q];
                }
            }

            double loc_col;
            double loc_row;
            minsubpix3x3_core(L, loc_col, loc_row);

            loc_col = clamp_1_3(loc_col);
            loc_row = clamp_1_3(loc_row);

            /*
             * Preserve current MATLAB indexing behavior:
             *
             *   att_subpix(i,j) = T(round(minxsubpixLfit), round(minysubpixLfit))
             *   df_subpix(i,j)  = S(round(minxsubpixLfit), round(minysubpixLfit))
             *
             * The MATLAB wrapper later flips dx/dy signs to match UMPA.m output.
             */

            int t_row = static_cast<int>(std::round(loc_col)) - 1;
            int t_col = static_cast<int>(std::round(loc_row)) - 1;

            if (t_row < 0) t_row = 0;
            if (t_row > 2) t_row = 2;
            if (t_col < 0) t_col = 0;
            if (t_col > 2) t_col = 2;

            const int tq = t_row + 3*t_col;
            const mwSize out_idx = idx2(ii, jj, outH);

            att_out[out_idx] = T[tq];
            df_out[out_idx]  = S[tq];
            dx_out[out_idx]  = loc_col - 2.0;
            dy_out[out_idx]  = loc_row - 2.0;
        }
    }
}