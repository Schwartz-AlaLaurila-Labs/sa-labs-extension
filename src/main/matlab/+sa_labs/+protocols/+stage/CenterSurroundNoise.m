classdef CenterSurroundNoise < sa_labs.protocols.StageProtocol
    % This protocol from turner-package, commit a07ffa5, retrieved Sep 13 2016
    % https://github.com/Rieke-Lab/turner-package
    % thanks Max! -Sam
    
    
    properties
        preTime = 500 % ms
        stimTime = 8000 % ms
        tailTime = 500 % ms
        centerDiameter = 150 % um
        annulusInnerDiameter = 300 % um
        annulusOuterDiameter = 600 % um
        frameDwell = 1 % Frames per noise update
        contrastValues = [0.3] %contrast, as fraction of mean
        seedStartValue = 1
        locationMode = 'Center';

        numberOfEpochs = uint16(30) % number of epochs to queue
    end

    properties (Hidden)
        centerNoiseSeed
        surroundNoiseSeed
        centerNoiseStream
        surroundNoiseStream
        currentStimulus
        currentContrast
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = '';
    end
    
    properties (Dependent, Hidden)
        totalNumEpochs
    end
    
    methods
        
        
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            

            obj.currentStimulus = 'Center';
            
            index = mod(obj.numEpochsCompleted,2)
            if index == 1
                seed = obj.seedStartValue;
            elseif index == 0
                seed = obj.seedStartValue + obj.numEpochsCompleted / 2;
            end
            
            if length(obj.contrastValues) > 1
                obj.currentContrast = obj.contrastValues(mod(floor(obj.numEpochsCompleted / 2), length(obj.contrastValues)) + 1);
            end
                
            seed
            obj.centerNoiseSeed = seed;
            %at start of epoch, set random streams using this cycle's seeds
            obj.centerNoiseStream = RandStream('mt19937ar', 'Seed', obj.centerNoiseSeed);
%             obj.surroundNoiseStream = RandStream('mt19937ar', 'Seed', obj.surroundNoiseSeed);

            epoch.addParameter('centerNoiseSeed', obj.centerNoiseSeed);
%             epoch.addParameter('surroundNoiseSeed', obj.surroundNoiseSeed);
            epoch.addParameter('currentStimulus', obj.currentStimulus);
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            %convert from microns to pixels...
            centerDiameterPix = obj.um2pix(obj.centerDiameter);
            annulusInnerDiameterPix = obj.um2pix(obj.annulusInnerDiameter);
            annulusOuterDiameterPix = obj.um2pix(obj.annulusOuterDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            p.setBackgroundColor(obj.meanLevel); % Set background intensity
            preFrames = round(60 * (obj.preTime/1e3));
            if or(strcmp(obj.currentStimulus, 'Surround'), strcmp(obj.currentStimulus, 'Center-Surround'))
                surroundSpot = stage.builtin.stimuli.Ellipse();
                surroundSpot.radiusX = annulusOuterDiameterPix/2;
                surroundSpot.radiusY = annulusOuterDiameterPix/2;
                surroundSpot.position = canvasSize/2;
                p.addStimulus(surroundSpot);
                surroundSpotIntensity = stage.builtin.controllers.PropertyController(surroundSpot, 'color',...
                    @(state)getSurroundIntensity(obj, state.frame - preFrames));
                p.addController(surroundSpotIntensity);
                % hide during pre & post
                surroundSpotVisible = stage.builtin.controllers.PropertyController(surroundSpot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(surroundSpotVisible);
                %mask / annulus...
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
                centerSpotIntensity = stage.builtin.controllers.PropertyController(centerSpot, 'color',...
                    @(state)getCenterIntensity(obj, state.frame - preFrames));
                p.addController(centerSpotIntensity);
                % hide during pre & post
                centerSpotVisible = stage.builtin.controllers.PropertyController(centerSpot, 'visible', ...
                    @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
                p.addController(centerSpotVisible);
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
                i = intensity;
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
                i = intensity;
            end

        end
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
    end
    
end