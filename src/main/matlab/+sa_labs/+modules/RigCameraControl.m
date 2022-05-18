classdef RigCameraControl < symphonyui.ui.Module

    properties
        display
        nrows = 3
        ncols = 3
        overlap = .1
        width = 720
        height = 480
    end

    properties (Dependent)
        mag
    end

    properties (Hidden)
        mags = {'10X','60X'}
        mag_ind = 1
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
                'style','edit',...
                'string',self.nrows,...
                'Callback', @self.onSetNRows);

            uicontrol(...
                'parent',menu,...
                'style','text',...
                'string','-by-');
            
            uicontrol(...
                'parent',menu,...
                'style','edit',...
                'string',self.ncols,...
                'Callback',@self.onSetNCols);
            
            uicontrol(...
                'parent',menu,...
                'style','text',...
                'string','Relative overlap: ');            
            
            uicontrol(...
                'parent',menu,...
                'style','edit',...
                'string',self.overlap,...
                'Callback',@self.onSetOverlap);
            
            uicontrol(...
                'parent',menu,...
                'style','listbox',...
                'string',self.mags,...
                'value',self.mag_ind,...
                'Callback',@self.onSetMag);   

            uicontrol(...
                'parent',menu,...
                'style','pushbutton',...
                'string','Start',...
                'Callback',@self.start);
            
            self.display = axes(...
                'parent',layout);

            set(layout, 'Heights', [50, -1]);
        end

        function self = onSetNRows(self, e, ~)
            self.nrows = str2double(e.String);
        end
        
        function self = onSetNCols(self, e, ~)
            self.ncols = str2double(e.String);
        end

        function self = onSetOverlap(self, e, ~) 
            self.overlap = str2double(e.String);
        end
        
        function self = onSetMag(self, e, ~) 
            self.mag_ind = e.Value;
        end        

        function mag = get.mag(self)
            mag = self.mags(self.mag_ind);
        end

        function start(self, ~, ~)            
            scale = (1-self.overlap) .* self.pix2um(self.mag) .* [self.width, self.height];
            [x,y] = meshgrid( - (self.ncols/2 - .5) :  (self.ncols/2 - .5), - (self.nrows/2 - .5) :  (self.nrows/2 - .5));
            
            x = x .* scale(1);
            y = y .* scale(2);

            for n = 1:numel(x)
                %%      move to (x,y)
                %%   take image
                %%   stitch?
                %%   display image
            end

        end
    end

end