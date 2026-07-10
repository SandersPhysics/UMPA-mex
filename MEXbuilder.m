function MEXbuilder()
%MEXBUILDER Build all MEX targets used by the fast UMPA MATLAB path.

builder_file = mfilename('fullpath');
builder_dir = fileparts(builder_file);

root_dir = fileparts(mfilename('fullpath'));

source_dir = fullfile(root_dir, 'script functions', 'mex_source');
bin_root   = fullfile(root_dir, 'script functions', 'mex_bin');
bin_dir    = fullfile(bin_root, computer('arch'));

ensure_folder(source_dir);
ensure_folder(bin_dir);

write_build_test_source(source_dir);

openmp_args = get_openmp_args();

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


function openmp_args = get_openmp_args()
%GET_OPENMP_ARGS Return platform-specific OpenMP MEX flags.

if ismac
    arch = computer('arch');

    omp_include = fullfile( ...
        matlabroot, ...
        'toolbox', ...
        'eml', ...
        'externalDependency', ...
        'omp', ...
        arch, ...
        'include');

    omp_runtime_dir = fullfile(matlabroot, 'bin', arch);
    omp_runtime = fullfile(omp_runtime_dir, 'libomp.dylib');
    omp_header = fullfile(omp_include, 'omp.h');

    if ~isfile(omp_header)
        error('MEXbuilder:MissingMatlabOpenMPHeader', ...
            ['Could not find MATLAB''s bundled omp.h file:' newline ...
             '  %s'], omp_header);
    end

    if ~isfile(omp_runtime)
        error('MEXbuilder:MissingMatlabOpenMPRuntime', ...
            ['Could not find MATLAB''s bundled libomp.dylib:' newline ...
             '  %s'], omp_runtime);
    end

    fprintf('\nmacOS OpenMP support:\n');
    fprintf('  Header folder: %s\n', omp_include);
    fprintf('  Runtime:       %s\n', omp_runtime);

    openmp_args = { ...
        sprintf( ...
            'CXXFLAGS=$CXXFLAGS -Xpreprocessor -fopenmp -I"%s"', ...
            omp_include), ...
        sprintf( ...
            'LDFLAGS=$LDFLAGS -L"%s" -lomp -Wl,-rpath,"%s"', ...
            omp_runtime_dir, ...
            omp_runtime_dir) ...
    };

else
    fprintf('\nOpenMP support:\n');
    fprintf('  Using standard -fopenmp compiler/linker flags.\n');

    openmp_args = { ...
        'CXXFLAGS=$CXXFLAGS -fopenmp', ...
        'LDFLAGS=$LDFLAGS -fopenmp' ...
    };
end

end


function omp_prefix = find_mac_libomp()
%FIND_MAC_LIBOMP Locate Homebrew libomp on macOS.
%
% MATLAB on macOS may not inherit the same PATH as Terminal, especially
% when opened from Finder/Dock. Therefore, check standard Homebrew libomp
% locations before relying on the brew command.

candidate_paths = { ...
    '/opt/homebrew/opt/libomp', ...  % Apple Silicon Homebrew default
    '/usr/local/opt/libomp' ...      % Intel Homebrew default
};

for k = 1:numel(candidate_paths)
    if isfolder(candidate_paths{k})
        omp_prefix = candidate_paths{k};
        return
    end
end

brew_commands = { ...
    '/opt/homebrew/bin/brew --prefix libomp', ...
    '/usr/local/bin/brew --prefix libomp', ...
    'brew --prefix libomp' ...
};

for k = 1:numel(brew_commands)
    [status, cmdout] = system(brew_commands{k});

    if status == 0
        omp_prefix = strtrim(cmdout);

        if isfolder(omp_prefix)
            return
        end
    end
end

error('MEXbuilder:MissingLibomp', ...
    ['Could not find Homebrew libomp.' newline newline ...
     'Open Terminal and run:' newline ...
     '  brew install libomp' newline newline ...
     'Then restart MATLAB and run MEXbuilder again.' newline newline ...
     'Expected libomp locations:' newline ...
     '  /opt/homebrew/opt/libomp' newline ...
     '  /usr/local/opt/libomp']);

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