classdef HexSMS < sa_labs.protocols.StageProtocol
    properties
        preTime = 500   % Spot leading duration (ms)
        stimTime = 1000 % Spot duration (ms)
        tailTime = 1000 % Spot trailing duration (ms)
        
        intensity = 0.5;
        
        minSize = 30 % Diameter of smallest spot (um)
        maxSize = 1200 % Diameter of largest spot (um)
        numberOfSizeSteps = 12
        numberOfCycles = 3
        
        gridX = 125; % Width of grid (um)
        gridY = 125; % Height of grid (um)
        coverage = 2.5; % The average number of spots at each point in space for a given spot size. At ~0.9069 there is 0 overlap.
        
        logScaling = true % Scale spot size logarithmically (more precision in smaller sizes)
        randomOrdering = true
    end
    
    properties (Dependent)
        totalNumEpochs % The total number of epochs for this grid
        timeEstimate % An estimate of the time in minutes to complete the experiment
    end
    
    properties (Hidden)
        version = 1;
        spots;
        currSpot;
        
        %TODO: fix the nightmarish inheritance of the response analysis figure
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'curSpotSize';
    end
    
    
    methods
        
        function self = HexSMS()
        
%             self@sa_labs.protocols.StageProtocol(varargin);
            self.spots = self.getSpots();
        end
        
        function p = getPreview(self, panel)
            p = sa_labs.previews.HexPreview(panel, @self.getSpots);
        end
        
        function prepareRun(self)
            prepareRun@sa_labs.protocols.StageProtocol(self);
            self.spots = self.getSpots();
        end
        
        function prepareEpoch(self, epoch)
            index = mod(self.numEpochsPrepared, size(self.spots,1)) + 1;
            if index == 1 && self.randomOrdering
                self.spots = self.spots(randperm(size(self.spots, 1)), :);
            end
            
            self.currSpot = self.spots(index,:);
            epoch.addParameter('cx', self.currSpot(1));
            epoch.addParameter('cy', self.currSpot(2));
            epoch.addParameter('curSpotSize', self.currSpot(3));
            
            prepareEpoch@sa_labs.protocols.StageProtocol(self, epoch);
        end
        
        function p = createPresentation(self)
            p = stage.core.Presentation((self.preTime + self.stimTime + self.tailTime) * 1e-3);
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = self.um2pix(self.currSpot(3)/2);
            spot.radiusY = spot.radiusX;
            spot.color = self.intensity;
            canvasSize = self.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2 + self.um2pix(self.currSpot(1:2));
            p.addStimulus(spot);
            
            self.setOnDuringStimController(p, spot);
            self.setColorController(p, spot);
        end
        
        function [spots,gridRect] = getSpots(self)
            if self.logScaling
                S = logspace(log10(self.minSize), log10(self.maxSize), self.numberOfSizeSteps);
            else
                S = linspace(self.minSize, self.maxSize, self.numberOfSizeSteps);
            end
            spots = [];
            
            %coverage = 3pi/4 * spacing / (3sqrt(3)/2* diameter)
            spaceFactor = sqrt(3*pi/4 / self.coverage / (3*sqrt(3)/2));
            halfGrids = [self.gridX, self.gridY]/2;
            
            
            for i = numel(S):-1:1
                s = S(i);
                
                %space the spots to achieve the desired coverage factor
                %uses the ratio of the area of a hexagon to that of a circle
                spacing = spaceFactor * s;
                
                %find the x and y coordinates for the hex grid
                xa = [0:-spacing:-self.gridX/2-spacing, spacing:spacing:self.gridX/2+spacing];
                xb= [xa - spacing/2, xa(end)+spacing/2];
                
                yspacing = cos(pi/6)*spacing;
                
                ya = [0:-2*yspacing:-self.gridY/2-yspacing, 2*yspacing:2*yspacing:self.gridY/2+yspacing];
                yb = [ya - yspacing, ya(end) + yspacing];

                %create the grid
                [xqa, yqa] = meshgrid(xa,ya); %doing it in this order causes larger spots to be centered
                [xqb, yqb] = meshgrid(xb,yb);
                locs = [xqa(:), yqa(:); xqb(:), yqb(:)];
                
                %remove any circles that don't intersect the viewing rectangle
                % the bounding box of the circle must intersect the rectangle
                locs = locs(all(abs(locs) < halfGrids + s/2, 2), :);
                
                % circles near the corners might have an intersecting
                % bounding box but not actually intersect
                % if either of the coordinates is inside the box, it
                % definitely intersects
                % otherwise it must intersect the corner
                locs = locs(any(abs(locs) < halfGrids, 2) | 4*sum((abs(locs)-halfGrids).^2,2) <= s.^2 , :); 

                spots=vertcat(spots,[locs, ones(size(locs,1),1)*s]); %#ok<AGROW>
            end
            
            gridRect = [-self.gridX/2, -self.gridY/2, self.gridX, self.gridY];
            self.spots = spots;
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(self)
%             totalNumEpochs = self.numberOfCycles * size(self.getSpots,1);
            totalNumEpochs = self.numberOfCycles * size(self.spots,1);
%             fprintf('got total num epochs: %d * %d = %d\n', self.numberOfCycles, size(self.getSpots,1));
        end
        
        function timeEstimate = get.timeEstimate(self)
           timeEstimate = self.numberOfCycles * size(self.spots,1) * (self.preTime + self.stimTime + self.tailTime) * 1e-3 / 60;
        end
    end
    
end