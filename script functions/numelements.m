function [outputArg1] = numelements(dirpath)
% NUMELEMENTS Function to calculate the number of elements in a dirctory.
% This function uses the dir structure for the target directory and
% excludes the hidden files and folders in the path (files and folders that
% begin with a dot)
% Arthur W. Redgate
files = dir(dirpath);
files = files(~startsWith({files.name}, '.')); % Exclude hidden files
files = files(~startsWith({files.name}, 'results')); % Exclude results folder
files = files(~endsWith({files.name},'.db')); % Exclude 
numFiles = numel(files);
disp(['Number of files: ', num2str(numFiles)]);
outputArg1 = numFiles;
end