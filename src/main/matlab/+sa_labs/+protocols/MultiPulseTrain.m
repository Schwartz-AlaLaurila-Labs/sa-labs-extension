classdef MultiPulseTrain < sa_labs.protocols.BaseProtocol
    % Presents a pulse train to a specified amplifier and records from the same amplifier.
    % from A Sodium-Pump-Mediated Afterhyperpolarization in Pyramidal Neuron.JNeuroscience
    % All blame should be directed to Santiago Guardo (06.2024). He didn't really know what he was doing
    
    properties
        outputAmpSelection = 1              % Output amplifier (1 or 2)
        preTime = 500                       % Pulse leading duration (ms)
        SpikeTrainpulseTime = 2                       % Duration of each individual pulse (ms)
        testpulsetime = 50
        TestPulseAmplitude = 50
        tailTime = 500                    % Pulse trailing duration (ms)
        STFreq = 25                         % Stimulation frequency (Hz)
        PTFreq = 0.5                         % Test pulses frequency (Hz)
        pulseAmplitude = 1000               % Pulse amplitude (mV or pA depending on amp mode)
        PulseTrainTime = 250                   % Pulse train duration (ms)
        numberOfEpochs = 10;
    end
    
    properties (Dependent)
        numPulses % Total number of current/voltage train pulses
        test1numPulses = 4
        test2numPulses = 9
        stimTime
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = ''; %'pulseAmplitude';
        stim1Time = test1numPulses*(1000/obj.PTFreq)
        stim2Time = test2numPulses*(1000/obj.PTFreq)
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
        pulseInterval = 1000/obj.STFreq;      %time from the start of one pulse to the start of the next pulse (ms)
        intervalTime = pulseInterval - obj.SpikeTrainpulseTime; %Inter-pulse interval duration (ms)
        TestPulseInterval = 1000/obj.PTFreq;
        TestPulseIntervalTime = TestPulseInterval - obj.testpulsetime;
    end    
    
    methods
                
        
%         function prepareRun(obj)
%             prepareRun@sa_labs.protocols.BaseProtocol(obj, epoch);
%             
%         end
        
        function stim = createAmpStimulus(obj, ampName)

            stimCell = {};
            
            % create delay pulse
            % create background pulse
            genB = symphonyui.builtin.stimuli.PulseGenerator();
            
            genB.preTime = 0;
            genB.stimTime = obj.preTime+obj.stim1Time+obj.stim2Time+obj.tailTime;
            genB.tailTime = 0;
            genB.amplitude = obj.rig.getDevice(ampName).background.quantity;
            genB.mean = 0;
            genB.sampleRate = obj.sampleRate;
            genB.units = obj.rig.getDevice(ampName).background.displayUnits;

            stimCell{1} = genB.generate();
            
            %Create stim baseline pulses
            gen1 = symphonyui.builtin.stimuli.PulseTrainGenerator();
            
            gen1.preTime = obj.preTime;
            gen1.pulseTime = obj.testpulsetime;
            gen1.tailTime = (obj.PTFreq/2)*1000;  %Test pulses frequency over 2 (ms)
            gen1.intervalTime = obj.TestPulseIntervalTime;
            gen1.amplitude = obj.TestPulseAmplitude;
            gen1.numPulses = obj.test1numPulses;
            gen1.mean = 0;
            gen1.sampleRate = obj.sampleRate;
            gen1.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{2} = gen1.generate();

            %Create spike train

            gen2 = symphonyui.builtin.stimuli.PulseTrainGenerator();
            
            gen2.preTime = obj.preTime + obj.stim1Time;
            gen2.pulseTime = obj.SpikeTrainpulseTime;
            gen2.tailTime = (obj.PTFreq/2)*1000;
            gen2.intervalTime = obj.intervalTime;
            gen2.amplitude = obj.TestPulseAmplitude;
            gen2.numPulses = obj.test1numPulses;
            gen2.mean = 0; %obj.rig.getDevice(ampName).background.quantity;
            gen2.sampleRate = obj.sampleRate;
            gen2.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{3} = gen2.generate();

            %Create PostTrain pulses

            gen3 = symphonyui.builtin.stimuli.PulseTrainGenerator();
            
            gen3.preTime = obj.preTime + obj.stim1Time + obj.stim2Time;
            gen3.pulseTime = obj.testpulsetime;
            gen3.tailTime = obj.tailTime;  %Test pulses frequency over 2 (ms)
            gen3.intervalTime = obj.TestPulseIntervalTime;
            gen3.amplitude = obj.TestPulseAmplitude;
            gen3.numPulses = obj.test2numPulses;
            gen3.mean = 0;
            gen3.sampleRate = obj.sampleRate;
            gen3.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{4} = gen3.generate();

            % add together all stimuli
            genSum = symphonyui.builtin.stimuli.SumGenerator();
            genSum.stimuli = stimCell;
            stim = genSum.generate();
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
        function stimTime = get.stimTime(obj)
            stimTime = obj.stim1Time+obj.PulseTrainTime+obj.stim2Time;
        end 
        
    end
    
end

