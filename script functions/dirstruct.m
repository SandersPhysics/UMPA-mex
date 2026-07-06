function [outputArg1] = dirstruct(struct,varargin)
%dirstruct creates string for file navigation
%   Creates directory structure and returns platform name
if ispc
    struct.platform = 'Windows';
elseif ismac
    struct.platform = 'MacOS';
end
if strcmpi(varargin{1},'GUI') == 1
    struct.obj_folder = uigetdir(cd(fullfile('.')), 'Select the parent folder'); % use ui to specify main folder
    struct.main_folder = strcat(struct.obj_folder,filesep,'..',filesep);
else
    struct.main_folder = struct.dirstr;
    struct.obj_folder = strcat(strcat(struct.main_folder,filesep,struct.samplefolder));
end
struct.ref_folder  = strcat(strcat(struct.main_folder,filesep,struct.referencefolder));
struct.offset_location = strcat(struct.main_folder,filesep,struct.calibrationfolder);
struct.gain_location = strcat(struct.main_folder,filesep,struct.calibrationfolder);
struct.savedir = strcat(struct.obj_folder,strcat(filesep,'results'));

outputArg1 = struct;
end