function plot_umpa_bias_shifts(processed_images_raw, processed_images_bias, struct)
%PLOT_UMPA_BIAS_SHIFTS Show raw shifts and reference-vs-reference bias maps.

if numel(processed_images_raw) < 4 || numel(processed_images_bias) < 4
    error('plot_umpa_bias_shifts:BadInput', ...
        'Expected at least four result channels: ATT, DF, dx, dy.');
end

dx_raw  = processed_images_raw(3).data;
dy_raw  = processed_images_raw(4).data;
dx_bias = processed_images_bias(3).data;
dy_bias = processed_images_bias(4).data;

if ~isequal(size(dx_raw), size(dy_raw), size(dx_bias), size(dy_bias))
    error('plot_umpa_bias_shifts:SizeMismatch', ...
        'Raw and bias shift maps must have matching sizes.');
end

display_opts.med_size = [5, 5];
display_opts.gauss_sig = 2;
display_opts.clim = [-1, 1];

figure('Color', 'k', 'Name', [struct.version '_bias_shift_summary']);

tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

title_text = sprintf('%s bias inspection: raw shifts vs reference-bias shifts', struct.version);
sgtitle(title_text, 'Color', 'w', 'Interpreter', 'none');

plot_one(dx_raw,  'dx raw',  display_opts);
plot_one(dy_raw,  'dy raw',  display_opts);
plot_one(dx_bias, 'dx bias', display_opts);
plot_one(dy_bias, 'dy bias', display_opts);

end


function plot_one(img, panel_title, display_opts)

img_display = imgaussfilt( ...
    medfilt2(real(img), display_opts.med_size), ...
    display_opts.gauss_sig ...
);

nexttile;

imagesc(img_display);
axis image;
colormap gray;
colorbar;
clim(display_opts.clim);

title(panel_title, 'Color', 'w', 'Interpreter', 'none');

set(gca, ...
    'Color', 'k', ...
    'XColor', [0.85 0.85 0.85], ...
    'YColor', [0.85 0.85 0.85]);

end