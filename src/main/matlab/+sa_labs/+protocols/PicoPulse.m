classdef PicoPulse < sa_labs.protocols.BaseProtocol
    % Presents a set of rectangular pulse stimuli to a specified amplifier and records from the same amplifier.
    % from the rieke lab with our thanks
    
    properties
        preTime = 500                    % Pulse leading duration (ms)
        stimTime = 500                  % Pulse duration (ms)
        tailTime = 500                   % Pulse trailing duration (ms)
        numberOfEpochs = 50;
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = ''; %'pulseAmplitude';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.sampleRate = obj.sampleRate;
            gen.amplitude = 5;
            gen.mean = 0;
            gen.units = 'V';
            triggers = obj.rig.getDevices('picospritz_trigger');
            if ~isempty(triggers)
                epoch.addStimulus(triggers{1},  gen.generate());
            else
                disp('no pico trigger device found')
            end
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
        
    end
    
end

