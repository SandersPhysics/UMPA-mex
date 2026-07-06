#include "mex.h"

#include <algorithm>
#include <cmath>
#include <vector>
#include <omp.h>

/*
 * image_cleanup_mex
 *
 * Fast compiled version of the MATLAB image-stack cleanup path.
 *
 * Inputs:
 *   0 objload          HxW or HxWxK object/sample image stack
 *   1 shiftedrefload   HxW or HxWxK reference image stack
 *   2 Nsig             outlier threshold multiplier
 *   3 use_outlier      true/false, apply outlier replacement
 *   4 use_zero         true/false, apply nonpositive-pixel replacement
 *
 * Outputs:
 *   0 I                cleaned object/sample stack
 *   1 Io               cleaned reference stack
 *
 * Each image slice is processed independently. The input arrays are
 * duplicated first, so the original MATLAB inputs are not modified.
 *
 * The filtering order intentionally matches the old MATLAB logic:
 *   1. Replace statistical outliers using a frozen 6x6 median image.
 *   2. Replace Inf using that same frozen 6x6 median image.
 *   3. Replace NaN using that same frozen 6x6 median image.
 *   4. Replace values <= 0 using a frozen 3x3 median image.
 *   5. Replace any remaining values <= 0 with the slice mean.
 */

static inline mwSize idx2(mwSize row, mwSize col, mwSize nrows)
{
    return row + col * nrows;
}

static void require_real_double_array(const mxArray* arr, const char* name)
{
    if (!mxIsDouble(arr) || mxIsComplex(arr) || mxIsSparse(arr)) {
        mexErrMsgIdAndTxt("image_cleanup_mex:InputType",
                          "%s must be a real, full double array.", name);
    }
}

static double get_real_scalar(const mxArray* arr, const char* name)
{
    if (!mxIsNumeric(arr) || mxIsComplex(arr) || mxGetNumberOfElements(arr) != 1) {
        mexErrMsgIdAndTxt("image_cleanup_mex:ScalarInput",
                          "%s must be a real numeric scalar.", name);
    }

    return mxGetScalar(arr);
}

static bool get_bool_scalar(const mxArray* arr, const char* name)
{
    if (mxGetNumberOfElements(arr) != 1) {
        mexErrMsgIdAndTxt("image_cleanup_mex:ScalarInput",
                          "%s must be a scalar logical or numeric value.", name);
    }

    if (mxIsLogical(arr)) {
        return mxIsLogicalScalarTrue(arr);
    }

    if (!mxIsNumeric(arr) || mxIsComplex(arr)) {
        mexErrMsgIdAndTxt("image_cleanup_mex:ScalarInput",
                          "%s must be a scalar logical or numeric value.", name);
    }

    return mxGetScalar(arr) != 0.0;
}

static inline bool is_outlier(double x, double mean_value, double std_value, double nsig)
{
    return std::abs(x - mean_value) > nsig * std_value;
}

static double mean_image(const double* A, mwSize offset, mwSize H, mwSize W)
{
    const mwSize n = H * W;
    double total = 0.0;

    for (mwSize p = 0; p < n; ++p) {
        total += A[offset + p];
    }

    return total / static_cast<double>(n);
}

static double std_image(const double* A, mwSize offset, mwSize H, mwSize W, double mean_value)
{
    const mwSize n = H * W;

    if (n < 2) {
        return 0.0;
    }

    double sum_squares = 0.0;

    for (mwSize p = 0; p < n; ++p) {
        const double d = A[offset + p] - mean_value;
        sum_squares += d * d;
    }

    return std::sqrt(sum_squares / static_cast<double>(n - 1));
}

static double median3_zero_padded(const double* A, mwSize H, mwSize W, mwSize row, mwSize col)
{
    double values[9];
    int count = 0;

    for (int dc = -1; dc <= 1; ++dc) {
        for (int dr = -1; dr <= 1; ++dr) {
            const long rr = static_cast<long>(row) + dr;
            const long cc = static_cast<long>(col) + dc;

            if (rr < 0 || cc < 0 || rr >= static_cast<long>(H) || cc >= static_cast<long>(W)) {
                values[count++] = 0.0;
            } else {
                values[count++] = A[idx2(static_cast<mwSize>(rr), static_cast<mwSize>(cc), H)];
            }
        }
    }

    std::sort(values, values + 9);
    return values[4];
}

static double median6_zero_padded(const double* A, mwSize H, mwSize W, mwSize row, mwSize col)
{
    double values[36];
    int count = 0;

    /*
     * MATLAB medfilt2(A, [6 6]) uses an asymmetric even-sized window:
     * rows i-2:i+3 and columns j-2:j+3.
     *
     * Padding is zero-valued here to match the old cleanup behavior.
     */

    for (int dc = -2; dc <= 3; ++dc) {
        for (int dr = -2; dr <= 3; ++dr) {
            const long rr = static_cast<long>(row) + dr;
            const long cc = static_cast<long>(col) + dc;

            if (rr < 0 || cc < 0 || rr >= static_cast<long>(H) || cc >= static_cast<long>(W)) {
                values[count++] = 0.0;
            } else {
                values[count++] = A[idx2(static_cast<mwSize>(rr), static_cast<mwSize>(cc), H)];
            }
        }
    }

    std::sort(values, values + 36);

    /*
     * MATLAB median for an even number of values averages the two middle
     * entries after sorting.
     */

    return 0.5 * (values[17] + values[18]);
}

static void copy_slice(const double* A, mwSize offset, mwSize n, std::vector<double>& out)
{
    out.resize(n);

    for (mwSize p = 0; p < n; ++p) {
        out[p] = A[offset + p];
    }
}

static void replace_outliers_and_nonfinite(double* A, mwSize offset, mwSize H, mwSize W, double nsig)
{
    const mwSize n = H * W;

    const double mean_value = mean_image(A, offset, H, W);
    const double std_value = std_image(A, offset, H, W, mean_value);

    /*
     * Freeze the source slice before building the median replacements.
     * This matches MATLAB code that computes med = medfilt2(I, [6 6])
     * before assigning any replacement pixels.
     */

    std::vector<double> med_source;
    copy_slice(A, offset, n, med_source);

    for (mwSize col = 0; col < W; ++col) {
        for (mwSize row = 0; row < H; ++row) {
            const mwSize local_idx = idx2(row, col, H);
            const mwSize global_idx = offset + local_idx;
            const double x = med_source[local_idx];

            if (is_outlier(x, mean_value, std_value, nsig)) {
                A[global_idx] = median6_zero_padded(med_source.data(), H, W, row, col);
            }
        }
    }

    /*
     * The old MATLAB logic separately replaces Inf and NaN using the same
     * frozen 6x6 median image.
     */

    for (mwSize col = 0; col < W; ++col) {
        for (mwSize row = 0; row < H; ++row) {
            const mwSize global_idx = offset + idx2(row, col, H);

            if (std::isinf(A[global_idx])) {
                A[global_idx] = median6_zero_padded(med_source.data(), H, W, row, col);
            }
        }
    }

    for (mwSize col = 0; col < W; ++col) {
        for (mwSize row = 0; row < H; ++row) {
            const mwSize global_idx = offset + idx2(row, col, H);

            if (std::isnan(A[global_idx])) {
                A[global_idx] = median6_zero_padded(med_source.data(), H, W, row, col);
            }
        }
    }
}

static bool slice_has_nonpositive(const double* A, mwSize offset, mwSize n)
{
    for (mwSize p = 0; p < n; ++p) {
        if (A[offset + p] <= 0.0) {
            return true;
        }
    }

    return false;
}

static void replace_nonpositive(double* A, mwSize offset, mwSize H, mwSize W)
{
    const mwSize n = H * W;

    if (!slice_has_nonpositive(A, offset, n)) {
        return;
    }

    /*
     * Freeze the post-outlier slice before 3x3 median replacement.
     * This matches MATLAB code that computes med = medfilt2(I, [3 3])
     * before assigning replacement pixels.
     */

    std::vector<double> med_source;
    copy_slice(A, offset, n, med_source);

    for (mwSize col = 0; col < W; ++col) {
        for (mwSize row = 0; row < H; ++row) {
            const mwSize global_idx = offset + idx2(row, col, H);

            if (A[global_idx] <= 0.0) {
                A[global_idx] = median3_zero_padded(med_source.data(), H, W, row, col);
            }
        }
    }

    /*
     * Old fallback:
     *   I(find(I <= 0)) = mean(I(:));
     */

    if (slice_has_nonpositive(A, offset, n)) {
        const double mean_after = mean_image(A, offset, H, W);

        for (mwSize p = 0; p < n; ++p) {
            if (A[offset + p] <= 0.0) {
                A[offset + p] = mean_after;
            }
        }
    }
}

static void clean_slice(double* A, mwSize offset, mwSize H, mwSize W,
                        double nsig, bool use_outlier, bool use_zero)
{
    if (use_outlier) {
        replace_outliers_and_nonfinite(A, offset, H, W, nsig);
    }

    if (use_zero) {
        replace_nonpositive(A, offset, H, W);
    }
}

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
    if (nrhs != 5) {
        mexErrMsgIdAndTxt("image_cleanup_mex:InputCount",
                          "Expected five inputs: objload, shiftedrefload, Nsig, use_outlier, use_zero.");
    }

    if (nlhs != 2) {
        mexErrMsgIdAndTxt("image_cleanup_mex:OutputCount",
                          "Expected two outputs: I and Io.");
    }

    const mxArray* obj_mx = prhs[0];
    const mxArray* ref_mx = prhs[1];

    require_real_double_array(obj_mx, "objload");
    require_real_double_array(ref_mx, "shiftedrefload");

    const mwSize obj_nd = mxGetNumberOfDimensions(obj_mx);
    const mwSize ref_nd = mxGetNumberOfDimensions(ref_mx);

    if (obj_nd != ref_nd) {
        mexErrMsgIdAndTxt("image_cleanup_mex:DimensionCount",
                          "objload and shiftedrefload must have matching dimensions.");
    }

    if (obj_nd < 2 || obj_nd > 3) {
        mexErrMsgIdAndTxt("image_cleanup_mex:Dimensions",
                          "Inputs must be 2D images or 3D image stacks.");
    }

    const mwSize* obj_dims = mxGetDimensions(obj_mx);
    const mwSize* ref_dims = mxGetDimensions(ref_mx);

    for (mwSize d = 0; d < obj_nd; ++d) {
        if (obj_dims[d] != ref_dims[d]) {
            mexErrMsgIdAndTxt("image_cleanup_mex:SizeMismatch",
                              "objload and shiftedrefload must have the same size.");
        }
    }

    const mwSize H = obj_dims[0];
    const mwSize W = obj_dims[1];
    const mwSize K = (obj_nd == 3) ? obj_dims[2] : 1;

    const double nsig = get_real_scalar(prhs[2], "Nsig");
    const bool use_outlier = get_bool_scalar(prhs[3], "use_outlier");
    const bool use_zero = get_bool_scalar(prhs[4], "use_zero");

    if (!std::isfinite(nsig) || nsig < 0.0) {
        mexErrMsgIdAndTxt("image_cleanup_mex:BadNsig",
                          "Nsig must be finite and nonnegative.");
    }

    plhs[0] = mxDuplicateArray(obj_mx);
    plhs[1] = mxDuplicateArray(ref_mx);

    double* I = mxGetPr(plhs[0]);
    double* Io = mxGetPr(plhs[1]);

    const long long num_slices = static_cast<long long>(K);

    #pragma omp parallel for schedule(static)
    for (long long kk = 0; kk < num_slices; ++kk) {
        const mwSize k = static_cast<mwSize>(kk);
        const mwSize offset = H * W * k;

        clean_slice(I,  offset, H, W, nsig, use_outlier, use_zero);
        clean_slice(Io, offset, H, W, nsig, use_outlier, use_zero);
    }
}