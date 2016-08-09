classdef NonStageProtocol < sa_labs.protocols.BaseProtocol

    properties
        %times in ms
        preTime = 250	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 500	% Spot trailing duration (ms)
        
        numberOfEpochs = 50;
    end
    
    properties (Hidden)
        version = 1
        displayName = 'non stage prot'
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = '';        
    end
    
    methods
      

        function stim = createAmpStimulus(obj)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = 1;
            gen.mean = obj.rig.getDevice(obj.chan1).background.quantity;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(obj.chan1).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            epoch.addStimulus(obj.rig.getDevice(obj.chan1), obj.createAmpStimulus());
%             epoch.addResponse(obj.rig.getDevice(obj.chan1));
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfEpochs;
        end
        
        
    end
    
end