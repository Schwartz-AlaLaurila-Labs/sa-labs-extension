classdef StepPulseScale < sa_labs.protocols.BaseProtocol
    properties
        outputAmpSelection = 1
        preTime = 500
        minStimTime = 100
        stimTime = 100
        tailTime = 2000
        numberOfSteps = 5
        maxAmplitude = 300
        numberOfCycles = 3
        randomOrdering = true;
        scaleFactor = 2;
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian'
        responsePlotSplitParameter = 'scaledAmplitude';
        pulseVector
        stimtimeVector
        adjustedTailTimeVector
        scaledStimTime
        scaledAmplitude
        adjustedTailTime
    end
    
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        function prepareRun(obj)
            
            prepareRun@sa_labs.protocols.BaseProtocol(obj);
            scale_vector = obj.scaleFactor .^ ([0 : obj.numberOfSteps - 1]);
            obj.pulseVector = obj.maxAmplitude ./ scale_vector;
            obj.stimtimeVector = obj.minStimTime * scale_vector;
            obj.adjustedTailTimeVector = obj.tailTime + (max(obj.stimtimeVector) - obj.stimtimeVector);
            
        end
        
        function stim = createAmpStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.scaledStimTime;
            gen.tailTime = obj.adjustedTailTime;
            gen.amplitude = obj.scaledAmplitude;
            gen.mean = 0;
            gen.sampleRate = obj.sampleRate;
            gen.units = 'pA';
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            
            outputAmpName = sprintf('amp%g', obj.outputAmpSelection);
            
            index = mod(obj.numEpochsPrepared, obj.numberOfSteps);
            if index == 0 && obj.randomOrdering
                idx = randperm(obj.numberOfSteps);
                obj.pulseVector = obj.pulseVector(idx);
                obj.stimtimeVector = obj.stimtimeVector(idx);
                obj.adjustedTailTimeVector = obj.adjustedTailTimeVector(idx);
            end
            obj.scaledStimTime = obj.stimtimeVector(index + 1);
            obj.scaledAmplitude = obj.pulseVector(index + 1);
            obj.adjustedTailTime = obj.adjustedTailTimeVector(index + 1);
            
            epoch.addParameter('scaleStimTime', obj.scaledStimTime);
            epoch.addParameter('scaledAmplitude', obj.scaledAmplitude);
            epoch.addParameter('adjustedTailTime', obj.adjustedTailTime);
            
            obj.stimTime = obj.scaledStimTime;
            obj.tailTime = obj.adjustedTailTime;

            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            epoch.addStimulus(obj.rig.getDevice(outputAmpName), obj.createAmpStimulus());
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles*obj.numberOfSteps;
        end
        
    end
end

