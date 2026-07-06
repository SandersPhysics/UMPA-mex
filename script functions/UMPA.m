function [struct, result] = UMPA(I, Io, struct, whalf, wshft, mode)
%UMPA Original MATLAB UMPA reconstruction path.
%
% Supported modes:
%   'DF'  = attenuation + dark-field + dx/dy
%   'DPC' = attenuation + dx/dy, dark-field off

t_start = tic;

if nargin ~= 6
    error('UMPA:BadInputCount', ...
        'Expected I, Io, struct, whalf, wshft, and mode.');
end

mode_key = lower(strtrim(char(mode)));

switch mode_key
    case 'df'
        is_df = true;

    case {'dpc', 'nodf', 'no_df'}
        is_df = false;

    otherwise
        error('UMPA:UnsupportedMode', ...
            'Unsupported mode: %s. Use ''DF'' or ''DPC''.', mode);
end

%% Parameters for cross-correlation window

struct.corrparam.window   = whalf;
struct.corrparam.extrapad = wshft;

struct.nwin = 2 * struct.corrparam.window + 1;
struct.npad = struct.corrparam.extrapad;

struct.imin = struct.corrparam.window + struct.npad + 1;
struct.imax = struct.rect(4) - struct.corrparam.window - struct.npad;
struct.jmin = struct.corrparam.window + struct.npad + 1;
struct.jmax = struct.rect(3) - struct.corrparam.window - struct.npad;

nwin = (struct.nwin - 1) / 2;
npad = struct.npad;
num_images = size(I, 3);

winfunc = window_type('hamming', struct.nwin);
filter_kern = winfunc / sum(winfunc(:));

pad_mode = 'replicate';
filter_mode = 'corr';
output_size = 'same';

sum_I2  = sum(I.^2, 3);
sum_Io2 = sum(Io.^2, 3);

sum_I  = sum(I, 3);
sum_Io = sum(Io, 3);

Iobar = mean(sum_Io(:)) / num_images;
Iobar2 = Iobar^2;

win_I2  = imfilter(sum_I2,  filter_kern, pad_mode, filter_mode, output_size);
win_Io2 = imfilter(sum_Io2, filter_kern, pad_mode, filter_mode, output_size);

win_IIobar  = Iobar * imfilter(sum_I,  filter_kern, pad_mode, filter_mode, output_size);
win_IoIobar = Iobar * imfilter(sum_Io, filter_kern, pad_mode, filter_mode, output_size);

imin = struct.imin;
imax = struct.imax;
jmin = struct.jmin;
jmax = struct.jmax;

%% Preallocate full image-sized maps

att_subpix = zeros(size(I, 1), size(I, 2));
df_subpix  = zeros(size(I, 1), size(I, 2));
dx_subpix  = zeros(size(I, 1), size(I, 2));
dy_subpix  = zeros(size(I, 1), size(I, 2));

%% Pixel loop

for i = imin:imax
    for j = jmin:jmax

        c1 = win_I2(i, j);
        c3 = win_Io2(i-npad:i+npad, j-npad:j+npad);

        if is_df
            c2 = num_images * Iobar2;
            c4 = win_IIobar(i, j);
            c6 = win_IoIobar(i-npad:i+npad, j-npad:j+npad);
        else
            c2 = 0;
            c4 = 0;
            c6 = 0;
        end

        cc_Io = Io(i-nwin-npad:i+nwin+npad, j-nwin-npad:j+nwin+npad, :);
        cc_I  = filter_kern .* I(i-nwin:i+nwin, j-nwin:j+nwin, :);

        [M, ~, ~] = size(cc_Io);
        [N, ~, ~] = size(cc_I);

        F_mesh = fft2(cc_Io);
        F_obj  = fft2(cc_I, M, M);

        C_full = ifft2(F_mesh .* conj(F_obj), 'symmetric');

        valid_size = M - N + 1;
        c5_temp = C_full(1:valid_size, 1:valid_size, :);

        c5 = sum(c5_temp, 3);

        if is_df
            denom = c2 .* c3 - c6.^2;

            Tau  = (c2 .* c5 - c4 .* c6) ./ denom;
            Zeta = (c3 .* c4 - c5 .* c6) ./ denom;

            T = Zeta + Tau;
            S = Tau ./ T;

            L = c1 ...
                + c2 .* Zeta.^2 ...
                + c3 .* Tau.^2 ...
                - 2 * c4 .* Zeta ...
                - 2 * c5 .* Tau ...
                + 2 * c6 .* Zeta .* Tau;

        else
            Tau = c5 ./ c3;

            T = Tau;
            S = ones(size(T));

            L = c1 ...
                + c3 .* Tau.^2 ...
                - 2 * c5 .* Tau;
        end

        [minxL, minyL] = coordinate_extremum_finder(L, 'min');

        edgeparam = 1;

        tempLx = minxL;
        tempLy = minyL;

        tempLx(tempLx <= edgeparam) = edgeparam + 1;
        tempLy(tempLy <= edgeparam) = edgeparam + 1;

        tempLx(tempLx + edgeparam >= size(L, 1)) = size(L, 1) - edgeparam;
        tempLy(tempLy + edgeparam >= size(L, 2)) = size(L, 2) - edgeparam;

        [minxsubpixLfit, minysubpixLfit, ~] = quadfit( ...
            L(tempLx-1:tempLx+1, tempLy-1:tempLy+1) ...
        );

        minxsubpixLfit = min(max(minxsubpixLfit, 1), 2*npad + 1);
        minysubpixLfit = min(max(minysubpixLfit, 1), 2*npad + 1);

        att_subpix(i, j) = T(round(minxsubpixLfit), round(minysubpixLfit));
        df_subpix(i, j)  = S(round(minxsubpixLfit), round(minysubpixLfit));

        dx_subpix(i, j) = minxsubpixLfit - (npad + 1);
        dy_subpix(i, j) = minysubpixLfit - (npad + 1);
    end
end

%% Package results

result(1).data = att_subpix(imin:imax, jmin:jmax);
result(1).name = 'attenuation-UMPA';

result(2).data = df_subpix(imin:imax, jmin:jmax);
result(2).name = 'dark-field-UMPA';

result(3).data = -dx_subpix(imin:imax, jmin:jmax);
result(3).name = 'dx-UMPA';

result(4).data = -dy_subpix(imin:imax, jmin:jmax);
result(4).name = 'dy-UMPA';

struct.runtime_seconds = toc(t_start);

end