function outputArg1 = system_specs(struct)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
switch struct.architecture
    case 'GPU'
        if gpuDeviceCount == 1
            dev = gpuDevice();
            gpuName = dev.Name;
            struct.printName = gpuName;
            fprintf('GPU available: %s\n',gpuName)
        else
            cpuName = feature('GetCPU');
            struct.printName = cpuName;
            fprintf('WARNING: No GPU available\n ...defaulting to CPU\n')
            architecture  = 'CPU';
        end
    case 'CPU'
        cpuName = feature('GetCPU');
        struct.printName = cpuName;
end

outputArg1 = struct;
end