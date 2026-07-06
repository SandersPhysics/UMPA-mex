function [outputArg1,outputArg2] = window_type(wintype,winsize)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
switch wintype
    case 'rectwin'
        winfunc = rectwin(winsize)*rectwin(winsize)';
    case 'bartlett'
        winfunc = bartlett(winsize)*bartlett(winsize)';
    case 'chebwin'
        winfunc = chebwin(winsize)*chebwin(winsize)';
    case 'bartlett-hann'
        winfunc = barthannwin(winsize)*barthannwin(winsize)';
    case 'hamming'
        winfunc = hamming(winsize)*hamming(winsize)';
    case 'blackman'
        winfunc = blackman(winsize)*blackman(winsize)';
    case 'custom'
        winfunc = ones(winsize)/(winsize).^2;
    case 'gaussian'
        winfunc = gausswin(winsize)*gausswin(winsize)';

end

winfunc = winfunc./sum(winfunc(:));
outputArg1 = winfunc;
outputArg2 = 1;
end