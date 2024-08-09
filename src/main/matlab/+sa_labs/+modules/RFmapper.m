classdef RFmapper < symphonyui.ui.Module & symphonyui.core.FigureHandler
% for the time being, this only operates with the PairedSpotField stimulus

properties (Access = private)
    h
    extentR = 200
    spotDiam = 30
    spacing = 30
    grid = []
    pairs1 = []
    pairs2 = []
    order = '0'

    gridSc
    lastSpotsSc

    gridAx
    lastSpotsAx
    lastRasterAx 
    lastTopSpotAx
    lastTraceAx
    
    params
    spikeDetector
end

methods
    function createUi(self, figure_handle)
        self.h = figure_handle;
        set(self.h,...
            'Name','RF Mapper',...
            'Position', appbox.screenCenter(1000,750));
        
        layout = uix.VBox(...
            'parent', self.h,...
            'padding', 8);

        menu = uix.HBox(...
            'parent', layout,...
            'padding', 8);
        
        uicontrol(...
           'parent', menu,...
           'style', 'edit',...
           'string', self.extentR,...
           'tooltip', 'Radius of grid (microns)',...
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
            'tooltip', 'Order of neighbors to test',...
            'Callback', @self.setOrder);
        
        uicontrol(...
            'parent', menu,...
            'style', 'pushbutton',...
            'string', 'Draw RF',...
            'Callback', @self.draw);

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
            'color', 'none',...
            'ycolor', 'none');

        self.lastSpotsAx = axes(...
            'parent', displayTop,...
            'units', 'points',...
            'color', 'none',...
            'ycolor', 'none');

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

        hold(self.gridAx, 'on');
        title(self.gridAx, 'RF map');
        xlabel(self.gridAx, 'Position (microns)');
        xlim(self.gridAx,[-self.extentR, self.extentR]);
        ylim(self.gridAx,[-self.extentR, self.extentR]);
        self.gridSc = scatter(self.gridAx,...
            [],[],'k','linewidth', 2);        
        
        hold(self.lastSpotsAx, 'on');
        title(self.lastSpotsAx, 'Last epoch map');
        xlabel(self.lastSpotsAx, 'Position (microns)');
        xlim(self.lastSpotsAx,[-self.extentR, self.extentR]);
        ylim(self.lastSpotsAx,[-self.extentR, self.extentR]);
        self.lastSpotsSc = scatter(self.gridAx,...
            [],[],'k','linewidth', 2);        
        
        
        set(layout, 'Heights', [40, -1, -1]);
        set(displayTop, 'Widths', [-2, -2, -1]);
        
        self.updateGrid();
    end

    function setExtentR(self, e, ~)
        self.extentR = str2double(e.String);
        self.updateGrid();
    end

    function setSpotDiam(self, e, ~)
        self.spotDiam = str2double(e.String);
        self.updateGrid(); %TODO: only need to redraw
    end

    function setSpacing(self, e, ~)
        self.spacing = str2double(e.String);
        self.updateGrid();
    end
    
    function setOrder(self, e, ~)
        self.order = e.String;
    end


    function updateGrid(self)
        xa = [0:-self.spacing:-self.extentR-self.spacing, self.spacing:self.spacing:self.extentR+self.spacing];
        xb = [xa - self.spacing/2, xa(end)+self.spacing/2];
        yspacing = cos(pi/6)*self.spacing;
        ya = [0:-2*yspacing:-self.extentR-yspacing, 2*yspacing:2*yspacing:self.extentR+yspacing];
        yb = [ya - yspacing, ya(end) + yspacing];

        %create the grid
        [xqa, yqa] = meshgrid(xa,ya);
        [xqb, yqb] = meshgrid(xb,yb);
        locs = [xqa(:), yqa(:); xqb(:), yqb(:)];

        %remove any circles that aren't contained by the grid circumference
        self.grid = locs(sum(locs.^2, 2) <= (self.extentR.^2), :);
        
        xlim(self.gridAx,[-self.extentR, self.extentR]);
        ylim(self.gridAx,[-self.extentR, self.extentR]);
        
        axpos =  get(self.gridAx, 'position');
        msz = self.spotDiam / sqrt(pi) / diff(xlim(self.gridAx)) * axpos(3);

        set(self.gridSc, 'xdata', self.grid(:,1), 'ydata', self.grid(:,2), 'sizedata', msz.^2, 'cdata', [0,0,0]);
        axis(self.gridAx,'equal');
        
        
        %% generate first and second order pairs
        d = pdist(self.grid);
        p = d < (self.spacing * 1.5);
        p = triu(squareform(p),1);
        [r,c] = find(p);
        self.pairs1 = [r,c];
        
        p = (d > (self.spacing * 1.5)) & (d < (self.spacing * 2.5));
        p = triu(squareform(p),1);
        [r,c] = find(p);
        self.pairs2 = [r,c];
        
    end
    
    function draw(self)
        % draw polygon on self.gridAx;
        % find all pairs of each order inPolygon
        % delete polygon and draw pretty polygon...
        % set state so that run() only uses pairs inpolygon...
        
        % only inPolygon if both spots in pair are inpolygon...
        
    end

    function run(self, ~, ~)
        self.acquisitionService.selectProtocol('sa_labs.protocols.stage.PairedSpotField');

        % % set the properties based on the menu items
        self.acquisitionService.setProtocolProperty('spotSize',self.spotDiam);
        
        switch self.order
            % note that setter reshapes pairs into N-by-(a,b)-by-(x,y)
            case '0'
                self.acquisitionService.setProtocolProperty('spotPairs',cat(1,self.grid,self.grid));
            case '1'
                self.acquisitionService.setProtocolProperty('spotPairs',self.grid(self.pairs1,:));
            case '2'
                self.acquisitionService.setProtocolProperty('spotPairs',self.grid(self.pairs2,:));
            case '1+2'                
                self.acquisitionService.setProtocolProperty('spotPairs',self.grid(cat(1,self.pairs1,self.pairs2),:));
        end

        self.params = self.acquisitionService.getProtocolPropertyDescriptors().toMap();
        
        self.spikeDetector = sa_labs.util.SpikeDetector(self.params('spikeDetectorMode'),...
            self.params('spikeThreshold'));
        % etc...
        
        % set(lastTraceTr, 'xdata', ..., 'ydata', zeros)
        self.acquisitionService.record()

        % % check if running
        % % self.acquisitionService.getControllerState() 

        % % handle state change
        % % addListener(obj.acquisitionService, 'ChangedControllerState, @...)


    end

    function updateFigures(self, epoch)
        if epoch.isInterval()
            return
        end
%         properties = self.acquisitionService.getProtocolPropertyDescriptors();
        properties = epoch.parameters;
        
        
        %% Epoch-wise plots
        % update the bottom trace
        response = epoch.getResponse('Amp1');
        [dat, ~] = response.getData();
        
        samplesPerSpot = (properties('spikePreFrames') + properties('spikeStimFrames') + properties('spikeTailFrames')) / properties('frameRate') * properties('sampleRate');
        
        spikeI = self.spikeDetector.detectSpikes(dat);
        spikeI = spikeI.sp - properties('preTime') * 1e-3 * properties('sampleRate');
        spikeI(spikeI < 0) = [];
        spikeI(spikeI >= properties('stimTime') * 1e-3 * properties('sampleRate')) = [];
                
        spikeS = floor(spikeI / samplesPerSpot) + 1;
        
        % accumulate the spike count
        countS = accumarray(spikeS', 1, [properties('spotsPerEpoch'),1], @sum, 0);
        
        % update the last spots map
        cx = properties('cx');
        cy = properties('cy');
        % set('xdata','ydata','cdata')...
        
        % divide spike indices by numSpots per epoch
        % update the raster map
        spikeE = mod(spikeI-1, samplesPerSpot) + 1;
        % line(spikeE, spikeS,...)
        
        % draw the section of trace with most spikes
        exampleS = mode(spikeS);
        % set('ydata',dat(properties('sampleRate')*properties('preTime') +
        %   samplesPerSpot*(exampleS-1 : exampleS) + 1))
        
        
        %% RF map
        
        % accumulate the spike and trial counts for each spot/pair index 
        % pairI = func(cx,cy) -> index
        
        % if order 0
        %   gridSpikeCounts(pairI) += countS
        %   gridTrialCounts(pairI) += ??
        %   set(gridSc, 'cdata', gridSpikeCount / gridTrialCounts)
        % elseif order 1
        %   pair1SpikeCounts(pairI) += countS
        %   pair1TrialCounts(pairI) += ??
        %   set(gridLines1, 'cdata', pair1SpikeCount / pair1TrialCounts)
        % elseif order 2
        %   pair2SpikeCounts(pairI) += countS
        %   pair2TrialCounts(pairI) += ??
        %   set(gridLines2, 'cdata', pair2SpikeCount / pair2TrialCounts)
        % elseif order 1+2
        %   pairI(pairI <= size(pairs1,1)) -> pair1 ?
        
        
        

    end

    function h = showFigure(self, ~, ~)
        h = self.h;
        self.show();
    end

    function clearFigures(~)
        %pass
    end

    function closeFigures(~)
        %pass
    end
    
    function show(self)
        figure(self.h);
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