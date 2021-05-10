classdef HexPreview < symphonyui.core.ProtocolPreview
    
    properties
       getInfo 
    end
    
    
    properties (Access = private)
       axes 
    end
    
    methods
        function self = HexPreview(panel, getInfo)
            self@symphonyui.core.ProtocolPreview(panel);
            self.getInfo = getInfo;
        end
        
        function createUi(self)
            self.axes = axes( ...
                'Parent', self.panel, ...
                'FontName', get(self.panel, 'DefaultUicontrolFontName'), ...
                'FontSize', get(self.panel, 'DefaultUicontrolFontSize'), ...
                'Color', 'black'); %#ok<CPROP>
            self.update();
        end
        
        function update(self)
            cla(self.axes);
            text(10,10,'test','color','white');
            
            %colorcub
        end
    end
end

