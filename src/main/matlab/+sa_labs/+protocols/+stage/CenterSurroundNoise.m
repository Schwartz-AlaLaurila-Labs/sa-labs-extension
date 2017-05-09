classdef CenterSurroundNoise < sa_labs.protocols.StageProtocol
    % This protocol from turner-package, commit a07ffa5, retrieved Sep 13 2016
    % https://github.com/Rieke-Lab/turner-package
    % thanks Max! -Sam
    
    
    properties
        preTime = 500 % ms
        stimTime = 30000 % ms
        tailTime = 500 % ms
        centerDiameter = 150 % um
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 600 % um
        frameDwell = 1 % Frames per noise update, use only 1 when colorMode is 2 pattern
        contrastValues = 1 %contrast, as fraction of mean
        seedStartValue = 1
        seedChangeMode = 'repeat only';
        locationMode = 'Center';
        colorNoiseMode = '1 pattern';
        
        colorMeanIntensity1 = 0.5;
        colorMeanIntensity2 = 0.5;

        numberOfEpochs = uint16(30) % number of epochs to queue
    end

    properties (Hidden)
        version = 2; % version 1 is unmarked; version 2 introduces 2-color presentations
        
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        locationModeType = symphonyui.core.PropertyType('char', 'row', {'Center', 'Surround', 'Center-Surround'})
        colorNoiseModeType = symphonyui.core.PropertyType('char', 'row', {'1 pattern', '2 patterns'})
        
        centerNoiseSeed
        surroundNoiseSeed
        centerNoiseStream
        surroundNoiseStream
        currentStimulus
        currentContrast
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'centerNoiseSeed';
    end
    
    properties (Dependent, Hidden)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            if obj.meanLevel == 0
                warning('Mean Level must be greater than 0 for this to work');
            end
            
            prepareRun@sa_labs.protocols.StageProtocol(obj);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
            obj.currentStimulus = obj.locationMode;

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
                        
%             if length(obj.contrastValues) > 1
%                 contrastIndex = mod(floor(obj.numEpochsCompleted / 2), length(obj.contrastValues)) + 1;
%             else
%                 contrastIndex = 1;
%             end
            obj.currentContrast = obj.contrastValues(1);
            
            obj.centerNoiseSeed = seed;
            fprintf('Using center seed %g\n', obj.centerNoiseSeed);
            
            obj.surroundNoiseSeed = seed + 1e5; % magic number ftw
            fprintf('Using surround seed %g\n', obj.surroundNoiseSeed);

            %at start of epoch, set random streams using this cycle's seeds
            obj.centerNoiseStream = RandStream('mt19937ar', 'Seed', obj.centerNoiseSeed);
            obj.surroundNoiseStream = RandStream('mt19937ar', 'Seed', obj.surroundNoiseSeed);

            epoch.addParameter('centerNoiseSeed', obj.centerNoiseSeed);
            epoch.addParameter('surroundNoiseSeed', obj.surroundNoiseSeed);
            epoch.addParameter('currentStimulus', obj.currentStimulus);
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            centerDiameterPix = obj.um2pix(obj.centerDiameter);
            [~, annulusInnerDiameterPix] = obj.um2pix(obj.annulusInnerDiameter);
            [~, annulusOuterDiameterPix] = obj.um2pix(obj.annulusOuterDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            preFrames = round(obj.frameRate * (obj.preTime/1e3));
            
            % create shapes
            if strcmp(obj.colorNoiseMode, '2 patterns')
                % create background for color use
                backgroundRect = stage.builtin.stimuli.Rectangle();
                backgroundRect.position = canvasSize/2;
                backgroundRect.size = canvasSize + 10;
                p.addStimulus(backgroundRect);
            end
                
            if or(strcmp(obj.currentStimulus, 'Surround'), strcmp(obj.currentStimulus, 'Center-Surround'))
                surroundSpot = stage.builtin.stimuli.Ellipse();
                surroundSpot.radiusX = annulusOuterDiameterPix/2;
                surroundSpot.radiusY = annulusOuterDiameterPix/2;
                surroundSpot.position = canvasSize/2;
                p.addStimulus(surroundSpot);
                %mask / annulus
                maskSpot = stage.builtin.stimuli.Ellipse();
                maskSpot.radiusX = annulusInnerDiameterPix/2;
                maskSpot.radiusY = annulusInnerDiameterPix/2;
                maskSpot.position = canvasSize/2;
                maskSpot.color = obj.meanLevel;
                p.addStimulus(maskSpot);
            end
            if or(strcmp(obj.currentStimulus, 'Center'), strcmp(obj.currentStimulus, 'Center-Surround'))
                centerSpot = stage.builtin.stimuli.Ellipse();
                centerSpot.radiusX = centerDiameterPix/2;
                centerSpot.radiusY = centerDiameterPix/2;
                centerSpot.position = canvasSize/2;
                p.addStimulus(centerSpot);
            end
                
            
            % add controllers
            if strcmp(obj.colorNoiseMode, '1 pattern')
                if or(strcmp(obj.currentStimulus, 'Surround'), strcmp(obj.currentStimulus, 'Center-Surround'))
                    surroundSpotIntensity = stage.builtin.controllers.PropertyController(surroundSpot, 'color',...
                        @(state)getSurroundIntensity(obj, state.frame - preFrames));
                    p.addController(surroundSpotIntensity);
                    % hide during pre & post
                    surroundSpotVisibleController = stage.builtin.controllers.PropertyController(surroundSpot, 'visible', ...
                        @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                    p.addController(surroundSpotVisibleController);
                end

                if or(strcmp(obj.currentStimulus, 'Center'), strcmp(obj.currentStimulus, 'Center-Surround'))
                    centerSpotIntensityController = stage.builtin.controllers.PropertyController(centerSpot, 'color',...
                        @(state)getCenterIntensity(obj, state.frame - preFrames));
                    p.addController(centerSpotIntensityController);
                    % hide during pre & post
                    centerSpotVisibleController = stage.builtin.controllers.PropertyController(centerSpot, 'visible', ...
                        @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                    p.addController(centerSpotVisibleController);
                end
            else
                
                % 2 pattern controllers:
            
                % background rect
                backgroundRectColorController = stage.builtin.controllers.PropertyController(backgroundRect, 'color',...
                    @(s) colorPatternLookup(s, [obj.colorMeanIntensity1, obj.colorMeanIntensity2]));
                p.addController(backgroundRectColorController);
                                
                % mask spot
                if or(strcmp(obj.currentStimulus, 'Surround'), strcmp(obj.currentStimulus, 'Center-Surround'))
                    maskSpotColorController = stage.builtin.controllers.PropertyController(maskSpot, 'color',...
                        @(s) colorPatternLookup(s, [obj.colorMeanIntensity1, obj.colorMeanIntensity2]));
                    p.addController(maskSpotColorController);
                end
                
                % surround
                if or(strcmp(obj.currentStimulus, 'Surround'), strcmp(obj.currentStimulus, 'Center-Surround'))
                    surroundSpotIntensity = stage.builtin.controllers.PropertyController(surroundSpot, 'color',...
                        @(state)getSurroundIntensity2Pattern(obj, state.frame - preFrames, state.pattern));
                    p.addController(surroundSpotIntensity);
                    % hide during pre & post
                    surroundSpotVisibleController = stage.builtin.controllers.PropertyController(surroundSpot, 'visible', ...
                        @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                    p.addController(surroundSpotVisibleController);
                end
                
                % center
                if or(strcmp(obj.currentStimulus, 'Center'), strcmp(obj.currentStimulus, 'Center-Surround'))
                    centerSpotIntensityController = stage.builtin.controllers.PropertyController(centerSpot, 'color',...
                        @(state)getCenterIntensity2Pattern(obj, state.frame - preFrames, state.pattern));
                    p.addController(centerSpotIntensityController);
                    % hide during pre & post
                    centerSpotVisibleController = stage.builtin.controllers.PropertyController(centerSpot, 'visible', ...
                        @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                    p.addController(centerSpotVisibleController);
                end
            end
            
            function c = colorPatternLookup(state, colors)
                c = colors(state.pattern + 1);
            end
                        
            function i = getCenterIntensity(obj, frame)
                persistent intensity;
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = obj.meanLevel;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = obj.meanLevel + ... 
                            obj.currentContrast * obj.meanLevel * obj.centerNoiseStream.randn;
                    end
                end
                
                i = clipIntensity(intensity, obj.meanLevel);
            end
            
            function i = getSurroundIntensity(obj, frame)
                persistent intensity;
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = obj.meanLevel;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = obj.meanLevel + ... 
                            obj.currentContrast * obj.meanLevel * obj.surroundNoiseStream.randn;
                    end
                end
          
                i = clipIntensity(intensity, obj.meanLevel);
            end
            
            
            function i = getCenterIntensity2Pattern(obj, frame, pattern)
                persistent intensity;
                if pattern == 0
                    mn = obj.colorMeanIntensity1;
                else
                    mn = obj.colorMeanIntensity2;
                end
                
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = mn;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = mn + obj.currentContrast * mn * obj.centerNoiseStream.randn;
                    end
                end
          
                i = clipIntensity(intensity, mn);
            end
            
            function i = getSurroundIntensity2Pattern(obj, frame, pattern)
                persistent intensity;
                if pattern == 0
                    mn = obj.colorMeanIntensity1;
                else
                    mn = obj.colorMeanIntensity2;
                end
                
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = mn;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = mn + obj.currentContrast * mn * obj.surroundNoiseStream.randn;
                    end
                end
          
                i = clipIntensity(intensity, mn);
            end

            
            function intensity = clipIntensity(intensity, mn)
                if intensity < 0
                    intensity = 0;
                elseif intensity > mn * 2
                    intensity = mn * 2; % probably important to be symmetrical to whiten the stimulus
                elseif intensity > 1
                    intensity = 1;
                end    
            end

        end
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
    end
    
end