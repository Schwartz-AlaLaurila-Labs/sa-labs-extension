classdef WhiteNoiseFlicker < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 1000
        stimTime = 8000
        tailTime = 1000
        noiseSD = 0.2          % relative light intensity units
        framesPerStep = 1      % at 60Hz
        spotSize = 300         % stim size in microns, use rigConfig to set microns per pixel
        seedStartValue = 1
        seedChangeMode = 'repeat only';
        numberOfEpochs = 1     % number of cycles 
    end
    
    properties (Hidden)
        version = 2; % Corrected preFrames when framePerStep > 1 
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'randSeed';
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        waveVec
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareEpoch(obj, epoch)
            % Call the base method.
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
            
            %add seed parameter
            epoch.addParameter('randSeed', seed);
            %set rand seed
            rng(seed);
            
            if ~ isempty(obj.rig.getDevices('LightCrafter'))
                patternRate = obj.rig.getDevice('LightCrafter').getPatternRate();
            end
            
            nFrames = ceil((obj.stimTime/1000) * (patternRate / obj.framesPerStep));
            obj.waveVec = randn(1, nFrames);
            obj.waveVec = obj.waveVec .* obj.noiseSD; % set SD
            obj.waveVec = obj.waveVec + obj.meanLevel; % add mean
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));  % convert to pixels
            spot.radiusY = spot.radiusX;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            if ~ isempty(obj.rig.getDevices('LightCrafter'))
                patternRate = obj.rig.getDevice('LightCrafter').getPatternRate();
            end
            
            preFrames = ceil((obj.preTime/1e3) * patternRate);
            
            function c = noiseStim(state, preTime, stimTime, preFrames, waveVec, frameStep, meanLevel)
                if state.frame > preFrames && state.time <= (preTime+stimTime) *1e-3
                    index = ceil((state.frame - preFrames) / frameStep);
                    c = waveVec(index);
                else
                    c = meanLevel;
                end
            end
            
            controller = stage.builtin.controllers.PropertyController(spot, 'color', @(s)noiseStim(s, obj.preTime, obj.stimTime, ...
                preFrames, obj.waveVec, obj.framesPerStep, obj.meanLevel));
            p.addController(controller);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
    end
    
end