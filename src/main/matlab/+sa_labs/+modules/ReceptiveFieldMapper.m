classdef ReceptiveFieldMapper < symphonyui.ui.Module & symphonyui.core.FigureHandlerManager
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
    pairs1L
    lastSpotsSc
    lastPairs1L
    lastRasterL
    lastTopSpotTr
    lastTraceTr

    gridAx
    lastSpotsAx
    lastRasterAx 
    lastTopSpotAx
    lastTraceAx
    
    params
    spikeDetector
    
    spotCountGrid
    spotCountPairs1
    spotCountPairs2
    
    spikeCountGrid
    spikeCountPairs1
    spikeCountPairs2
    
    useGrid
    usePairs1
    usePairs2
end

methods
    function createUi(self, figure_handle)
        self.h = figure_handle;
        set(self.h,'color','w');
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
        
        self.pairs1L = patch(self.gridAx,...
            'faces',[],...
            'vertices',[],...
            'linewidth',4,'edgecolor','flat','facecolor','none');
        self.gridSc = scatter(self.gridAx,...
            [],[],'k','filled');    
        
        hold(self.lastSpotsAx, 'on');
        title(self.lastSpotsAx, 'Last epoch map');
        xlabel(self.lastSpotsAx, 'Position (microns)');
        xlim(self.lastSpotsAx,[-self.extentR, self.extentR]);
        ylim(self.lastSpotsAx,[-self.extentR, self.extentR]);
        self.lastPairs1L = patch(self.lastSpotsAx,...
            'faces',[],...
            'vertices',[],...
            'linewidth',4,'edgecolor','flat','facecolor','none');
        
        self.lastSpotsSc = scatter(self.lastSpotsAx,...
            [],[],'k','linewidth', 2,'markerfacecolor','flat');
        
        self.lastRasterL = scatter(self.lastRasterAx,...
            [],[],'k. ');        
        self.lastTopSpotTr = plot(self.lastTopSpotAx,...
            nan,nan,'k');
        self.lastTraceTr = plot(self.lastTraceAx,...
            nan,nan,'k');
        
        
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
        self.order = e.String{e.Value};
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
        
        xlim(self.lastSpotsAx,[-self.extentR, self.extentR]);
        ylim(self.lastSpotsAx,[-self.extentR, self.extentR]);
        
        
        axpos =  get(self.gridAx, 'position');
        msz = self.spotDiam / sqrt(pi) / diff(xlim(self.gridAx)) * axpos(3);

        
        set(self.gridSc, 'xdata', self.grid(:,1), 'ydata', self.grid(:,2), 'sizedata', msz.^2, 'cdata', [0,0,0]);
        set(self.lastSpotsSc,'sizedata', msz.^2);
        axis(self.gridAx,'equal');
        axis(self.lastSpotsAx,'equal');
        
        
        
        %% generate first and second order pairs
        
        % TODO: 1.5 and 2.5 are very arbitrary... we should check this
        d = pdist(self.grid);
        p = d < (self.spacing * 1.5);
        p = triu(squareform(p),1);
        [r,c] = find(p);
        self.pairs1 = [r,c];
        
        p = (d > (self.spacing * 1.5)) & (d < (self.spacing * 2.5));
        p = triu(squareform(p),1);
        [r,c] = find(p);
        self.pairs2 = [r,c];
        
        set(self.pairs1L,'faces',reshape(1:numel(self.pairs1),[],2),...
            'vertices',self.grid(self.pairs1,:),...
            'cdata',zeros(numel(self.pairs1),1),'linewidth',msz/3);
        set(self.lastPairs1L,'faces',reshape(1:numel(self.pairs1),[],2),...
            'vertices',self.grid(self.pairs1,:),...
            'cdata',nan(numel(self.pairs1),1),'linewidth',msz/3);
        
        %% update spike and spot counts
        self.spotCountGrid = zeros(size(self.grid,1),1);
        self.spotCountPairs1 = zeros(size(self.pairs1,1),1);
        self.spotCountPairs2 = zeros(size(self.pairs2,1),1);        
        
        self.spikeCountGrid = zeros(size(self.grid,1),1);       
        self.spikeCountPairs1 =zeros(size(self.pairs1,1),1);       
        self.spikeCountPairs2 =zeros(size(self.pairs2,1),1);      
        
        self.useGrid = true(size(self.grid,1),1);
        self.usePairs1 = true(size(self.pairs1,1),1);
        self.usePairs2 = true(size(self.pairs2,1),1);
        
    end
    
    function draw(self, ~, ~)
        if verLessThan('matlab','R2018b')
            return
        end
        roi = drawpolygon(self.gridAx,'color','k');
        
        self.useGrid = inROI(roi, self.grid(:,1), self.grid(:,2));
        self.usePairs1 = self.useGrid(self.pairs1,1) & self.useGrid(self.pairs1,2);
        self.usePairs2 = self.useGrid(self.pairs2,1) & self.useGrid(self.pairs2,2);
        
        roi.Deletable = false;
        roi.InteractionsAllowed = 'none';
        roi.FaceAlpha = 0;
        
    end

    function run(self, ~, ~)
        self.acquisitionService.selectProtocol('sa_labs.protocols.stage.PairedSpotField');

        % % set the properties based on the menu items
        self.acquisitionService.setProtocolProperty('spotSize',self.spotDiam);
        
        switch self.order
            % note that setter reshapes pairs into N-by-(a,b)-by-(x,y)
            case '0'
                self.acquisitionService.setProtocolProperty('spotPairs',cat(1,self.grid(self.useGrid,:),self.grid(self.useGrid,:)));
            case '1'
                self.acquisitionService.setProtocolProperty('spotPairs',self.grid(self.pairs1(self.usePairs1,:),:));
            case '2'
                self.acquisitionService.setProtocolProperty('spotPairs',self.grid(self.pairs2(self.usePairs2,:),:));
            case '1+2'                
                self.acquisitionService.setProtocolProperty('spotPairs',self.grid(cat(1,self.pairs1(self.usePairs1,:),self.pairs2(self.usePairs2,:)),:));
        end
        % self.acquisitionService.setProtocolProperty('RFMapper',self);
%         self.documentationService.getCurrentEpochGroup()

        self.acquisitionService.setProtocolFigureHandlerManager(self);
        self.params = self.acquisitionService.getProtocolPropertyDescriptors().toMap();
        
        % need to set the figure handler manager for paired spots
        % stimulus...
        
        %could do in paired spots constructor, but could be tricky to
        %implement? how do we get the module without constructing it?

        %is this just an accessible property?? seems that it's protected which would fail
        % unless we update the setProperty method...


        
        
        
        self.spikeDetector = sa_labs.util.SpikeDetector(self.params('spikeDetectorMode'),...
            self.params('spikeThreshold'));
        
        xl = [-self.params('spotPreFrames')/self.params('frameRate'), (self.params('spotStimFrames') + self.params('spotTailFrames'))/self.params('frameRate')];
        xlim(self.lastRasterAx,xl);
        ylim(self.lastRasterAx,[0.5, self.params('numSpotsPerEpoch')+0.5]);
        
        samplesPerSpot = (self.params('spotPreFrames') + self.params('spotStimFrames') + self.params('spotTailFrames')) / self.params('frameRate') * self.params('sampleRate');
        st = linspace(-self.params('spotPreFrames'),self.params('spotStimFrames')+self.params('spotTailFrames'), samplesPerSpot)/self.params('frameRate');
        set(self.lastTopSpotTr,'xdata',st,'ydata',nan(size(st)));
        xlim(self.lastTopSpotAx,xl);
        
        xd = 1:(self.params('preTime') + self.params('stimTime') + self.params('tailTime'))* 1e-3 * self.params('sampleRate');
        set(self.lastTraceTr,'xdata',xd,'ydata',nan(size(xd)));
        xlim(self.lastTraceAx,[1,xd(end)]);
        
        set(self.lastSpotsSc,'xdata',[],'ydata',[]);
        set(self.lastPairs1L,'cdata',nan(numel(self.pairs1),1));
        set(self.lastRasterL,'xdata',[],'ydata',[]);
        
        delete(self.lastSpotsAx.Children(1:end-2));
        
        % set(lastTraceTr, 'xdata', ..., 'ydata', zeros)
%         self.acquisitionService.record()
        self.acquisitionService.viewOnly()

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
        
        
        
        %% Epoch-wise plots
        % update the bottom trace
        response = epoch.getResponse(self.configurationService.getDevice('Amp1'));
        [dat, ~] = response.getData();
        
        samplesPerSpot = (self.params('spotPreFrames') + self.params('spotStimFrames') + self.params('spotTailFrames')) / self.params('frameRate') * self.params('sampleRate');
        
        %spikeI: the index of the spike relative to start of stim period
        spikeI = self.spikeDetector.detectSpikes(dat);
        spikeI = spikeI.sp - self.params('preTime') * 1e-3 * self.params('sampleRate');
        spikeI(spikeI < 1) = [];
        spikeI(spikeI > self.params('stimTime') * 1e-3 * self.params('sampleRate')) = [];
                
        %spikeS: the spot index into cx/cy for each spike
        spikeS = floor((spikeI-1) / samplesPerSpot) + 1;
        
        %countS: the number of spikes for each spot index into cx/cy
        countS = accumarray(spikeS', 1, [self.params('numSpotsPerEpoch'),1], @sum, 0);        
        
        %spikeE: the index of each spike relative to the start of the spot
        %period
        spikeE = mod(spikeI-1, samplesPerSpot) + 1;
        
        %spikeT: time of each spike realtive to start of spot period
        spikeT = (spikeE-1)/self.params('sampleRate') - self.params('spotPreFrames')/self.params('frameRate');
        
        cx = epoch.parameters('cx');
        cy = epoch.parameters('cy');
                    
        % update the raster map
        set(self.lastRasterL,'xdata',spikeT,'ydata',spikeS);
        
        % draw the section of trace with most spikes
        exampleS = mode(spikeS);
        if isnan(exampleS)
            exampleS = 1;
        end
        set(self.lastTopSpotTr,'ydata',dat((samplesPerSpot*(exampleS-1)+1 : samplesPerSpot*exampleS) + self.params('preTime')*1e-3 * self.params('sampleRate')));
        
        %draw the full trace
        set(self.lastTraceTr,'ydata',dat);
        
        % update the last spots and RF maps
        if strcmp(self.order,'0')
            %determine the spot indices
            [~,idx] = ismember([cx(:,1), cy(:,1)],self.grid,'rows');
            
            % accumulate the average spike count
            self.spikeCountGrid = self.spikeCountGrid + accumarray(idx,countS,[size(self.grid,1),1], @sum);
            self.spotCountGrid = self.spotCountGrid + accumarray(idx,1,[size(self.grid,1),1], @sum);
            set(self.gridSc,'cdata',self.spikeCountGrid ./ self.spotCountGrid);
            
            set(self.lastSpotsSc,'xdata',cx(:,1),'ydata',cy(:,1),'cdata',countS);
        elseif strcmp(self.order,'1')
            %determine the pairs indices
            [~,idx1] = ismember([cx(:,1), cy(:,1)],self.grid,'rows');
            [~,idx2] = ismember([cx(:,2), cy(:,2)],self.grid,'rows');
            [~,idx] = ismember([idx1, idx2], self.pairs1,'rows');
            
            % accumulate the average spike count
            c = accumarray(idx,countS,[size(self.pairs1,1),1], @sum);
            self.spikeCountPairs1 = self.spikeCountPairs1 + c;
            self.spotCountPairs1 = self.spotCountPairs1 + accumarray(idx,1,[size(self.pairs1,1),1], @sum);
            
            set(self.pairs1L,'cdata',[self.spikeCountPairs1 ./ self.spotCountPairs1; zeros(size(self.pairs1,1),1)]);
            
            c(c==0) = nan;
            set(self.lastPairs1L,'cdata',[c; nan(size(self.pairs1,1),1)]);
            
        elseif strcmp(self.order,'2')
            
            delete(self.lastSpotsAx.Children(1:end-2));
        
           text(self.lastSpotsAx,cx(:,1),cy(:,1),num2cell(num2str((1:self.params('numSpotsPerEpoch'))')));
           text(self.lastSpotsAx,cx(:,2),cy(:,2),num2cell(num2str((1:self.params('numSpotsPerEpoch'))')));
           
        elseif strcmp(self.order,'1+2')
        end    
        
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