%% Basic calling script for all retrieval methods
clc; clear all;

t_profile_start = tic;

addpath(genpath('script functions'));

%%----------------------AIDEN'S SANDBOX-----------------------

% UMPA core toggle
%   'original' = original MATLAB UMPA.m
%   'mex'      = fast MEX path
umpa_core = 'mex';

% Filter cleanup toggle
%   'matlab' = singularityswitch/outlier_filter/zero_filter
%   'mex'    = fast MEX filter path preserving old MATLAB filter logic
filter_core = 'mex';

% Reconstruction mode
%   'DF'  = attenuation + dark-field + dx/dy
%   'DPC' = attenuation + dx/dy, dark-field off
umpa_mode = 'DF';

% UMPA correlation/search settings
umpa_w_half = 2;
umpa_w_shft = 1; % Only supports 1

% Shift-bias correction
%   'off' = no bias correction
%   'on'  = reference-vs-reference shift-bias correction
bias_correct_shifts = 'off';

% Bias correction mode
%   'same_pixel'     = subtract bias at the same pixel
%   'shifted_lookup' = subtract bias interpolated at r + raw shift
bias_correction_mode = 'same_pixel';

%%--------------------HARDWARE ACCELERATION--------------------

struct.architecture = 'CPU'; % 'CPU', 'GPU'. GPU unsupported in MEX implementation
struct = system_specs(struct);

%%------------------------SAVE FILES--------------------------

struct.savefiles = 'on'; % 'on','off'

%%----------------------DECONVOLUTION--------------------------

deconvolve = 'off';
deconv_type = 'detector'; % 'manual','full','detector'

struct.cam_type = 'gsense';
struct.order = 'source-object-reference-detector';
struct.override_nsr = 'override';
struct.nsr = 1e-2;

% System geometry for deconvolution, units in microns
struct.geo.spotsize = 210;
struct.geo.Dsd      = 80*10^4;
struct.geo.Dsm      = 57*10^4;
struct.geo.Dso      = 65*10^4;

%%-----------------------GAIN CORRECTION------------------------

goff = 'gain_offset'; % 'gain_offset', 'gain', 'offset', 'off'

%%----------------------FOLDER STRUCTURE------------------------

struct.samplefolder      = 'Sample_total';
struct.referencefolder   = 'Ref_total';
struct.calibrationfolder = 'Calibration images';

struct.dirstr = pwd;
struct = dirstruct(struct, 'default'); % 'GUI', 'default'

%%--------------------------DATA SETTINGS--------------------------

struct.datatype = 'tomosynthesis'; % 'single projection', 'tomography', 'tomosynthesis'

struct.resize = 'off'; % 'on','off'
struct.rescalefactor = 1/2;

struct.outlier = 'on';
struct.zero = 'on';
struct.corrparam.sig = 3;

%%--------------------------CROP STYLE-----------------------------

cropload = 'off';
struct.crop_mode = 'directory image';

if strcmpi(cropload, 'on')
    load('croprect.mat')
    crop_style = 'manual';
    struct.manualcrop = rectout;

elseif strcmpi(cropload, 'off')
    crop_style = 'full';
    struct.manualcrop = [150, 200, 849, 1299];

else
    error('runUMPA:BadCropLoad', 'Incorrect cropload option selected.')
end

%%--------------------------IMAGE LOADING--------------------------

struct.imgstart = 1;
struct.imgend = numelements(struct.ref_folder);
struct.imgstep = 1;

struct = ROI_crop(crop_style, struct);

[objload, shiftedrefload] = shiftloader(struct);
[struct, I, Io] = gainoffset(goff, objload, shiftedrefload, struct);

clear objload shiftedrefload

%%--------------------------PIXEL CLEANUP--------------------------

switch lower(char(filter_core))
    case 'matlab'
        [I, Io] = singularityswitch(struct, I, Io);

    case 'mex'
        if isempty(which('cleanup_image_stack'))
            error('runUMPA:MissingCleanupImageStack', ...
              'Could not find cleanup_image_stack.m on the MATLAB path.');
    end

    [I, Io] = cleanup_image_stack(struct, I, Io);

    otherwise
        error('runUMPA:BadFilterToggle', ...
            'Unknown filter_core value: %s. Use ''matlab'' or ''mex''.', filter_core);
end

%%--------------------------DECONVOLUTION--------------------------

switch lower(char(deconvolve))
    case 'on'
        struct = camera(struct);

        I(~isfinite(I)) = 0;
        Io(~isfinite(Io)) = 0;

        [I, Io] = deconvstack(struct, I, Io, 'IIo', deconv_type);

    case 'off'
        % No deconvolution.

    otherwise
        error('runUMPA:BadDeconvolveToggle', ...
            'Unknown deconvolve value: %s. Use ''on'' or ''off''.', deconvolve);
end

%%--------------------------UMPA CORE ALGORITHM--------------------------

I(~isfinite(I)) = 0;
Io(~isfinite(Io)) = 0;

mode_key = lower(strtrim(char(umpa_mode)));

switch mode_key
    case 'df'
        struct.mode = 'DF';

    case {'dpc', 'nodf', 'no_df'}
        struct.mode = 'DPC';

    otherwise
        error('runUMPA:UnsupportedMode', ...
            'Unsupported umpa_mode: %s. Use ''DF'' or ''DPC''.', umpa_mode);
end

w_half = umpa_w_half;
w_shft = umpa_w_shft;

if ~(isscalar(w_half) && w_half >= 1 && mod(w_half, 1) == 0)
    error('runUMPA:BadWindowHalf', ...
        'w_half must be a positive integer. Current value: %g', w_half);
end

if ~(isscalar(w_shft) && w_shft >= 1 && mod(w_shft, 1) == 0)
    error('runUMPA:BadShiftRadius', ...
        'w_shft must be a positive integer. Current value: %g', w_shft);
end

switch lower(char(umpa_core))
    case 'original'
        struct.version = 'UMPA';
        result_out(struct);

        [struct, processed_images] = UMPA(I, Io, struct, w_half, w_shft, struct.mode);

    case 'mex'
        if w_shft ~= 1
            error('runUMPA:UnsupportedShift', ...
                'MEX fast path currently supports w_shft = 1 only. Current value: %d', w_shft);
        end

        if isempty(which('UMPA_mex'))
            error('runUMPA:MissingUMPA_mex', ...
                'Could not find UMPA_mex.m on the MATLAB path.');
        end

        struct.version = 'UMPA_mex';
        result_out(struct);

        [struct, processed_images] = UMPA_mex(I, Io, struct, w_half, w_shft, struct.mode);

    otherwise
        error('runUMPA:BadCoreToggle', ...
            'Unknown umpa_core value: %s. Use ''original'' or ''mex''.', umpa_core);
end

%%--------------------------BIAS CORRECTION--------------------------

switch lower(char(bias_correct_shifts))
    case 'off'
        % No shift-bias correction.

    case 'on'
        fprintf('\nRunning UMPA shift-bias correction: reference vs reference...\n');

        struct_bias = struct;
        struct_bias.version = [struct.version, '_bias'];

        switch lower(char(umpa_core))
            case 'original'
                [~, bias_images] = UMPA(Io, Io, struct_bias, ...
                    w_half, w_shft, struct.mode);

            case 'mex'
                [~, bias_images] = UMPA_mex(Io, Io, struct_bias, ...
                    w_half, w_shft, struct.mode);

            otherwise
                error('runUMPA:BadCoreToggleDuringBias', ...
                    'Unknown umpa_core value during bias correction: %s.', umpa_core);
        end

        processed_images_raw = processed_images;   %#ok<NASGU>
        processed_images_bias = bias_images;       %#ok<NASGU>

        fprintf('Bias correction mode: %s\n', bias_correction_mode);

        processed_images = apply_umpa_bias_correction( ...
            processed_images, processed_images_bias, bias_correction_mode);

    otherwise
        error('runUMPA:BadBiasToggle', ...
            'Unknown bias_correct_shifts value: %s. Use ''on'' or ''off''.', bias_correct_shifts);
end

struct.runtime_seconds = toc;

%%--------------------------IMAGE DISPLAY--------------------------

XRPD_PNG(processed_images, struct, 2, 2)

if strcmpi(bias_correct_shifts, 'on')
    plot_umpa_bias_shifts(processed_images_raw, processed_images_bias, struct);
end

%%--------------------------SAVE FILES--------------------------

if strcmpi(struct.savefiles, 'on')
    save_folder = fullfile(struct.savedir, struct.version);

    if ~exist(save_folder, 'dir')
        mkdir(save_folder);
    end

    save(fullfile(save_folder, 'processed_images'), 'processed_images')
end

%%--------------------------WRAP UP--------------------------

elapsed_profile_time = toc(t_profile_start);

fprintf("Total elapsed time: %.2f seconds\n", elapsed_profile_time);