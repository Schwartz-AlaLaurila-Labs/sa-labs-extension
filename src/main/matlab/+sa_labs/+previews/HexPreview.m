classdef HexPreview < symphonyui.core.ProtocolPreview
    
    properties
       getInfo 
    end
    
    
    properties (Access = private)
       axes 
    %    render
    end
    
    methods
        function self = HexPreview(panel, getInfo)
            self@symphonyui.core.ProtocolPreview(panel);
            self.getInfo = getInfo;
            self.createUi();
        end
        
        function createUi(self)
            self.axes = axes( ...
                'Parent', self.panel, ...
                'FontName', get(self.panel, 'DefaultUicontrolFontName'), ...
                'FontSize', get(self.panel, 'DefaultUicontrolFontSize'), ...
                'Position', [0,0,1,1]); %#ok<CPROP>
            axis(self.axes, 'off');
            self.update();
        end
        
        function update(self)
            cla(self.axes);
            
            pyx = self.panel.Position([4,3]);
            render = zeros(pyx,3);

            [spots, rect] = self.getInfo();
            [rads,~,radI] = unique(spots(:,3));
            nRads = numel(rads)
            
            if nRads > 7
                colors = colorcube(nRads);
            else
                colors = lines(nRads);
            end

            ratio = min(pyx ./ rect(3:4)) * .8; %take the larger ratio
            spots = spots * ratio;
            spots(:,1:2) = spots(:,[2, 1]) + pyx./2;
            rect = rect * ratio;
            rect(1:2) = rect(1:2) + pyx./2;
            %the box will now fill 80% of the smaller axis (y)

            render = insertShape(render, 'filledcircle', spots, 'color', colors(radI,:), 'opacity', .2, 'smoothedges', false);
            
            render = insertShape(render, 'rectangle', rect, 'color', 'white', 'linewidth', 3);

            %colorcub
            imshow(render, 'parent', self.axes);
        end
    end
end

