classdef ObjectMotionSensitivity < sa_labs.protocols.StageProtocol
    
    
    properties
        %times in ms
        preTime = 1000;
        tailTime = 0;
        stimTime = 20000;
        
        intensity = 0.5;
        contrast = 1; % percentage around the mean
        
        motionAngle = 0;
        
        centerDiameter = 200;
        patternMode = 'grating'; % grating only for now
        patternDimension = 40; % µm, spatial scale
        gratingProfile = 'square'; %sine, square, or sawtooth
        
        motionMode = 'filteredNoise';
        
        motionSeedChangeModeCenter = 'increment only';
        motionStandardDeviationCenter = 400; % µm std or random walk step
        motionLowpassFilterPassbandCenter = 5; % Hz
        
        motionSeedModeSurround = 'same';
        motionStandardDeviationSurround = 400; % µm std or random walk step
        motionLowpassFilterPassbandSurround = 5; % Hz
        
        numberOfCycles = 3;
        numberOfEpochs = 300;
        
    end
    
    properties (Hidden)
        version = 1
        
        motionModeType = symphonyui.core.PropertyType('char','row',{'filteredNoise','randomWalk'});
        
        motionPathCenter
        motionSeedCenter
        motionFilterCenter
        motionSeedChangeModeCenterType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        
        motionPathSurround
        motionSeedSurround
        motionFilterSurround
        motionSeedModeSurroundType = symphonyui.core.PropertyType('char', 'row', {'same','offset','random'})
        
        patternModeType = symphonyui.core.PropertyType('char', 'row', {'grating','texture'});
        gratingProfileType = symphonyui.core.PropertyType('char', 'row', {'sine', 'square', 'sawtooth'});
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'motionSeedCenter';
        
        patternSize = [4000,2000];
    end
    
    properties (Dependent)
        motionLowpassFilterStopband
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
        
    end
    
    methods
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case {'motionSeed','motionStandardDeviation','motionLowpassFilterPassband','motionLowpassFilterStopband'}
                    d.category = '5 Random Motion';
            end
            
        end
        
        function prepareRun(obj)
            
            % Call the base method.
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            
            % create the motion filters
            frameRate = 60;
            obj.motionFilterCenter = designfilt('lowpassfir','PassbandFrequency',obj.motionLowpassFilterPassbandCenter,...
                'StopbandFrequency',obj.motionLowpassFilterPassbandCenter*1.2,'SampleRate',frameRate);
            
            obj.motionFilterSurround = designfilt('lowpassfir','PassbandFrequency',obj.motionLowpassFilterPassbandSurround,...
                'StopbandFrequency',obj.motionLowpassFilterPassbandSurround*1.2,'SampleRate',frameRate);
            
        end
        
        function prepareEpoch(obj, epoch)
            
            % Select a pair of seeds
            if strcmp(obj.motionSeedChangeModeCenter, 'repeat only')
                seed = obj.motionSeedStart;
            elseif strcmp(obj.motionSeedChangeModeCenter, 'increment only')
                seed = obj.numEpochsCompleted + obj.motionSeedStart;
            else
                seedIndex = mod(obj.numEpochsCompleted,2);
                if seedIndex == 0
                    seed = obj.motionSeedStart;
                elseif seedIndex == 1
                    seed = obj.motionSeedStart + (obj.numEpochsCompleted + 1) / 2;
                end
            end
            obj.motionSeedCenter = seed;
            
            switch obj.motionSeedModeSurround
                case 'same'
                    obj.motionSeedSurround = seed;
                case 'offset'
                    obj.motionSeedSurround = seed + 10;
                case 'random'
                    obj.motionSeedSurround = randi(1e4,1);
            end
            
            epoch.addParameter('motionSeedCenter', obj.motionSeedCenter);
            epoch.addParameter('motionSeedSurround', obj.motionSeedSurround);
            
            fprintf('Using seeds %g, %g\n', obj.motionSeedCenter, obj.motionSeedSurround);
            
            frameRate = 60;
            pathLength = round((obj.stimTime + obj.preTime)/1000 * frameRate + 100);
            switch obj.motionMode
                case 'filteredNoise'
                    stream = RandStream('mt19937ar', 'Seed', obj.motionSeedCenter);
                    mpathc = obj.motionStandardDeviationCenter .* stream.randn(pathLength, 1);
                    obj.motionPathCenter = filtfilt(obj.motionFilterCenter, mpathc);
                    
                    stream = RandStream('mt19937ar', 'Seed', obj.motionSeedSurround);
                    mpaths = obj.motionStandardDeviationSurround .* stream.randn(pathLength, 1);
                    obj.motionPathSurround = filtfilt(obj.motionFilterSurround, mpaths);
                    
                case 'randomWalk'
                    stream = RandStream('mt19937ar', 'Seed', obj.motionSeedCenter);
                    mpathc = zeros(pathLength,1);
                    for i = 2:pathLength
                        if stream.rand(1) > 0.5
                            step = 1;
                        else
                            step = -1;
                        end
                        mpathc(i) = mpathc(i-1) + step * obj.motionStandardDeviationCenter;
                    end
                    obj.motionPathCenter = mpathc;
                    
                    stream = RandStream('mt19937ar', 'Seed', obj.motionSeedSurround);
                    mpaths = zeros(pathLength,1);
                    for i = 2:pathLength
                        if stream.rand(1) > 0.5
                            step = 1;
                        else
                            step = -1;
                        end
                        mpaths(i) = mpaths(i-1) + step * obj.motionStandardDeviationSurround;
                    end
                    obj.motionPathSurround = mpaths;
                    
                    
            end
            
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            patternSurround = stage.builtin.stimuli.Grating(obj.gratingProfile, 1024);
            patternSurround.position = [0,0];
            patternSurround.orientation = obj.motionAngle;
            patternSurround.contrast = obj.contrast;
            patternSurround.size = obj.um2pix(obj.patternSize);
            [~, pixelsPerMicron] = obj.um2pix(1);
            patternSurround.spatialFreq = 1/(pixelsPerMicron*(obj.patternDimension)); % in cycles per pixel
            patternSurround.phase = 0;
            p.addStimulus(patternSurround);
            
            patternCenter = stage.builtin.stimuli.Grating(obj.gratingProfile, 1024);
            patternCenter.position = [0,0];
            patternCenter.orientation = obj.motionAngle;
            patternCenter.contrast = obj.contrast;
            patternCenter.size = obj.um2pix(obj.patternSize);
            [~, pixelsPerMicron] = obj.um2pix(1);
            patternCenter.spatialFreq = 1/(pixelsPerMicron*(obj.patternDimension)); % in cycles per pixel
            patternCenter.phase = 0;
            p.addStimulus(patternCenter);
            
            
            apertureDiameterRel = obj.centerDiameter / max(obj.patternSize);
            mask = stage.core.Mask.createAnnulus(-1, apertureDiameterRel, 2048);
            grat.setMask(mask);
            
            % random motion controller
            function pos = movementController(state, angle, center, motionPath)
                
                if state.frame < 1
                    frame = 1;
                else
                    frame = state.frame;
                end
                if size(motionPath,2) == 1
                    y = sind(angle) * motionPath(frame);
                    x = cosd(angle) * motionPath(frame);
                end
                pos = [x,y] + center;
                
            end
            
            controllerCenter = stage.builtin.controllers.PropertyController(patternCenter, ...
                'position', @(s)movementController(s, obj.motionAngle, canvasSize/2, obj.motionPathCenter));
            p.addController(controllerCenter);
            
            controllerSurround = stage.builtin.controllers.PropertyController(patternSurround, ...
                'position', @(s)movementController(s, obj.motionAngle, canvasSize/2, obj.motionPathSurround));
            p.addController(controllerSurround);
            
            obj.setOnDuringStimController(p, patternCenter);
            obj.setOnDuringStimController(p, patternSurround);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            
            totalNumEpochs = obj.numberOfCycles * obj.numberOfEpochs;
            
        end
        
        
    end
    
end