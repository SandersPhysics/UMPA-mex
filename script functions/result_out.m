function result_out(struct)
% Checks for the existence of reference directory and creates the
% associated results folder
%   Arthur W. Redgate: University at Albany
refcheckdir = struct.ref_folder;
savedir = struct.savedir;
switch struct.mode
    case 'df'
        struct.version = append(struct.version,'-',struct.mode);
end
if strcmpi(struct.savefiles,'off') == 1
    fprintf('Warning: file save is off \n');
end

if isfolder(refcheckdir) == 1
    if isfolder(strcat(savedir,filesep, struct.version)) == 1
        fprintf('Results folder already exists \n')
        return
    else
        fprintf('Creating results folder \n')
        mkdir(strcat(savedir,filesep, struct.version))
    end
else
    error('Invalid location, please check spelling and make sure the file location exists:')
end