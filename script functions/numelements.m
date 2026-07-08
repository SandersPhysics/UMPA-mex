function outputArg1 = numelements(dirpath)
%NUMELEMENTS Count supported image files in a directory.

if ~isfolder(dirpath)
    error('numelements:MissingFolder', ...
        'Folder does not exist: %s', dirpath);
end

files = dir(dirpath);
files = files(~[files.isdir]);

names = {files.name};

valid_ext = {'.tif', '.tiff', '.png', '.jpg', '.jpeg', '.bmp'};
[~, ~, ext] = cellfun(@fileparts, names, 'UniformOutput', false);

is_image = ismember(lower(ext), valid_ext);
is_hidden = startsWith(names, '.');
is_system = strcmpi(names, 'Thumbs.db') | strcmpi(names, 'desktop.ini');

files = files(is_image & ~is_hidden & ~is_system);

numFiles = numel(files);

disp(['Number of image files: ', num2str(numFiles)]);

if numFiles == 0
    error('numelements:NoImagesFound', ...
        'No supported image files found in folder: %s', dirpath);
end

outputArg1 = numFiles;

end