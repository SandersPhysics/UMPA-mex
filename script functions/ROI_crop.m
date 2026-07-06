function [struct] = ROI_crop(crop_type,struct)

switch struct.crop_mode
    case 'directory image'
        objdir = dir(fullfile(struct.obj_folder,'*.tif'));
        objdir = objdir(~ismember({objdir.name}, {'.', '..'}));
        mask = startsWith({objdir.name}, '._');
        objdir(mask) = [];
        F = dir(fullfile(struct.obj_folder,objdir(1).name));
        tempload = double(imread(strcat(F.folder,filesep,F.name)));
        stemp = size(tempload,1);
        struct.resolution = stemp;
        switch struct.resize
            case 'on'
                clear tempload
                tempload = imresize(double(imread(strcat(F.folder,filesep,F.name))),struct.rescalefactor);
        end
    case 'advanced'
        tempload = evalin('base',struct.modulated);
end
[s1,s2] = size(tempload);

switch crop_type

    case 'cursor'
        figure; imagesc(tempload); axis image; colormap gray;
        [~,croprect] = imcrop(gcf);
        close(gcf);
        struct.rect = round(croprect);
    case 'manual'
        switch struct.resize
            case 'on'
                struct.rect = round(struct.manualcrop*struct.rescalefactor);
            case 'off'
                struct.rect = struct.manualcrop;
        end
    case 'full'
        xlen=s2;
        ylen=s1;
        struct.rect= [1,1,xlen,ylen];

end

end