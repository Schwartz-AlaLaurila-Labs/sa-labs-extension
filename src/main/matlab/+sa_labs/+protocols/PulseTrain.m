classdef PulseTrain < sa_labs.protocols.BaseProtocol
    % Presents a pulse train to a specified amplifier and records from the same amplifier.
    % from A Sodium-Pump-Mediated Afterhyperpolarization in Pyramidal Neuron.JNeuroscience
    % All blame should be directed to Santiago Guardo (06.2024). He didn't really know what he was doing
    
    properties
        outputAmpSelection = 1              % Output amplifier (1 or 2)
        preTime = 500                       % Pulse leading duration (ms)
        pulseTime = 2                       % Duration of each individual pulse (ms)
        tailTime = 20000                    % Pulse trailing duration (ms)
        trainFreq = 25                      % Stimulation frequency (Hz)\
        pulseAmplitude = 1000               % Pulse amplitude (mV or pA depending on amp mode)
        stimTime = 3000                    % Pulse train duration (ms)
        numberOfEpochs = 10;
    end
    
    properties (Dependent)
        numPulses % Total number of current/voltage steps
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = ''; %'pulseAmplitude';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end    
    
    methods
                
        
%         function prepareRun(obj)
%             prepareRun@sa_labs.protocols.BaseProtocol(obj, epoch);
%             
%         end
        
        function stim = createAmpStimulus(obj, ampName)
            
            pulseInterval = 1000/obj.trainFreq;      %time from the start of one pulse to the start of the next pulse (ms)
            intervalTime = pulseInterval - obj.pulseTime; %Inter-pulse interval duration (ms)
            

            gen = symphonyui.builtin.stimuli.PulseTrainGenerator();
            
            gen.preTime = obj.preTime;
            gen.pulseTime = obj.pulseTime;
            gen.tailTime = obj.tailTime;
            gen.intervalTime = intervalTime;
            gen.amplitude = obj.pulseAmplitude;
            gen.numPulses = obj.numPulses;
            gen.mean = obj.rig.getDevice(ampName).background.quantity;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stim = gen.generate();
        end
                
        function prepareEpoch(obj, epoch)
%             epoch.addParameter('pulseAmplitude', obj.pulseAmplitude)
%             epoch.addParameter('TrainFrequency', obj.trainFreq)
%             epoch.addParameter('intervalTime', obj.intervalTime)
%             epoch.addParameter('numPulses', obj.numPulses)

            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
%             shutterDevice = obj.rig.getDevice('ScanImageShutter');
%             epoch.addResponse(shutterDevice);
            
            outputAmpName = sprintf('amp%g', obj.outputAmpSelection);
            epoch.addStimulus(obj.rig.getDevice(outputAmpName), obj.createAmpStimulus(outputAmpName));
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end        
        
        function numPulses = get.numPulses(obj)
            numPulses = obj.stimTime/(1000/obj.trainFreq); 
        end  
        
    end
    
end

