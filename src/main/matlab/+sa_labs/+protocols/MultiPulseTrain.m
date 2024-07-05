classdef MultiPulseTrain < sa_labs.protocols.BaseProtocol
    % Presents a pulse train to a specified amplifier and records from the same amplifier.
    % from A Sodium-Pump-Mediated Afterhyperpolarization in Pyramidal Neuron.JNeuroscience
    % All blame should be directed to Santiago Guardo (06.2024). He didn't really know what he was doing
    
    properties
        outputAmpSelection = 1              % Output amplifier (1 or 2)
        preTime = 500                       % Pulse leading duration (ms)
        SpikeTrainPulseTime = 2             % Duration of each individual pulse (ms)
        TestPulseTime = 50                  % Duration of each individual test pulse(ms)
        TestPulseAmplitude = 50             % Test pulse amplitude (pA)
        tailTime = 500                    % Pulse trailing duration (ms)
        STFreq = 25                         % Stimulation frequency (Hz)
        pulseAmplitude = 1000               % Pulse amplitude (mV or pA depending on amp mode)
        PulseTrainTime = 250                   % Pulse train duration (ms)
        numberOfEpochs = 10
        test1numPulses = 4
        test2numPulses = 9
        PTFreq = 0.5
    end
    
    properties (Dependent)
        numPulses % Total number of current/voltage train pulses
        StNumPulses
        stimTime
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = ''; %'pulseAmplitude';
        
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
        pulseInterval      %time from the start of one pulse to the start of the next pulse (ms)
        intervalTime %Inter-pulse interval duration (ms)
        TestPulseInterval 
        TestPulseIntervalTime
        stim1Time
        stim2Time
    end    
    
    methods
                
        
%         function prepareRun(obj)
%             prepareRun@sa_labs.protocols.BaseProtocol(obj, epoch);
%             
%         end
        
        function stim = createAmpStimulus(obj, ampName)

            stimCell = {};
            
            %create delay pulse
            % create background pulse
            genB = symphonyui.builtin.stimuli.PulseGenerator();
            
            genB.preTime = 0;
            genB.stimTime = obj.preTime + obj.stim1Time + obj.PulseTrainTime + obj.stim2Time + obj.tailTime;
            genB.tailTime = 0;
            genB.amplitude = obj.rig.getDevice(ampName).background.quantity;
            genB.mean = 0;
            genB.sampleRate = obj.sampleRate;
            genB.units = obj.rig.getDevice(ampName).background.displayUnits;

            stimCell{1} = genB.generate();
            
            %Create stim baseline pulses
            gen1 = symphonyui.builtin.stimuli.PulseTrainGenerator();
            
            gen1.preTime = obj.preTime;
            gen1.pulseTime = obj.TestPulseTime;
            gen1.tailTime =  obj.PulseTrainTime + obj.stim2Time+obj.tailTime; 
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
            gen2.pulseTime = obj.SpikeTrainPulseTime;
            gen2.tailTime = obj.stim2Time+obj.tailTime;
            actual_dur = obj.pulseInterval * obj.StNumPulses - obj.intervalTime;
            dur_diff = obj.PulseTrainTime - actual_dur;
            gen2.tailTime = gen2.tailTime + dur_diff;
            gen2.intervalTime = obj.intervalTime;
            gen2.amplitude = obj.pulseAmplitude;
            gen2.numPulses = obj.StNumPulses;
            gen2.mean = 0; %obj.rig.getDevice(ampName).background.quantity;
            gen2.sampleRate = obj.sampleRate;
            gen2.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{3} = gen2.generate();

            %Create PostTrain pulses

            gen3 = symphonyui.builtin.stimuli.PulseTrainGenerator();
            
            gen3.preTime = obj.preTime + obj.stim1Time + obj.PulseTrainTime;
            gen3.pulseTime = obj.TestPulseTime;
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
        
        %Define dependent properties and how they are calculated
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end        
        function StNumPulses = get.StNumPulses(obj)
            StNumPulses = floor(obj.PulseTrainTime / obj.pulseInterval);
        end
        function numPulses = get.numPulses(obj)
            numPulses = obj.test1numPulses + obj.test2numPulses + obj.StNumPulses; 
        end
        
        function stimTime = get.stimTime(obj)
            stimTime = obj.stim1Time+obj.PulseTrainTime+obj.stim2Time;
        end
        
        function stim1Time = get.stim1Time(obj) 
            %stim1Time = obj.test1numPulses*(1000/obj.PTFreq); %this is wrong
            stim1Time = (obj.test1numPulses * obj.TestPulseTime)+ (obj.test1numPulses-1)  *obj.TestPulseIntervalTime;
        end
        
        function stim2Time = get.stim2Time(obj)
            %stim2Time = obj.test2numPulses*(1000/obj.PTFreq); %this is wrong
            stim2Time = (obj.test2numPulses * obj.TestPulseTime)+ (obj.test2numPulses-1)  *obj.TestPulseIntervalTime;
        end
        
        function intervalTime = get.intervalTime(obj)
            intervalTime = obj.pulseInterval - obj.SpikeTrainPulseTime; %Inter-pulse interval duration (ms)
        end
        function pulseInterval = get.pulseInterval(obj)
            pulseInterval = 1000/obj.STFreq;
        end
        function TestPulseInterval = get.TestPulseInterval(obj)
            TestPulseInterval = 1000/obj.PTFreq;
        end
        
        function TestPulseIntervalTime = get.TestPulseIntervalTime(obj)
            TestPulseIntervalTime = obj.TestPulseInterval - obj.TestPulseTime;
        end
        
        
    end
    
end

