classdef TemporalNoise < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500 % ms
        stimTime = 30000 % ms
        tailTime = 500 % ms
        
        contrast = .25 % weber contrast
        spotMeanLevel = 0.1 %Mean intensity of the light spot

        aperture = 2000 % um diameter

        frameDwell = 1 % Frames per noise update, use only 1 when colorMode is 2 pattern
        seedStartValue = 1
        seedChangeMode = 'increment only';
        colorNoiseMode = '1 pattern';
        colorNoiseDistribution = 'gaussian'
        
        numberOfEpochs = uint16(30) % number of epochs to queue
        
    end    
    
    properties (Hidden)
        version = 1;
        
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        colorNoiseModeType = symphonyui.core.PropertyType('char', 'row', {'1 pattern', '2 patterns'})
        colorNoiseDistributionType = symphonyui.core.PropertyType('char', 'row', {'uniform', 'gaussian', 'binary'})
        
        noiseSeed
        noiseStream
        
        noiseFn
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'noiseSeed';
    end
    
    properties (Dependent, Hidden)
        totalNumEpochs
    end
    
    methods
       
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
                seedIndex = mod(obj.numEpochsCompleted,2);
                if seedIndex == 0
                    seed = obj.seedStartValue;
                elseif seedIndex == 1
                    seed = obj.seedStartValue + (obj.numEpochsCompleted + 1) / 2;
                end
            end
            
            obj.noiseSeed = seed;
            
            %at start of epoch, set random streams using this cycle's seeds
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
            
            switch obj.colorNoiseDistribution
                case 'uniform'
                    obj.noiseFn = @() 2 * obj.noiseStream.rand() - 1;
                case 'gaussian'
                    obj.noiseFn = @() obj.spotMeanLevel + obj.contrast* obj.noiseStream.randn();
                case 'binary'
                    obj.noiseFn = @() 2 * (obj.noiseStream.rand() > .5) - 1;
            end
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            preFrames = round(obj.frameRate * (obj.preTime/1e3));
            
            % create shapes
            % checkerboard is filled from top left (is 1,1)
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX =  round(obj.um2pix(obj.aperture/2));
            spot.radiusY = spot.radiusX;
            spot.position = canvasSize / 2;

            p.addStimulus(spot);
            
            % add controllers
            % dimensions are swapped correctly
            if strcmp(obj.colorNoiseMode, '1 pattern')
                spotIntensityController = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getIntensity(obj, state.frame - preFrames));
            else
                % 2 pattern controller:
                spotIntensityController = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getIntensity2Pattern(obj, state.frame - preFrames, state.pattern + 1));
            end
            p.addController(spotIntensityController);
                       
            
            obj.setOnDuringStimController(p, spot);
                                    
            % TODO: verify X vs Y in matrix
            
            function i = getIntensity(obj, frame)
                persistent intensity;
                if frame < 0 %pre frames. frame 0 starts stimPts
                    intensity = obj.meanLevel;
                    intensity = clipIntensity(intensity, obj.meanLevel);
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = obj.spotMeanLevel + ...
                            obj.contrast * obj.spotMeanLevel * obj.noiseFn();
                        intensity = clipIntensity(intensity, obj.meanLevel);
                    end
                end
                i = intensity;
            end
                        
            function i = getIntensity2Pattern(obj, frame, pattern)
                persistent intensity;
                if isempty(intensity)
                    intensity = cell(2,1);
                end
                if pattern == 1
                    mn = obj.spotMeanLevel;
                    c = obj.contrast1;
                else
                    mn = obj.spotMeanLevel;
                    c = obj.contrast2;
                end
                
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity{pattern} = mn;
                    intensity{pattern} = clipIntensity(intensity{pattern}, mn);
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity{pattern} = mn + c * mn * obj.noiseFn();
                        intensity{pattern} = clipIntensity(intensity{pattern}, mn);
                    end
                    
                end
                
                i = intensity{pattern};
            end
            
            
            function intensity = clipIntensity(intensity, mn)
                intensity(intensity < 0) = 0;
                intensity(intensity > mn * 2) = mn * 2;
                intensity(intensity > 1) = 1;
                intensity = uint8(255 * intensity);
            end
            
        end
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
    end
end