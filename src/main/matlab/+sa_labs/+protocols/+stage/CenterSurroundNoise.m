classdef CenterSurroundNoise < sa_labs.protocols.StageProtocol
    % This protocol from turner-package, commit a07ffa5, retrieved Sep 13 2016
    % https://github.com/Rieke-Lab/turner-package
    % thanks Max! -Sam
        
    properties
        preTime = 500 % ms
        stimTime = 20000 % ms
        tailTime = 500 % ms
        centerDiameter = 150 % um
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 2000 % um
        frameDwell = 1 % Frames per noise update, use only 1 when colorMode is 2 pattern
        contrast = 10 %contrast, as fraction of mean (set high for binary noise)
        seedStartValue = 1
        seedChangeMode = 'repeat only';
        locationMode = 'Center';
        colorNoiseMode = '1 pattern';

        numberOfEpochs = uint16(60) % number of epochs to queue
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
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'centerNoiseSeed';
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
        
        function prepareRun(obj)
            if obj.numberOfPatterns == 1 && obj.meanLevel == 0
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
                                
                % mask spot
                if or(strcmp(obj.currentStimulus, 'Surround'), strcmp(obj.currentStimulus, 'Center-Surround'))
                    maskSpotColorController = stage.builtin.controllers.PropertyController(maskSpot, 'color',...
                        @(s) colorPatternLookup(s, [obj.meanLevel1, obj.meanLevel2]));
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
                            obj.contrast * obj.meanLevel * obj.centerNoiseStream.randn;
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
                            obj.contrast * obj.meanLevel * obj.surroundNoiseStream.randn;
                    end
                end
          
                i = clipIntensity(intensity, obj.meanLevel);
            end
            
            
            function i = getCenterIntensity2Pattern(obj, frame, pattern)
                persistent intensity;
                if pattern == 0
                    mn = obj.meanLevel1;
                    c = obj.contrast1;
                else
                    mn = obj.meanLevel2;
                    c = obj.contrast2;
                end
                
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = mn;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = mn + c * mn * obj.centerNoiseStream.randn;
                    end
                end
          
                i = clipIntensity(intensity, mn);
            end
            
            function i = getSurroundIntensity2Pattern(obj, frame, pattern)
                persistent intensity;
                if pattern == 0
                    mn = obj.meanLevel1;
                    c = obj.contrast1;
                else
                    mn = obj.meanLevel2;
                    c = obj.contrast2;
                end
                
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity = mn;
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = mn + c * mn * obj.surroundNoiseStream.randn;
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