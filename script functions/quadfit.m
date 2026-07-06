function [x_sub,y_sub,surf] = quadfit(Z,varargin)
% This function computes a quadratic fit to the data, and outputs the fit
% function as a gassian matrix of the same size as the input matrix. This
% function is suitable to use in conjunction with Matlab's rapid extremum
% search for a highly parallelized quad fit min search. The function also
% has the ability to refine the grid of the input matrix to create a finer
% mesh for sub integer localization.
% Written by Arthur Redgate Spring 2026
% Linear algebra expression solution written by Jonathan Petruccelli
%-----------------------------------------------

[xSize, ySize] = size(Z);
[X, Y] = meshgrid(1:ySize, 1:xSize);
% Reshape the matrices into vectors for fitting
x = X(:);
y = Y(:);
z = Z(:);
% Construct the design matrix
X = [x(:).^2, y(:).^2, x(:).*y(:), x(:), y(:), ones(size(x(:)))];
% Compute the coefficients using least squares
coeff = X \ z(:);
% Extract coefficients
% Solve for stationary point
a = coeff(1); b = coeff(2); c = coeff(3);
d = coeff(4); e = coeff(5); f = coeff(6);
M = [2*a, c; c, 2*b];
rhs = -[d; e];
offset = M \ rhs;

% Subpixel coordinates relative to center pixel
x_sub = offset(1);
y_sub = offset(2);
val_sub = coeff(1)*offset(1)^2 + coeff(2)*offset(2)^2 + ...
    coeff(3)*offset(1)*offset(2) + coeff(4)*offset(1) + ...
    coeff(5)*offset(2) + coeff(6);

if length(varargin)>=1
    mesh_xresize = varargin{1}*xSize;
    mesh_yresize = varargin{1}*ySize;
    [X_grid, Y_grid] = meshgrid(linspace(min(x), max(x), varargin{1}*xSize), linspace(min(y), max(y), varargin{1}*ySize));
    surf = (a*X_grid.^2 + b*Y_grid.^2 + c*X_grid.*Y_grid + d*X_grid + e*Y_grid + f)/mesh_xresize;
else
    [X_grid, Y_grid] = meshgrid(linspace(min(x), max(x), xSize), linspace(min(y), max(y), ySize));
    surf = a*X_grid.^2 + b*Y_grid.^2 + c*X_grid.*Y_grid + d*X_grid + e*Y_grid + f;
end
end