function [outputArg1, outputArg2] = shiftloader(struct)
%SHIFTLOADER Load sample and reference image stacks.

objdir = dir(struct.obj_folder);
objdir = objdir(~[objdir.isdir]);
objdir = filter_image_files(objdir);

refdir = dir(struct.ref_folder);
refdir = refdir(~[refdir.isdir]);
refdir = filter_image_files(refdir);

if isempty(objdir)
    error('shiftloader:NoSampleImages', ...
        'No supported sample images found in folder: %s', struct.obj_folder);
end

if isempty(refdir)
    error('shiftloader:NoReferenceImages', ...
        'No supported reference images found in folder: %s', struct.ref_folder);
end

if numel(objdir) ~= numel(refdir)
    error('shiftloader:ImageCountMismatch', ...
        'Sample and reference image counts do not match. Sample: %d, Reference: %d.', ...
        numel(objdir), numel(refdir));
end

switch struct.resize
    case 'on'
        for k = 1:numel(objdir)
            img = double(imread(fullfile(objdir(k).folder, objdir(k).name)));
            img = imresize(img, struct.rescalefactor);
            objload(:,:,k) = imcrop(img, struct.rect);
        end

        for k = 1:numel(refdir)
            img = double(imread(fullfile(refdir(k).folder, refdir(k).name)));
            img = imresize(img, struct.rescalefactor);
            shiftedrefload(:,:,k) = imcrop(img, struct.rect);
        end

    case 'off'
        for k = 1:numel(objdir)
            img = double(imread(fullfile(objdir(k).folder, objdir(k).name)));
            objload(:,:,k) = imcrop(img, struct.rect);
        end

        for k = 1:numel(refdir)
            img = double(imread(fullfile(refdir(k).folder, refdir(k).name)));
            shiftedrefload(:,:,k) = imcrop(img, struct.rect);
        end

    otherwise
        error('shiftloader:BadResizeToggle', ...
            'Unknown resize option: %s. Use ''on'' or ''off''.', struct.resize);
end

outputArg1 = objload;
outputArg2 = shiftedrefload;

end


function files = filter_image_files(files)

names = {files.name};

valid_ext = {'.tif', '.tiff', '.png', '.jpg', '.jpeg', '.bmp'};
[~, ~, ext] = cellfun(@fileparts, names, 'UniformOutput', false);

is_image = ismember(lower(ext), valid_ext);
is_hidden = startsWith(names, '.');
is_system = strcmpi(names, 'Thumbs.db') | strcmpi(names, 'desktop.ini');

files = files(is_image & ~is_hidden & ~is_system);

[~, idx] = sort(lower({files.name}));
files = files(idx);

end