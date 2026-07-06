function outputArg1 = camera(struct)
%camera quickly reference the camera settings for deblurring
%   switch argument to load camera fwhm and pixel size
number = struct.resolution;
switch struct.cam_type
    case 'gsense'
        if (number >= 2000) && (number <= 2100)
            fwhm_um = 73;
            pixel_pitch_um = 22;

        elseif (number >= 4000) && (number <= 4100)
            fwhm_um = 31.5;
            pixel_pitch_um = 9;
        end

    case 'manual'
        fwhm_um = input('Specify the FWHM in micrometers: \n');
        pixel_pitch_um = input('Specify the pixel size in micrometers: \n');

end
struct.fwhm_um = fwhm_um;
struct.pixel_pitch_um = pixel_pitch_um;
outputArg1 = struct;