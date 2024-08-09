classdef RFmapper < symphony.ui.Module & symphonyui.core.FigureHandler
% for the time being, this only operates with the PairedSpotField stimulus

properties (Access = private)
    h
    extentR = 400
    spotDiam = 15
    spacing = 15
    grid = []

    gridSc

    gridAx
    lastSpotsAx
    lastRasterAx 
    lastTopSpotAx
    lastTraceAx
end

methods
    function createUi(self, figure_handle)
        self.h = figure_handle;
        set(h,...
            'Name','RF Mapper',...
            'Position', appbox.screenCenter(1000,750));
        
        layout = uix.VBox(...
            'parent', h,...
            'padding', 8);

        menu = uix.HBox(...
            'parent', layout,...
            'padding', 8);
        
        uicontrol(...
           'parent', menu,...
           'style', 'edit',...
           'string', self.extentR,...
           'tooltip', 'Extent of grid (microns)',...
           'Callback', @self.setExtentR);
        
        uicontrol(...
            'parent', menu,...
            'style', 'edit',...
            'string', self.spotDiam,...
            'tooltip', 'Diameter of spots (microns)',...
            'Callback', @self.setSpotDiam);

        uicontrol(...
            'parent', menu,...
            'style', 'edit',...
            'string', self.spacing,...
            'tooltip', 'Distance between spot centers (microns)',...
            'Callback', @self.setSpacing);

        uicontrol(...
            'parent', menu,...
            'style', 'popupmenu',...
            'string', {'0','1','2','1+2'},...
            'tooltip', 'Order of neighbors to test');

        uicontrol(...
            'parent', menu,...
            'style', 'pushbutton',...
            'string', 'Record',...
            'Callback', @self.run);

        displayTop = uix.HBox(...
            'parent', layout,...
            'padding', 8);

        self.gridAx = axes(...
            'parent', displayTop,...
            'units', 'points',...
            'color', 'none');

        self.lastSpotsAx = axes(...
            'parent', displayTop,...
            'units', 'points',...
            'color', 'none');

        displayRight = uix.VBox(...
            'parent', displayTop,...
            'padding', 8);
        
        self.lastRasterAx = axes(...
            'parent', displayRight,...
            'color', 'none');
    
        self.lastTopSpotAx = axes(...
            'parent', displayRight,...
            'color', 'none');
        
        self.lastTraceAx = axes(...
            'parent', layout,...
            'color', 'none');


        self.gridSc = scatter(self.gridAx,...
            [],[],'k','linewidth', 3);        
        
        set(layout, 'Heights', [50, -1]);
        set(displayTop, 'Widths', [2,2,1]);
        self.updateGrid();

    end

    function setExtentR(self, e, ~)
        self.extentR = str2double(e.String);
        self.updateGrid();
    end

    function setSpotDiam(self, e, ~)
        self.spotDiam = str2double(e.String);
        self.updateGrid();
    end

    function setSpacing(self, e, ~)
        self.spacing = str2double(e.String);
        self.updateGrid();
    end


    function updateGrid(self)
        xa = [0:-self.spacing:-self.extentR/2-self.spacing, self.spacing:self.spacing:self.extentR/2+self.spacing];
        xb= [xa - self.spacing/2, xa(end)+self.spacing/2];
        yspacing = cos(pi/6)*self.spacing;
        ya = [0:-2*yspacing:-self.extentR/2-yspacing, 2*yspacing:2*yspacing:self.extentR/2+yspacing];
        yb = [ya - yspacing, ya(end) + yspacing];

        %create the grid
        [xqa, yqa] = meshgrid(xa,ya);
        [xqb, yqb] = meshgrid(xb,yb);
        locs = [xqa(:), yqa(:); xqb(:), yqb(:)];

        halfGrids = [self.extentR, self.extentR]/2;
        %remove any circles that aren't contained by the grid circumference
        self.grid = locs(sum(locs .^2, 2) <= (self.extentR .^2), :);

        axpos =  get(self.gridAx, 'position');
        msz = self.spotDiam / diff(xlim(self.gridAx)) * axpos(3);

        set(self.gridSc, 'xdata', self.grid(:,1), 'ydata', self.grid(:,2), 'sizedata', msz.^2, 'cdata', 'k');
        axis(self.gridAx,'equal');
    end

    function run(self)
        % self.acquisitionService.selectProtocol('sa_labs.protocols.stage.PairedSpotField');

        % % set the properties based on the menu items
        % % self.acquisitionService.setProtocolProperty();

        % self.acquisitionService.record()



        % % check if running
        % % self.acquisitionService.getControllerState() 

        % % handle state change
        % % addListener(obj.acquisitionService, 'ChangedControllerState, @...)

        % % obj.documentationService.getCurrentEpochBlock(obj)

    end

    function updateFigures(self, epochOrInterval)
        if epochOrInterval.isInterval()
            return
        else
            epoch = epochOrInterval;
        end
        
        % ...

    end

    function h = showFigure(self, className, varargin)
        h = self.h;
    end

    function clearFigures(self)
        %pass
    end

    function closeFigures(self)
        %pass
    end


end


% step 1: layout the grid
% step 2: run unpaired spots (0-order neighbors)
% step 3: draw the RF map
% step 4: select the spots that pass the threshold, without holes
% step 5: run the paired spots (1-order neighbors)
% step 6: draw the graph
% step 7: repeat 5 & 6 for 2-order neighbors

end