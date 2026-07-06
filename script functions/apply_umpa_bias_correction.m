function processed_images = apply_umpa_bias_correction(processed_images, bias_images, mode)
%APPLY_UMPA_BIAS_CORRECTION Subtract reference-vs-reference shift bias.
%
% Modes:
%   'same_pixel'     subtract bias at the same pixel
%   'shifted_lookup' subtract bias interpolated at r + raw shift

if nargin < 3 || isempty(mode)
    mode = 'same_pixel';
end

if numel(processed_images) < 4 || numel(bias_images) < 4
    error('apply_umpa_bias_correction:BadInput', ...
        'Expected at least four result channels: ATT, DF, dx, dy.');
end

dx_raw  = processed_images(3).data;
dy_raw  = processed_images(4).data;
dx_bias = bias_images(3).data;
dy_bias = bias_images(4).data;

if ~isequal(size(dx_raw), size(dy_raw))
    error('apply_umpa_bias_correction:RawShiftSizeMismatch', ...
        'Raw dx and dy images have different sizes.');
end

if ~isequal(size(dx_raw), size(dx_bias)) || ~isequal(size(dy_raw), size(dy_bias))
    error('apply_umpa_bias_correction:BiasSizeMismatch', ...
        'Raw shift images and bias shift images must have matching sizes.');
end

mode_key = lower(strtrim(char(mode)));

switch mode_key
    case 'same_pixel'
        dx_bias_lookup = dx_bias;
        dy_bias_lookup = dy_bias;

    case 'shifted_lookup'
        [dx_bias_lookup, dy_bias_lookup] = shifted_bias_lookup( ...
            dx_raw, dy_raw, dx_bias, dy_bias);

    otherwise
        error('apply_umpa_bias_correction:BadMode', ...
            'Unknown bias correction mode: %s. Use ''same_pixel'' or ''shifted_lookup''.', mode);
end

processed_images(3).data = dx_raw - dx_bias_lookup;
processed_images(4).data = dy_raw - dy_bias_lookup;

processed_images(3).name = append_once(processed_images(3).name, ' bias corrected');
processed_images(4).name = append_once(processed_images(4).name, ' bias corrected');

end


function [dx_bias_lookup, dy_bias_lookup] = shifted_bias_lookup(dx_raw, dy_raw, dx_bias, dy_bias)
%SHIFTED_BIAS_LOOKUP Interpolate bias maps at r + raw shift.

[H, W] = size(dx_raw);

[X, Y] = meshgrid(1:W, 1:H);

Xq = X + dx_raw;
Yq = Y + dy_raw;

Xq = min(max(Xq, 1), W);
Yq = min(max(Yq, 1), H);

dx_bias_lookup = interp2(X, Y, dx_bias, Xq, Yq, 'linear');
dy_bias_lookup = interp2(X, Y, dy_bias, Xq, Yq, 'linear');

dx_bad = ~isfinite(dx_bias_lookup);
dy_bad = ~isfinite(dy_bias_lookup);

dx_bias_lookup(dx_bad) = dx_bias(dx_bad);
dy_bias_lookup(dy_bad) = dy_bias(dy_bad);

end


function out = append_once(in, suffix)

out = char(in);

if ~endsWith(out, suffix)
    out = [out, suffix];
end

end