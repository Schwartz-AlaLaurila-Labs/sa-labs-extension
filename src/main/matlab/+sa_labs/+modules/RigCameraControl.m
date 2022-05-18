classdef RigCameraControl < symphonyui.ui.Module

    properties
        display
    end

    methods
        function createUi(self, figure_handle)
            set(figure_handle,...
                'Name','Rig Camera',...
                'Position', appbox.screenCenter(500, 550));

            layout = uix.VBox(...
                'parent', figure_handle,...
                'padding', 8);

            menu = uix.HBox(...
                'parent', layout,...
                'padding', 8);
            
            uicontrol(...
                'parent',menu,...
                'style','pushbutton',...
                'string','Start',...
                'Callback',@self.onStart);
            
            self.display = axes(...
                'parent',layout);

            set(layout, 'Heights', [30, -1]);
        end

        function start(self, ~, ~) 
            disp('Pressed start');
        end
    end

end