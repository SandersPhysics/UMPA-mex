function MEXbuilder()
%MEXBUILDER Build all MEX targets used by the fast UMPA MATLAB path.

builder_file = mfilename('fullpath');
builder_dir = fileparts(builder_file);

source_dir = fullfile(builder_dir, 'mex_source');
bin_root = fullfile(builder_dir, 'mex_bin');
bin_dir = fullfile(bin_root, computer('arch'));

ensure_folder(source_dir);
ensure_folder(bin_dir);

write_build_test_source(source_dir);

openmp_args = { ...
    'CXXFLAGS=$CXXFLAGS -fopenmp', ...
    'LDFLAGS=$LDFLAGS -fopenmp' ...
};

targets = {
    struct( ...
        'name', 'build_test_mex', ...
        'source', fullfile(source_dir, 'build_test_mex.cpp') ...
    )
    struct( ...
        'name', 'umpa_core_mex', ...
        'source', fullfile(source_dir, 'umpa_core_mex.cpp'), ...
        'mex_args', {openmp_args} ...
    )
    struct( ...
        'name', 'image_cleanup_mex', ...
        'source', fullfile(source_dir, 'image_cleanup_mex.cpp'), ...
        'mex_args', {openmp_args} ...
    )
};

fprintf('\nMEXbuilder root folder:\n  %s\n', builder_dir);
fprintf('Source folder:\n  %s\n', source_dir);
fprintf('Binary folder:\n  %s\n', bin_dir);
fprintf('Platform architecture:\n  %s\n', computer('arch'));
fprintf('MEX extension:\n  .%s\n', mexext);

fprintf('\nTargets:\n');
for k = 1:numel(targets)
    fprintf('  %s\n', targets{k}.name);
end

for k = 1:numel(targets)
    build_target(targets{k}, bin_dir);
end

addpath(bin_dir);

y = build_test_mex(41);

fprintf('\nbuild_test_mex(41) returned %.1f\n', y);

if y == 42
    disp('MEXbuilder test passed.');
else
    error('MEXbuilder:TestFailed', ...
        'build_test_mex failed: expected 42, got %.12g.', y);
end

end


function ensure_folder(folder_path)

if ~exist(folder_path, 'dir')
    mkdir(folder_path);
end

end


function build_target(target, bin_dir)

fprintf('\nBuilding target: %s\n', target.name);

if ~exist(target.source, 'file')
    error('MEXbuilder:MissingSource', ...
        'Missing source file for target "%s": %s', target.name, target.source);
end

clear(target.name);

mex_args = {};
if isfield(target, 'mex_args')
    mex_args = target.mex_args;
end

mex( ...
    '-v', ...
    mex_args{:}, ...
    '-outdir', bin_dir, ...
    '-output', target.name, ...
    target.source ...
);

end


function write_build_test_source(source_dir)

source_file = fullfile(source_dir, 'build_test_mex.cpp');

cpp_lines = {
    '#include "mex.h"'
    ''
    'void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])'
    '{'
    '    if (nrhs != 1) {'
    '        mexErrMsgIdAndTxt("build_test_mex:nrhs", "One input required.");'
    '    }'
    ''
    '    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0]) || mxGetNumberOfElements(prhs[0]) != 1) {'
    '        mexErrMsgIdAndTxt("build_test_mex:input", "Input must be one real double scalar.");'
    '    }'
    ''
    '    double x = mxGetScalar(prhs[0]);'
    '    plhs[0] = mxCreateDoubleScalar(x + 1.0);'
    '}'
};

fid = fopen(source_file, 'w');

if fid < 0
    error('MEXbuilder:CannotWriteBuildTest', ...
        'Could not open source file for writing: %s', source_file);
end

cleanup_obj = onCleanup(@() fclose(fid));

for k = 1:numel(cpp_lines)
    fprintf(fid, '%s\n', cpp_lines{k});
end

end