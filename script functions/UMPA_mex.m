function [struct, result] = UMPA_mex(I, Io, struct, whalf, wshft, mode)
%UMPA_MEX Fast UMPA reconstruction wrapper.
%
% Prepares the local-window terms used by UMPA, then calls the compiled
% C++ reconstruction core.
%
% Supported modes:
%   'DF'  = attenuation + dark-field + dx/dy
%   'DPC' = attenuation + dx/dy, dark-field disabled

t_start = tic;

if nargin ~= 6
    error('UMPA_mex:BadInputCount', ...
        'Expected I, Io, struct, whalf, wshft, and mode.');
end

mode_key = lower(char(mode));

switch mode_key
    case 'df'
        mode_code = int32(1);

    case {'dpc', 'nodf', 'no_df'}
        mode_code = int32(0);

    otherwise
        error('UMPA_mex:UnsupportedMode', ...
            'Unsupported mode: %s. Use ''DF'' or ''DPC''.', mode);
end

if wshft ~= 1
    error('UMPA_mex:UnsupportedShift', ...
        'UMPA_mex currently supports w_shft = 1 only. Current value: %d', wshft);
end

if ~(isscalar(whalf) && whalf >= 1 && mod(whalf, 1) == 0)
    error('UMPA_mex:BadWindowHalf', ...
        'whalf must be a positive integer. Current value: %g', whalf);
end

if isempty(which('umpa_core_mex'))
    error('UMPA_mex:MissingCoreMex', ...
        'Could not find umpa_core_mex. Run MEXbuilder first.');
end

%% Reconstruction geometry

struct.corrparam.window   = whalf;
struct.corrparam.extrapad = wshft;

struct.nwin = 2 * struct.corrparam.window + 1;
struct.npad = struct.corrparam.extrapad;

struct.imin = struct.corrparam.window + struct.npad + 1;
struct.imax = struct.rect(4) - struct.corrparam.window - struct.npad;
struct.jmin = struct.corrparam.window + struct.npad + 1;
struct.jmax = struct.rect(3) - struct.corrparam.window - struct.npad;

imin = struct.imin;
imax = struct.imax;
jmin = struct.jmin;
jmax = struct.jmax;

num_images = size(I, 3);

%% Local-window terms

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

c2_core = num_images * Iobar2;

%% Compiled reconstruction core

[att_core, df_core, dx_core, dy_core] = umpa_core_mex( ...
    I, Io, ...
    win_I2, win_Io2, win_IIobar, win_IoIobar, ...
    filter_kern, ...
    imin, imax, jmin, jmax, ...
    whalf, c2_core, mode_code);

%% Package results

result(1).data = att_core;
result(1).name = 'attenuation-UMPA';

result(2).data = df_core;
result(2).name = 'dark-field-UMPA';

result(3).data = -dx_core;
result(3).name = 'dx-UMPA';

result(4).data = -dy_core;
result(4).name = 'dy-UMPA';

struct.runtime_seconds = toc(t_start);

end