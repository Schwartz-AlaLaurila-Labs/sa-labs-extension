classdef MultiPulse < sa_labs.protocols.BaseProtocol
    % Presents a set of rectangular pulse stimuli to a specified amplifier and records from the same amplifier.
    % from the rieke lab with our thanks
    % Presents one or two rectangular pulses 
    
    properties
        outputAmpSelection = 1          % Output amplifier (1 or 2)
        preTime = 500                    % Pulse leading duration (ms)
        stepByStim = 'Stim 2'%'neither'          % Which pulse are you stepping through (1 or 2)
        numberOfSteps = 5%1               % How many steps do you want
        stim1Time = 500                  % Pulse 1 duration (ms)
        stim2Time = 300%0                   % Pulse 2 duration (ms)
        tailTime = 1000                   % Pulse trailing duration (ms)
        pulse1Amplitude = 200%100            % Pulse 1 amplitude (mV or pA depending on amp mode)
        pulse2Amplitude = 0              % Pulse 2 amplitude (mV or pA depending on amp mode)
        minAmplitude = 0              % when you step the stimulus, what is the min
        maxAmplitude = 100              % when you step the stimulus, what is the max
        
        numberOfCycles = 10
        logScaling = false % scale spot size logarithmically (more precision in smaller sizes)
        randomOrdering = true;
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian';
        
        stepByStimType = symphonyui.core.PropertyType('char', 'row', {'neither', 'Stim 1', 'Stim 2'})
        pulseVector
        pulse1Curr
        pulse2Curr
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
        stimTime
        responsePlotSplitParameter
    end    
    
    methods   
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.BaseProtocol(obj, true);
            
            %set amplitude pulse vector
            if ~obj.logScaling
                obj.pulseVector = linspace(obj.minAmplitude, obj.maxAmplitude, obj.numberOfSteps);
            else
                obj.pulseVector = logspace(log10(obj.minAmplitude), log10(obj.maxAmplitude), obj.numberOfSteps);
            end

        end
        
        function stim = createAmpStimulus(obj, ampName)
            stimCell = {};
            
            % create background pulse
            genB = symphonyui.builtin.stimuli.PulseGenerator();
            
            genB.preTime = 0;
            genB.stimTime = obj.preTime+obj.stimTime+obj.tailTime;
            genB.tailTime = 0;
            genB.amplitude = obj.rig.getDevice(ampName).background.quantity;
            genB.mean = 0;
            genB.sampleRate = obj.sampleRate;
            genB.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{1} = genB.generate();
            
            % create stim 1 pulse
            gen1 = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen1.preTime = obj.preTime;
            gen1.stimTime = obj.stim1Time;
            gen1.tailTime = obj.stim2Time+obj.tailTime;
            gen1.amplitude = obj.pulse1Curr;
            gen1.mean = 0;
            gen1.sampleRate = obj.sampleRate;
            gen1.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{2} = gen1.generate();
            
            % create stim 2 pulse
            gen2 = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen2.preTime = obj.preTime+obj.stim1Time;
            gen2.stimTime = obj.stim2Time;
            gen2.tailTime = obj.tailTime;
            gen2.amplitude = obj.pulse2Curr;
            gen2.mean = 0;
            gen2.sampleRate = obj.sampleRate;
            gen2.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{3} = gen2.generate();
            
            % add together all three stimuli
            genSum = symphonyui.builtin.stimuli.SumGenerator();
            genSum.stimuli = stimCell;
            stim = genSum.generate();
        end
                
        function prepareEpoch(obj, epoch)
            
            % for each cycle generate a new random ordering
            index = mod(obj.numEpochsPrepared, obj.numberOfSteps);
            if index == 0
                obj.pulseVector = obj.pulseVector(randperm(obj.numberOfSteps));
            end
            
            % set current pulses depending which one you're stepping by
            obj.pulse1Curr = 0;
            obj.pulse2Curr = 0;
            if strcmp(obj.stepByStim, 'neither')
                obj.pulse1Curr = obj.pulse1Amplitude;
                obj.pulse2Curr = obj.pulse2Amplitude;
            elseif strcmp(obj.stepByStim, 'Stim 1')
                obj.pulse1Curr = obj.pulseVector(index+1);
                obj.pulse2Curr = obj.pulse2Amplitude;
            elseif strcmp(obj.stepByStim, 'Stim 2')
                obj.pulse1Curr = obj.pulse1Amplitude;
                obj.pulse2Curr = obj.pulseVector(index+1);
            end
            epoch.addParameter('pulse1Curr', obj.pulse1Curr);
            epoch.addParameter('pulse2Curr', obj.pulse2Curr);

            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            outputAmpName = sprintf('amp%g', obj.outputAmpSelection);
            epoch.addStimulus(obj.rig.getDevice(outputAmpName), obj.createAmpStimulus(outputAmpName));
            
            
        end
        
        % set dependent variables
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles*obj.numberOfSteps;
        end        
        function stimTime = get.stimTime(obj)
            stimTime = obj.stim1Time+obj.stim2Time;
        end   
        function responsePlotSplitParameter = get.responsePlotSplitParameter(obj)
            if strcmp(obj.stepByStim, 'Stim 2')
                responsePlotSplitParameter = 'pulse2Curr';
            else
                responsePlotSplitParameter = 'pulse1Curr';
            end
        end
    end
    
end

