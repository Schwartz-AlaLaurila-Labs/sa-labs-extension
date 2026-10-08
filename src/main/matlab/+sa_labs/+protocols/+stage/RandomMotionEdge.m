classdef RandomMotionEdge < sa_labs.protocols.StageProtocol
    
    
    properties
        %times in ms
        preTime = 0;
        tailTime = 0;
        stimTime = 20000;
        
        intensity = 0.5;
        barLength = 100;
        barWidth = 3000;
        singleEdgeMode = false;
        singleEdgePolarity = 1; % 1 or -1
        
        numberOfAngles = 2;
        angleOffset = 0;
        
        motionSeed = 1;
        motionStandardDeviation = 400; % �m
        motionLowpassFilterPassband = 5; % Hz
        
        numberOfCycles = 3;
        
    end
    
    properties (Hidden)
        version = 1
        curAngle
        angles
        motionPath
        randomMotionDimensions = 1; % keep at 1, doesn't work yet

        responsePlotMode = 'polar';
        responsePlotSplitParameter = 'movementAngle';
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
            
            %set directions
            obj.angles = rem((0:round(180/obj.numberOfAngles):179) + obj.angleOffset, 180);

            
            % create the motion path
            frameRate = 60;
            motionFilter = designfilt('lowpassfir','PassbandFrequency',obj.motionLowpassFilterPassband,'StopbandFrequency',obj.motionLowpassFilterStopband,'SampleRate',frameRate);
            stream = RandStream('mt19937ar', 'Seed', obj.motionSeed);
            obj.motionPath = obj.motionStandardDeviation .* stream.randn((obj.stimTime + obj.preTime)/1000 * frameRate + 100, 1);
            obj.motionPath = filtfilt(motionFilter, obj.motionPath);
            
        end
        
        function prepareEpoch(obj, epoch)
            
            % Randomize angles if this is a new set
            index = mod(obj.numEpochsPrepared, obj.numberOfAngles);
            if index == 0
                obj.angles = obj.angles(randperm(obj.numberOfAngles));
            end

            obj.curAngle = obj.angles(index+1);
            epoch.addParameter('movementAngle', obj.curAngle);
                        
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);           
            
            if obj.singleEdgeMode
                lengthIncreaseForSingleEdgeMode = 2000;
            else
                lengthIncreaseForSingleEdgeMode = 0;
            end                  
             
            bar = stage.builtin.stimuli.Rectangle();
            bar.color = obj.intensity;
            bar.opacity = 1;
            bar.orientation = obj.curAngle;
            bar.size = [obj.um2pix(obj.barLength + lengthIncreaseForSingleEdgeMode), obj.um2pix(obj.barWidth)];
            p.addStimulus(bar);
            
            if obj.singleEdgeMode
                edgeOffsetForSingleEdgeMode = obj.um2pix((obj.barLength + lengthIncreaseForSingleEdgeMode) / 2); % move bar back half a length to time-center leading edge
            else
                edgeOffsetForSingleEdgeMode = 0;
            end
            if obj.singleEdgePolarity < 0 
                edgeOffsetForSingleEdgeMode = edgeOffsetForSingleEdgeMode * -1;
            end
            
            % random motion controller
            % The controller closure is serialized to the Stage server, so it
            % captures plain values only (never obj or a nested function,
            % which shares this workspace and drags obj along).
            curAngle = obj.curAngle;
            motionPath = obj.motionPath;
            center = canvasSize/2;
            controller = stage.builtin.controllers.PropertyController(bar, ...
                'position', @(s) sa_labs.controllers.RandomMotionEdge_motionPosition( ...
                s.frame, curAngle, center, motionPath, edgeOffsetForSingleEdgeMode));
            p.addController(controller);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            
            totalNumEpochs = obj.numberOfCycles * obj.numberOfAngles;

        end
        
        function motionLowpassFilterStopband = get.motionLowpassFilterStopband(obj)
            motionLowpassFilterStopband = obj.motionLowpassFilterPassband * 1.2;
        end

    end

end