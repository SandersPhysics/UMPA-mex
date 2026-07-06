#include "mex.h"

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    if (nrhs != 1) {
        mexErrMsgIdAndTxt("build_test_mex:nrhs", "One input required.");
    }

    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0]) || mxGetNumberOfElements(prhs[0]) != 1) {
        mexErrMsgIdAndTxt("build_test_mex:input", "Input must be one real double scalar.");
    }

    double x = mxGetScalar(prhs[0]);
    plhs[0] = mxCreateDoubleScalar(x + 1.0);
}
