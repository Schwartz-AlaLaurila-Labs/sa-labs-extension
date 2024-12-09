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
        
        function switchTime = get.SwitchTime(obj)
            switchTime = obj.stimTime / 2;
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
            else
                seedIndex = mod(obj.numEpochsCompleted, 3);
                if seedIndex == 0
                    seed = obj.seedStartValue;
                else
                    seed = obj.seedStartValue + (obj.numEpochsCompleted + 1) / 3;
                end
            end
            
            obj.noiseSeed = seed;
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            preFrames = round(obj.frameRate * (obj.preTime / 1e3));
            stimFrames = round(obj.frameRate * (obj.stimTime / 1e3));
            totalFrames = preFrames + stimFrames + round(obj.frameRate * (obj.tailTime / 1e3));
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.aperture / 2));
            spot.radiusY = spot.radiusX;
            spot.position = canvasSize / 2;
            spot.opacity = 1;
            
            p.addStimulus(spot);
            
            spotIntensityController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                @(state)captureIntensity(obj,state.frame, preFrames, stimFrames, totalFrames));
            
            p.addController(spotIntensityController);
        
            function i = captureIntensity(obj, frame, preFrames, stimFrames, totalFrames)
                [i, global_intensity_log] = getIntensity(obj,frame, preFrames, stimFrames, totalFrames);
                assignin('base', 'intensity_log', global_intensity_log);
            end

            function [i, intensity_log] = getIntensity(obj, frame, preFrames, stimFrames)
    %             persistent intensity_log_internal;
                persistent intensity

                % Determine contrast based on frame position
                if frame < preFrames % Pre-time
                    contrast = obj.lowContrast; 
                elseif frame >= preFrames && frame < (preFrames + stimFrames) % Stimulus time
                    relative_frame = frame - preFrames;
                    blockNumber = floor((relative_frame / (obj.frameRate * (obj.stimTime /obj.SwitchTime))));
                    if mod(blockNumber, 2) == 0
                        contrast = obj.lowContrast;
                    else
                        contrast = obj.highContrast;
                    end

                else % Tail-time
                    contrast = obj.lowContrast;
                end

                if mod(frame, obj.frameDwell) == 0
                    noise = sa_labs.util.randn(obj.noiseStream, 1);
                    intensity = obj.spotMeanLevel + obj.spotMeanLevel * contrast * noise;
                end

                intensity = clipIntensity(intensity, obj.spotMeanLevel);
                intensity_log_internal(frame + 1) = intensity;
                intensity_log = intensity_log_internal;
                i = intensity;
            end
        
            % Clip intensity to the range [0, 1]
            function intensity = clipIntensity(intensity, mean_level)
                intensity(intensity > mean_level * 2) = mean_level * 2;
                intensity(intensity < 0) = 0;
                intensity(intensity > 1) = 1;
            end
        end
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end    
    end
end
