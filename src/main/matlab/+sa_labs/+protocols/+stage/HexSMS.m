classdef HexSMS < sa_labs.protocols.StageProtocol
    properties
        preTime = 500   % Spot leading duration (ms)
        stimTime = 1000 % Spot duration (ms)
        tailTime = 1000 % Spot trailing duration (ms)
        
        intensity = 0.5;
        
        minSize = 30
        maxSize = 1200
        numberOfSizeSteps = 12
        numberOfCycles = 3
        
        gridX = 125; %width of grid in microns
        gridY = 125; %height of grid in microns
        coverage = 2.5; %the average number of spots at each point in space for a given spot size
        
        logScaling = true
        randomOrdering = true
    end
    
    properties (Hidden)
        version = 1;
        spots;
        currSpot;
    end
    
    
    methods
        function p = getPreview(self, panel)
            p = sa_labs.previews.HexPreview(panel, self.getSpots);
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
            epoch.addParameter('x', self.currSpot(1));
            epoch.addParameter('y', self.currSpot(2));
            epoch.addParameter('curSpotSize', self.currSpot(3));
            
            prepareEpoch@sa_labs.protocols.StageProtocol(self, epoch);
        end
        
        function p = createPresentation(self)
            p = stage.core.Presentation((self.preTime + self.stimTime + self.tailTime) * 1e-3);
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(self.um2pix(self.currSpot(3)/2));
            spot.radiusY = spot.radiusX;
            spot.color = self.intensity;
            canvasSize = self.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2 + self.um2pix(self.currSpot(1:2));
            p.addStimulus(spot);
            
            self.setOnDuringStimController(p, spot);
            self.setColorController(p, spot);
        end
        
        function spots = getSpots(self)
            if self.logScaling
                S = logspace(log10(self.minSize), log10(self.maxSize), self.numberOfSizeSteps);
            else
                S = linspace(self.minSize, self.maxSize, self.numberOfSizeSteps);
            end
            spots = [];
            
            spaceFactor = 3*pi/4 / self.coverage / (3*sqrt(3)/2);
            halfGrids = [self.gridX, self.gridY]/2;
            
            
            for i = numel(S):-1:1
                s = S(i);
                
                %space the spots to achieve the desired coverage factor
                %uses the ratio of the area of a hexagon to that of a circle
                spacing = sqrt(spaceFactor * s^2);
                
                %find the x and y coordinates for the hex grid
                xa = 0:spacing:self.gridX+spacing;
                xa(end) = [];
                xb= [xa(1) - spacing/2, xa+spacing/2];
                y = -cos(pi/6)*spacing:cos(pi/6)*spacing:self.gridY+cos(pi/6)*spacing;
                
                %create the grid
                [xqa, yqa] = meshgrid(xa,y(2:2:end)); %doing it in this order causes larger spots to be centered
                [xqb, yqb] = meshgrid(xb,y(1:2:end));
                locs = [xqa(:), yqa(:); xqb(:), yqb(:)];
                
                %center the grid on 0,0 using the center of mass
                cm = mean(locs, 1);
                locs = locs - cm;
                
                %remove any circles that don't intersect the viewing rectangle
                %the first part rejects any points that don't intersect the corner
                %the second part rejects any points that are are not in the voronoi
                %space of the faces
                locs( 4*sum((abs(locs) - halfGrids).^2,2) > s.^2 & all(abs(locs) > halfGrids, 2), :) = [];

                if isempty(locs)
                    %try sliding the grid
                    [xqa, yqa] = meshgrid(xa,y(1:2:end)); 
                    [xqb, yqb] = meshgrid(xb,y(2:2:end));
                    locs = [xqa(:), yqa(:); xqb(:), yqb(:)];
                    cm = mean(locs);
                    locs = locs - cm;
                    locs( 4*sum((abs(locs) - halfGrids).^2,2) > s.^2  & all(abs(locs) > halfGrids, 2), :) = [];
                    if isempty(locs)
                        locs = [0,0]; %we still want a spot at the center
                        %we should never reach this?
                    end
                end
                
                %store the spot locations and sizes
                spots=vertcat(spots,[locs, ones(size(locs,1),1)*s]); %#ok<AGROW>
            end
            
        end
    end
    
end