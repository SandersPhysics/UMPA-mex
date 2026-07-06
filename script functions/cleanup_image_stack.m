function [I, Io] = cleanup_image_stack(sc, objload, shiftedrefload)
%CLEANUP_IMAGE_STACK Apply configured image-stack cleanup filters.
%
% Uses the compiled image_cleanup_mex path for outlier and nonpositive-pixel
% cleanup. The compiled core preserves the old MATLAB filter order while
% processing image slices in parallel.

if isempty(which('image_cleanup_mex'))
    error('cleanup_image_stack:MissingMex', ...
        'Could not find image_cleanup_mex. Run MEXbuilder first.');
end

Nsig = sc.corrparam.sig;

use_outlier = strcmpi(sc.outlier, 'on');
use_zero = strcmpi(sc.zero, 'on');

[I, Io] = image_cleanup_mex(objload, shiftedrefload, Nsig, use_outlier, use_zero);

end