classdef low_high_TemporalContrast < sa_labs.protocols.StageProtocol
    
    properties 
        preTime = 500 % ms
        stimTime = 30000 % ms
        tailTime = 500 % ms
        
        spotMeanLevel = 0.1 % Mean intensity of the light spot
        lowContrast = 0.08 % Low contrast value
        highContrast = 0.36 % High contrast value
        
        aperture = 2000 % um diameter
        
        frameDwell = 1 % Frames per noise update
        seedStartValue = 1
        seedChangeMode = 'increment only';
        colorNoiseMode = '1 pattern';
        colorNoiseDistribution = 'gaussian'
        
        numberOfEpochs = uint16(30) % Number of epochs to queue
    end
    
    properties (Dependent)
        SwitchTime
    end
    properties (Hidden)
        version = 1;
        
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'});
        colorNoiseModeType = symphonyui.core.PropertyType('char', 'row', {'1 pattern', '2 patterns'});
        colorNoiseDistributionType = symphonyui.core.PropertyType('char', 'row', {'uniform', 'gaussian', 'binary'});
        
        noiseSeed
        noiseStream
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'noiseSeed';
    end
    
    properties (Dependent, Hidden)
        totalNumEpochs
    end
    
    methods
        function SwitchTime = get.SwitchTime(obj)
            SwitchTime = obj.stimTime / 2e3;
        end
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case {'contrast'}
                    if obj.numberOfPatterns > 1
                        d.isHidden = true;
                    end
            end
        end
        
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
            if strcmp(obj.seedChangeMode, 'repeat only')
                seed = obj.seedStartValue;
            elseif strcmp(obj.seedChangeMode, 'increment only')
                seed = obj.numEpochsCompleted + obj.seedStartValue;
            else % Always repeat the first seed every 3rd epoch
                if mod(obj.numEpochsCompleted, 3) == 2 % Every 3rd epoch, use the first seed
                    seed = obj.seedStartValue; 
                else
                    seed = obj.seedStartValue + obj.numEpochsCompleted; % Regular incrementing seed
                end
            end 
            fprintf('Using seed %d for epoch %d\n', seed, obj.numEpochsCompleted + 1);

            obj.noiseSeed = seed;
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            preFrames = round(obj.frameRate * (obj.preTime / 1e3));
            stimFrames = round(obj.frameRate * (obj.stimTime / 1e3));
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.aperture / 2));
            spot.radiusY = spot.radiusX;
            spot.position = canvasSize / 2;
            spot.opacity = 1;
            
            p.addStimulus(spot);
            
            % The controller closure is serialized to the Stage server: it
            % captures plain values and the RandStream handle only (the
            % noise is drawn from the same stream as before), never obj or a
            % nested function (which shares this workspace and drags obj
            % along). Per-frame logic is in the package function
            % sa_labs.controllers.low_high_TemporalContrast_noiseIntensity.
            % tailFrames was previously referenced but never defined.
            tailFrames = round(obj.frameRate * (obj.tailTime / 1e3));
            frameDwell = obj.frameDwell;
            spotMeanLevel = obj.spotMeanLevel;
            lowContrast = obj.lowContrast;
            highContrast = obj.highContrast;
            switchTime = obj.SwitchTime;
            stream = obj.noiseStream;
            spotIntensityController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                @(state) sa_labs.controllers.low_high_TemporalContrast_noiseIntensity( ...
                state.frame - preFrames, preFrames, stimFrames, tailFrames, frameDwell, ...
                spotMeanLevel, lowContrast, highContrast, switchTime, stream));

            p.addController(spotIntensityController);
        end
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
    end

end
