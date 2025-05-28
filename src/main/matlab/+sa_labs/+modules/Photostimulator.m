classdef Photostimulator < symphonyui.ui.Module
    properties (Access = private)
        h
    end
    methods
        function createUi(self, figure_handle)
            self.h = figure_handle;
            set(self.h,'color','w');
            set(self.h,...
                'Name','Photostimulator',...
                'Position', appbox.screenCenter(1000,750));
        end

    end
end