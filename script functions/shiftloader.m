function [outputArg1,outputArg2] = shiftloader(struct)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
objdir = dir(fullfile(struct.obj_folder,'*.tif'));
objdir = objdir(~ismember({objdir.name}, {'.', '..'}));
mask1 = startsWith({objdir.name}, '._');
mask2 = endsWith({objdir.name},'*.db');
objdir(mask1) = [];
objdir(mask2) = [];

refdir = dir(fullfile(struct.ref_folder,'*.tif'));
refdir = refdir(~ismember({refdir.name}, {'.', '..'}));
mask = startsWith({refdir.name}, '._');
refdir(mask) = [];
% objload = zeros(struct.rect(4)+1,struct.rect(3)+1,numel(objdir));
switch struct.resize
    case 'on'
        for k = 1:numel(objdir)
            F = dir(fullfile(struct.obj_folder,objdir(k).name));
            objdir(k).data = imcrop(imresize(double(imread(strcat(F.folder,filesep,F.name))),struct.rescalefactor),struct.rect);
            objload(:,:,k) = objdir(k).data;
        end
        for k = 1:numel(refdir)
            F = dir(fullfile(struct.ref_folder,refdir(k).name));
            refdir(k).data = imcrop(imresize(double(imread(strcat(F.folder,'/',F.name))),struct.rescalefactor),struct.rect);
            shiftedrefload(:,:,k) =refdir(k).data; 
        end
    case 'off'
        for k = 1:numel(objdir)
            F = dir(fullfile(struct.obj_folder,objdir(k).name));
            objdir(k).data = imcrop(double(imread(strcat(F.folder,filesep,F.name))),struct.rect);
            objload(:,:,k) = objdir(k).data;
        end
        for k = 1:numel(refdir)
            F = dir(fullfile(struct.ref_folder,refdir(k).name));
            refdir(k).data = imcrop(double(imread(strcat(F.folder,'/',F.name))),struct.rect);
            shiftedrefload(:,:,k) =refdir(k).data; 
        end
end
outputArg1 = objload;
outputArg2 = shiftedrefload;
end