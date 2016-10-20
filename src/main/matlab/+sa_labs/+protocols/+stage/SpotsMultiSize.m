classdef SpotsMultiSize < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 1000	% Spot trailing duration (ms)
        
        %mean (bg) and amplitude of pulse
        intensity = 0.5;
        
        %stim size in microns, use rigConfig to set microns per pixel
        minSize = 30
        maxSize = 1200

        numberOfSizeSteps = 12
        numberOfCycles = 2;
        
        logScaling = true % scale spot size logarithmically (more precision in smaller sizes)
    end
    
    properties (Hidden)
        curSize
        sizes
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'curSpotSize';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            %set spot size vector
            if ~obj.logScaling
                obj.sizes = linspace(obj.minSize, obj.maxSize, obj.numberOfSizeSteps);
            else
                obj.sizes = logspace(log10(obj.minSize), log10(obj.maxSize), obj.numberOfSizeSteps);
            end

        end
        
        function prepareEpoch(obj, epoch)

            % Randomize sizes if this is a new set
            index = mod(obj.numEpochsPrepared - 1, obj.numberOfSizeSteps);
            if index == 0
                obj.sizes = obj.sizes(randperm(obj.numberOfSizeSteps)); 
            end
            
            % compute current size and add parameter for it
            
            %get current position
            obj.curSize = obj.sizes(index+1);
            epoch.addParameter('curSpotSize', obj.curSize);
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
                        
        end
        
        
        function p = createPresentation(obj)
            %set bg
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

            p.setBackgroundColor(obj.meanLevel);
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.curSize / 2));
            spot.radiusY = spot.radiusX;
            %spot.color = obj.intensity;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            function c = onDuringStim(state, preTime, stimTime, intensity, meanLevel)
                if state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3
                    c = intensity;
                else
                    c = meanLevel;
                end
            end
            
            controller = stage.builtin.controllers.PropertyController(spot, 'color', @(s)onDuringStim(s, obj.preTime, obj.stimTime, obj.intensity, obj.meanLevel));
            p.addController(controller);
                        
%             obj.addFrameTracker(p);
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfSizeSteps;
        end
        
        
    end
    
end