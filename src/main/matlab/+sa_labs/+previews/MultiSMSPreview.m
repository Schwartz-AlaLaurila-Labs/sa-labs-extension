classdef MultiSMSPreview < symphonyui.core.ProtocolPreview
    
    properties
       getInfo 
    end
    
    
    properties (Access = private)
       axes 
    %    render
    end
    
    methods
        function self = MultiSMSPreview(panel, getInfo)
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
            render = zeros([pyx,3]);

            [spots, rect] = self.getInfo();
            [~,spotsI] = sort(spots(:,3),'descend');
            spots = spots(spotsI,:);
            
            [rads,~,radI] = unique(spots(:,3));
            nRads = numel(rads);
            
            if nRads > 7
                colors = colorcube(nRads);
            else
                colors = lines(nRads);
            end

            ratio = min(pyx ./ rect([4,3])) * .4; %take the larger ratio
            spots = spots * ratio;
            spots(:,1:2) = spots(:,1:2) + pyx([2,1])./2;
            spots(:,3) = spots(:,3) / 2;
            rect = rect * ratio;
            rect(1:2) = rect(1:2) + pyx([2,1])./2;
           
            render = insertShape(render, 'filledcircle', spots, 'color', colors(radI,:), 'opacity', .2, 'smoothedges', false);
            
            render = insertShape(render, 'rectangle', rect, 'color', 'white', 'linewidth', 3);

            %colorcub
            imshow(render, 'parent', self.axes);
        end
    end
end

