function XRPD_PNG(image_struct,struct,varargin)
%processedFig make parameter based png
%   Detailed explanation goes here
%% --------------------------Image display--------------------------
blur = @(x,sigma) imgaussfilt(x,sigma);
if isempty(varargin{1})
    sig1 = 2;
    sig2 = 2;
else
sig1 = varargin{1};
sig2 = varargin{2};
end

fx=5;
fy=fx;
filt_size = [fx,fy];
a = datestr(now, 'dd-mmm-yyyy_HHMMSS');
figure; sgtitle(append(struct.version,': ',num2str(struct.imgend),' ','shifts; ','runtime = '...
    ,num2str(struct.runtime_seconds),' s; placeholder: ',struct.printName))
subplot(2,2,1); imagesc((blur(medfilt2(image_struct(1).data),sig1))); colormap gray; axis image, title('attenuation'); colorbar; clim([0,1])
subplot(2,2,2); imagesc(blur(medfilt2(image_struct(2).data,[fx,fy]),sig1)); colormap gray; axis image, title('dark-field'); colorbar; clim([0,1])
subplot(2,2,3); imagesc(blur(medfilt2(real(image_struct(3).data),[fx,fy]),sig2)); colormap gray; axis image, title('dx'); colorbar; clim([-1,1])
subplot(2,2,4); imagesc(blur(medfilt2(real(image_struct(4).data),[fx,fy]),sig2)); colormap gray; axis image, title('dy'); colorbar; clim([-1,1])
saveas(gcf,strcat(struct.savedir,filesep,struct.version,'.png'));

end