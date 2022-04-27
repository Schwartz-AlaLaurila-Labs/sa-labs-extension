classdef SpotsMultiSize < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 1000	% Spot trailing duration (ms)
        
        %mean (bg) and amplitude of pulse
        intensity = 0.5;
        
        %Option to pick specific spot sizes
        pickSpecificSizes = false;
        spotSizes = [100, 200, 1200];
        
        %stim size in microns, use rigConfig to set microns per pixel
        minSize = 30
        maxSize = 1200

        numberOfSizeSteps = 12
        numberOfCycles = 2;
        
        logScaling = true % scale spot size logarithmically (more precision in smaller sizes)
        randomOrdering = true;
        
        
    end
    
    properties (Hidden)
        version = 2;
        curSize
        sizes
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'curSpotSize';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            switch name
                case {'minSize', 'maxSize', 'numberOfSizeSteps', 'logScaling'}
                    if obj.pickSpecificSizes
                        d.isHidden = true;
                    else
                        d.isHidden = false;
                    end
                case {'spotSizes'}
                    if obj.pickSpecificSizes
                        d.isHidden = false;
                    else
                        d.isHidden = true;
                    end
            end
        end
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            %set spot size vector
            if obj.pickSpecificSizes
                obj.sizes = obj.spotSizes;
            else
                if ~obj.logScaling
                    obj.sizes = linspace(obj.minSize, obj.maxSize, obj.numberOfSizeSteps);
                else
                    obj.sizes = logspace(log10(obj.minSize), log10(obj.maxSize), obj.numberOfSizeSteps);
                end
            end

        end
        
        function prepareEpoch(obj, epoch)

            % Randomize sizes if this is a new set
            index = mod(obj.numEpochsPrepared, length(obj.sizes)) + 1;
            if index == 1 && obj.randomOrdering
                obj.sizes = obj.sizes(randperm(length(obj.sizes))); 
            end
            
            % compute current size and add parameter for it
            
            %get current position
            obj.curSize = obj.sizes(index);
            epoch.addParameter('curSpotSize', obj.curSize);
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
                        
        end
        
        
        function p = createPresentation(obj)
            %set bg
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.curSize / 2));
            spot.radiusY = spot.radiusX;
            spot.color = obj.intensity;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
           
            obj.setOnDuringStimController(p, spot);
                        
            % shared code for multi-pattern objects
            obj.setColorController(p, spot);
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * length(obj.sizes);
        end
        
        
    end
    
end