function [outputArg1,outputArg2] = coordinate_extremum_finder(inputArg1,str)
% finds the minimum coordinate values of the input matrix
switch str
    case 'min'
    [tempmin1,tempmin2] = min(inputArg1(:));
    [tempx,tempy] = ind2sub(size(inputArg1),tempmin2);
    outputArg1 = tempx;
    outputArg2 = tempy;
    case 'max'
    [tempmin1,tempmin2] = max(inputArg1(:));
    [tempx,tempy] = ind2sub(size(inputArg1),tempmin2);
    outputArg1 = tempx;
    outputArg2 = tempy;
end