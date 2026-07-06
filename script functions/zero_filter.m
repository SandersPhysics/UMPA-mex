function I = zero_filter(I)
%ZERO_FILTER Replace zero and negative values using a local median fallback.
%
% First pass:
%   Replace I <= 0 pixels using a 3x3 median-filtered image.
%
% Fallback:
%   Any pixels still <= 0 are replaced by the image mean.

zero_mask = I <= 0;

if any(zero_mask(:))
    med = medfilt2(I, [3 3]);
    I(zero_mask) = med(zero_mask);

    zero_mask = I <= 0;

    if any(zero_mask(:))
        I(zero_mask) = mean(I(:));
    end
end

end