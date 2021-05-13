classdef MultiSMS < sa_labs.protocols.StageProtocol
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
        
        logScaling = true % Scale spot size logarithmically (more precision in smaller sizes)
        randomOrdering = true
    end
    
    properties (Dependent)
        totalNumEpochs % The total number of epochs for this grid
    end
    
    properties (Transient, Dependent)
        timeEstimate % An estimate of the total time required to complete the experiment (min)
    end
    
    properties (Hidden)
        version = 1;
        
        responsePlotMode = false;
        responsePlotSplitParameter = '';
    end    
    
    properties (Transient, Hidden)
        updated = false;
        spots;
        currSpot;
        multiSMSResponseFigure;
        t = tic;
    end
    
    methods (Abstract)
        spots = updateSpots(self);
    end
    
    methods
        
        function self = MultiSMS()
            
            %             self@sa_labs.protocols.StageProtocol(varargin);
           self.getSpots();
        end
        
        function p = getPreview(self, panel)
            p = sa_labs.previews.MultiSMSPreview(panel, @self.getSpots);
        end
        
        function prepareRun(self)
            self.getSpots();
            prepareRun@sa_labs.protocols.StageProtocol(self);
            self.multiSMSResponseFigure = self.showFigure(...
                'sa_labs.figures.MultiSMSResponseFigure', self);
            self.multiSMSResponseFigure.reset();
            self.t = tic;
        end
        
        function completeRun(self)
           elapsed = toc(self.t);
           fprintf('run completed in %.2f minutes (vs. estimate of %.2f)\n',elapsed/60, self.timeEstimate);
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
            if ~self.updated
                self.updateSpots();
                self.updated = true;
            end
            spots = self.spots;
            
            if nargout > 1
                gridRect = [-self.gridX/2, -self.gridY/2, self.gridX, self.gridY];
            end
        end
        
        function totalNumEpochs = get.totalNumEpochs(self)
            %             totalNumEpochs = self.numberOfCycles * size(self.getSpots,1);
            totalNumEpochs = self.numberOfCycles * size(self.getSpots,1);
            %             fprintf('got total num epochs: %d * %d = %d\n', self.numberOfCycles, size(self.getSpots,1));
        end
        
        function timeEstimate = get.timeEstimate(self)
            trialTime = (self.preTime + self.stimTime + self.tailTime) * 1e-3;
            if (trialTime < .5) % fit on 21-05-12
                trialTime = trialTime + .33 + .84*trialTime;
            else 
                trialTime = trialTime + .2844;
            end
            
            timeEstimate = self.numberOfCycles * size(self.getSpots,1) * trialTime / 60;
        end        
    end
    
end