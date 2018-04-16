classdef RandomMotionObject < sa_labs.protocols.StageProtocol
    
    
    properties
        %times in ms
        preTime = 0;
        tailTime = 0;
        stimTime = 30000;
        
        intensity = 0.5;
        spotSize = 80;
        
        motionSeedStart = 1;
        motionSeedChangeMode = 'repeat only';
        motionStandardDeviation = 500; % µm
        motionLowpassFilterPassband = 3; % Hz
        
        numberOfCycles = 3;
        
    end
    
    properties (Hidden)
        version = 1
        motionPath
        motionSeed
        
        motionSeedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})

        motionFilter
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'motionSeed';
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

            frameRate = 60;
            obj.motionFilter = designfilt('lowpassfir','PassbandFrequency',obj.motionLowpassFilterPassband,'StopbandFrequency',obj.motionLowpassFilterStopband,'SampleRate',frameRate);

            
        end
        
        function prepareEpoch(obj, epoch)
            % Call the base method
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
            
            if strcmp(obj.motionSeedChangeMode, 'repeat only')
                seed = obj.motionSeedStart;
            elseif strcmp(obj.motionSeedChangeMode, 'increment only')
                seed = obj.numEpochsCompleted + obj.motionSeedStart;
            else
                seedIndex = mod(obj.numEpochsCompleted,2);
                if seedIndex == 0
                    seed = obj.motionSeedStart;
                elseif seedIndex == 1
                    seed = obj.motionSeedStart + (obj.numEpochsCompleted + 1) / 2;
                end
            end
            obj.motionSeed = seed;
            
            epoch.addParameter('motionSeed', obj.motionSeed);
            
            fprintf('Using seed %g\n', obj.motionSeed);
            
            % create the motion path
            stream = RandStream('mt19937ar', 'Seed', obj.motionSeed);
            
            for dim = 1:2
                mp = obj.motionStandardDeviation .* stream.randn((obj.stimTime + obj.preTime)/1000 * frameRate + 100, 1);
                obj.motionPath(:,dim) = filtfilt(obj.motionFilter, mp);
            end            
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);           
            
            ob = stage.builtin.stimuli.Ellipse();
            ob.radiusX = round(obj.um2pix(obj.spotSize / 2));
            ob.radiusY = ob.radiusX;
            ob.color = obj.intensity;
            ob.opacity = 1;
            p.addStimulus(ob);
            
            % random motion controller
            function pos = movementController(state, center, motionPath)
                
                if state.frame < 1
                    frame = 1;
                else
                    frame = state.frame;
                end
                y = motionPath(frame, 2);
                x = motionPath(frame, 1);
                pos = [x,y] + center;
                    
            end
            
            controller = stage.builtin.controllers.PropertyController(ob, ...
                'position', @(s)movementController(s, canvasSize/2, obj.motionPath));
            p.addController(controller);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            
            totalNumEpochs = obj.numberOfCycles;

        end
        
        function motionLowpassFilterStopband = get.motionLowpassFilterStopband(obj)
            motionLowpassFilterStopband = obj.motionLowpassFilterPassband * 1.2;
        end
        
    end
    
end