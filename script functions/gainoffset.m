function [struct,outputArg1,outputArg2] = gainoffset(type,obj,ref,struct)
% Gain and offset corrections for NxM matrices
%   Detailed explanation goes here
I = obj(:,:,struct.imgstart:struct.imgstep:struct.imgend);
Io = ref(:,:,struct.imgstart:struct.imgstep:struct.imgend);
clear obj ref
if strcmpi(type,'off')
    outputArg1 = I;
    outputArg2 = Io;
    return
end
if isfolder(struct.gain_location) == 1
else
    error('Folder not found: calibration images ')
end
switch type
    case 'doubleoffset'
        offset1 = imcrop(double(imread(struct.offset_location1)),struct.rect); % load offset
        offset2 = imcrop(double(imread(struct.offset_location2)),struct.rect); % load offset
        gain = imcrop(double(imread(struct.gain_location)),struct.rect); % load gain
        offset1=repmat(offset1,1,1,size(I,3));
        offset2=repmat(offset2,1,1,size(I,3));
        gain=repmat(gain,1,1,size(I,3));

        gain=(gain-offset2);
        I=(I-offset1);
        Io=(Io-offset1);
        I=I./gain;
        Io=Io./gain;
        outputArg1 = I;
        outputArg2 = Io;
    case 'gain+specific_offset'
        mesh_offset = imcrop(double(imread(strcat(struct.offset_location,filesep,'mesh offset.tif'))),struct.rect); % load reference offset
        sample_offset = imcrop(double(imread(strcat(struct.offset_location,filesep,'sample offset.tif'))),struct.rect); % load sample offset
        gain_offset = imcrop(double(imread(strcat(struct.gain_location,filesep,'gain offset.tif'))),struct.rect); % load gain offset
        gain = imcrop(double(imread(strcat(struct.gain_location,filesep,'gain.tif'))),struct.rect); % load gain

        mesh_offset=repmat(mesh_offset,1,1,size(I,3));
        sample_offset=repmat(sample_offset,1,1,size(I,3));

        gain=repmat(gain,1,1,size(I,3));

        I=(I-sample_offset)./(gain-gain_offset);
        Io=(Io-mesh_offset)./(gain-gain_offset);


        outputArg1 = I;
        outputArg2 = Io;
    case 'gain_offset'
        switch struct.resize
            case 'on'
                offset = imcrop(imresize(double(imread(strcat(struct.offset_location,filesep,'offset.tif'))),struct.rescalefactor),struct.rect); % load offset
                gain = imcrop(imresize(double(imread(strcat(struct.gain_location,filesep,'gain.tif'))),struct.rescalefactor),struct.rect); % load gain
            case 'off'
                offset = imcrop(double(imread(strcat(struct.offset_location,filesep,'offset.tif'))),struct.rect); % load offset
                gain = imcrop(double(imread(strcat(struct.gain_location,filesep,'gain.tif'))),struct.rect); % load gain
        end
        offset=repmat(offset,1,1,size(I,3));
        gain=repmat(gain,1,1,size(I,3));

        I=(I-offset)./(gain-offset);
        Io=(Io-offset)./(gain-offset);


        outputArg1 = I;
        outputArg2 = Io;
    case 'gain'
        switch struct.resize
            case 'on'         
                gain = imcrop(imresize(double(imread(strcat(struct.gain_location,filesep,'gain.tif'))),struct.rescalefactor),struct.rect); % load gain
            case 'off'
                gain = imcrop(double(imread(strcat(struct.gain_location,filesep,'gain.tif'))),struct.rect); % load gain
        end
        gain=repmat(gain,1,1,size(I,3));

        outputArg1=(I)./(gain);
        outputArg2=(Io)./(gain);

    case 'offset'
        offset = imcrop(double(imread(strcat(struct.offset_location,filesep,'offset.tif'))),struct.rect); % static reference pattern
        offset=repmat(offset,1,1,size(I,3));
        I=(I-offset);
        Io=(Io-offset);
        outputArg1 = I;
        outputArg2 = Io;
    case 'off'
        outputArg1 = I;
        outputArg2 = Io;
    otherwise
        error('Incorrect option selected')


end
struct.imgend = size(outputArg1,3);
end