function [outputArg1,outputArg2] = deconvstack(struct,objload,shiftedrefload,varargin)

I = sum(objload,3);
Io = sum(shiftedrefload,3);
Sig = I./Io;
switch varargin{1}
    case 'flatfield'
gain = double(imread(strcat(struct.gain_location,filesep,'gain.tif')));
offset = double(imread(strcat(struct.offset_location,filesep,'offset.tif')));

offsetgain = gain - offset;
offsetgain = offsetgain/mean(offsetgain(:));

% Define a Background Region of Interest (ROI)
background_roi = imcrop(offsetgain, [10, 10, 100, 100]);
total_power = var(Io(:));
    case 'IIo'
background_roi = imcrop(Sig, [10, 10, 100, 100]);
% Calculate Noise Power (Variance of the background)
noise_power = var(background_roi(:));
total_power = var(Sig(:));

% Calculate Total Power (Variance of the entire image)
% This contains both the signal fluctuations (the object) AND the noise
% calculate with each image individually, add varargin, without geometry
% default to the camera psf. Reasonable factor is 1.1*camera_blur.



% Isolate the Signal Power
signal_power = total_power - noise_power;

% Safety check: If the whole image is blank, signal power could drop below zero.
if signal_power <= 0
    signal_power = eps; % Set to a tiny number to avoid dividing by zero
end

% Calculate Final NSR
nsr_value = noise_power / signal_power;

fprintf('Calculated NSR: %e\n', nsr_value);

% Convert FWHM to Gaussian Standard Deviation (sigma)
% Formula: sigma = FWHM / (2 * sqrt(2 * ln(2)))
switch struct.order
    case 'source-reference-object-detector'
        struct.geo.Dom = struct.geo.Dsm - struct.geo.Dso;
        struct.geo.Dmd = struct.geo.Dsd - struct.geo.Dsm;
    case 'source-object-reference-detector'
        struct.geo.Dom = struct.geo.Dso - struct.geo.Dsm;
        struct.geo.Dmd = struct.geo.Dsm - struct.geo.Dsd;
end
switch varargin{2}
    case 'manual'
        struct.sigma_um = struct.fwhm_um / (2 * sqrt(2 * log(2)));
    case 'full'
        struct.fwhm_blur = (struct.geo.Dmd./struct.geo.Dsm.*struct.geo.spotsize);
        struct.sigma_um = sqrt((struct.fwhm_um.^2+struct.fwhm_blur.^2)) / (2 * sqrt(2 * log(2)));
    case 'detector'
        struct.sigma_um = struct.fwhm_um / (2 * sqrt(2 * log(2)));
end




% Convert physical sigma to pixel sigma
sigma_pixels = struct.sigma_um / struct.pixel_pitch_um;

fprintf('Calculated exact Gaussian Blur (Sigma): %.3f pixels\n', sigma_pixels);

% Generate the 2D PSF Kernel
% Ensure the kernel is large enough to contain the blur (6x sigma) and is an odd number
kernel_size = ceil(sigma_pixels * 6);
if mod(kernel_size, 2) == 0
    kernel_size = kernel_size + 1;
end

psf_final = fspecial('gaussian', kernel_size, sigma_pixels);

switch struct.override_nsr
    case 'override'
        fprintf('nsr override is enabled, using set value %.3e\n',struct.nsr)
        nsr_value = struct.nsr;
end

for k = 1:size(objload, 3)
    deconvolvedStack1(:,:,k) = deconvwnr(objload(:,:,k), psf_final, nsr_value);
    deconvolvedStack2(:,:,k) = deconvwnr(shiftedrefload(:,:,k), psf_final, nsr_value);
end

% figure;
% subplot(1,2,1);imagesc(deconvolvedStack1(:,:,1));colormap gray; axis image; clim([0,1])
% subplot(1,2,2);imagesc(objload(:,:,1)); colormap gray; axis image; clim([0,1])

outputArg1  = deconvolvedStack1;
outputArg2 = deconvolvedStack2;

end