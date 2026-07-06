function I = outlier_filter(J, N)
%OUTLIER_FILTER Replace intensity outliers, Inf, and NaN values using a
%local median-filtered image.
%
% A pixel is replaced if:
%   abs(pixel - mean(image)) > N*std(image)
% or if it is Inf/NaN.
%
% The median image is only computed when at least one pixel needs replacing.

I = J;

for k = 1:size(J, 3)
    img = J(:,:,k);

    mu = mean(img(:));
    sig = std(img(:));

    outlier_mask = abs(img - mu) > N * sig;
    bad_mask = outlier_mask | isinf(img) | isnan(img);

    if any(bad_mask(:))
        med = medfilt2(img, [6 6]);
        img(bad_mask) = med(bad_mask);
    end

    I(:,:,k) = img;
end

end