function [I, Io] = singularityswitch(sc, objload, shiftedrefload)
%SINGULARITYSWITCH Apply optional outlier and zero filtering to image stacks.

I = objload;
Io = shiftedrefload;

use_outlier = strcmpi(sc.outlier, 'on');
use_zero    = strcmpi(sc.zero, 'on');

if ~use_outlier && ~use_zero
    return
end

for k = 1:size(objload, 3)

    if use_outlier
        I(:,:,k)  = outlier_filter(I(:,:,k),  sc.corrparam.sig);
        Io(:,:,k) = outlier_filter(Io(:,:,k), sc.corrparam.sig);
    end

    if use_zero
        I(:,:,k)  = zero_filter(I(:,:,k));
        Io(:,:,k) = zero_filter(Io(:,:,k));
    end

end

end