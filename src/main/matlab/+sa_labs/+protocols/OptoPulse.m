classdef OptoPulse < sa_labs.protocols.BaseProtocol
    % Presents a set of rectangular pulse stimuli to a specified amplifier and records from the same amplifier.
    % from the rieke lab with our thanks
    
    properties
        preTime = 1000                    % Pulse leading duration (ms)
        stimTime = 500                  % Pulse duration (ms)
        tailTime = 1000                   % Pulse trailing duration (ms)
        numberOfEpochs = 75;
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = ''; %'pulseAmplitude';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods

%         function stim = createOptoStimulus(obj)
% 
%             pulseInterval = 1000/obj.trainFreq;      %time from the start of one pulse to the start of the next pulse (ms)
%             intervalTime = pulseInterval - obj.pulseTime; %Inter-pulse interval duration (ms)
% 
% 
%             gen = symphonyui.builtin.stimuli.PulseTrainGenerator();
% 
%             gen.preTime = obj.preTime;
%             gen.pulseTime = obj.pulseTime;
%             gen.tailTime = obj.tailTime;
%             gen.intervalTime = intervalTime;
%             gen.amplitude = 1;
%             gen.numPulses = obj.numPulses;
%             gen.mean =0;
%             gen.sampleRate = obj.sampleRate;
%             gen.units = obj.rig.getDevice(ampName).background.displayUnits;
% 
%             stim = gen.generate();
%         end
            
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.sampleRate = obj.sampleRate;
            gen.amplitude = 1;
            gen.mean = 0;
            gen.units = Symphony.Core.Measurement.UNITLESS;
            triggers = obj.rig.getDevices('Optogenetics Trigger');
            if ~isempty(triggers)
                epoch.addStimulus(triggers{1},  gen.generate());
            else
                disp('no opto trigger device found')
            end 

        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
        
    end
    
end

