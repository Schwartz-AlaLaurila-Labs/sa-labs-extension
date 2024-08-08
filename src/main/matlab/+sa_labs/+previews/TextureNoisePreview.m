classdef TextureNoisePreview < symphonyui.core.ProtocolPreview
    
    properties (Access = private)
       vbox
       hbox
       ftax
       fsax
       imax
       getInfo
    end
    
    methods
        function self = TextureNoisePreview(panel, getInfo)
            self@symphonyui.core.ProtocolPreview(panel);
            self.getInfo = getInfo;
            self.createUi();
        end
        
        function createUi(self)
            import appbox.*;
             
            self.hbox = uix.HBox('Parent', self.panel);
            self.vbox = uix.VBox('Parent', self.hbox);
            self.ftax = axes( ...
                'Parent', self.vbox, ...
                'FontName', get(self.vbox, 'DefaultUicontrolFontName'), ...
                'FontSize', get(self.vbox, 'DefaultUicontrolFontSize')/3, ...
                'OuterPosition', [0,.5,1,.5]);
            self.fsax = axes( ...
                'Parent', self.vbox, ...
                'FontName', get(self.vbox, 'DefaultUicontrolFontName'), ...
                'FontSize', get(self.vbox, 'DefaultUicontrolFontSize')/3, ...
                'OuterPosition', [0,0,1,.5]);
            self.imax = axes( ...
                'Parent', self.hbox, ...
                'FontName', get(self.hbox, 'DefaultUicontrolFontName'), ...
                'FontSize', get(self.hbox, 'DefaultUicontrolFontSize')/3, ...
                'OuterPosition', [0,0,1,1]);
            self.update();
        end
        
        function update(self)
            [fs,ft,filt_s,filt_t] = self.getInfo();

            cla(self.ftax);
            plot(self.ftax, ft, filt_t,'linewidth',3);
            xlim(self.ftax,[0,10]);
            xlabel(self.ftax,'F (Hz)')

            cla(self.fsax);
            plot(self.fsax, fs(floor(end/2),:), filt_s(floor(end/2),:),'linewidth',3);
            xlim(self.fsax,[0,50]);
            xlabel(self.fsax,'F (1/mm)')

            tex = fftshift(fftn(randn(size(filt_s), 'single')));
            tex = real(ifftn(ifftshift(tex .* filt_s)));
            tex = (tex - mean(tex(:))) ./ std(tex(:));
            tex(tex >  3) =  3;
            tex(tex < -3) = -3;
            tex = uint8((tex+3)*(255/6));

            cla(self.imax);
            x = size(fs,2)./(fs(floor(end/2),end)/1000)/4;
            y = size(fs,1)./(fs(end,floor(end/2))/1000)/4;
            imagesc(self.imax, [-x,x], [-y,y], tex);
            colormap(self.imax,'gray');
            axis(self.imax,'equal');
            axis(self.imax,'tight');
            xlabel(self.imax,'Microns');
            
        end
    end
end

