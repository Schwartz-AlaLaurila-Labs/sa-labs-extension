classdef MultiPulse < sa_labs.protocols.BaseProtocol
    % Presents a set of rectangular pulse stimuli to a specified amplifier and records from the same amplifier.
    % from the rieke lab with our thanks
    % Presents one or two rectangular pulses 
    % Sophia updated 12/7/18 to add in potential time intervals between steps
    
    properties
        outputAmpSelection = 1          % Output amplifier (1 or 2)
        preTime = 500                    % Pulse leading duration (ms)
        stepByStim = 'Stim 1'          % Which pulse are you stepping through (1 or 2)
        interTimeOpts = 'none'       % Do you want no time, a contant amount, or a changing amount of time between stim1 and stim2
        numberOfSteps = 20               % How many steps do you want
        stim1Time = 500                  % Pulse 1 duration (ms)
        stim2Time = 0                   % Pulse 2 duration (ms)
        interTime = 0                   % Time between stim1 and stim2 (ms)
        tailTime = 1000                   % Pulse trailing duration (ms)
        pulse1Amplitude = 0            % Pulse 1 amplitude (mV or pA depending on amp mode)
        pulse2Amplitude = 0              % Pulse 2 amplitude (mV or pA depending on amp mode)
        interTimeAmplitude = 0          % Inter time amplitude from baseline
        minAmplitude = -300              % when you step the stimulus, what is the min
        maxAmplitude = 300              % when you step the stimulus, what is the max
        minInterTime = 0                % min time between stim1 and stim2, if interTimeOpts = 'variable'
        maxInterTime = 0                % max time between stim1 and stim2, if interTimeOpts = 'variable'
        numberOfCycles = 3
        logScaling = true % scale spot size logarithmically (more precision in smaller sizes)
        randomOrdering = true
        logGenerator = 'log'
        min_of_log = 5;
        delayStart = 0; %delay start (ms)
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian'
        
        stepByStimType = symphonyui.core.PropertyType('char', 'row', {'neither', 'Stim 1', 'Stim 2'})
        interTimeOptsType = symphonyui.core.PropertyType('char', 'row', {'none', 'constant', 'variable'})
        pulseVector
        interTimeVector
        pulse1Curr
        pulse2Curr
        currInterTime
        logGeneratorType = symphonyui.core.PropertyType('char', 'row', {'log', 'cubic'})
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
                if strcmp(obj.logGenerator, 'log') 
                    
                    if sign(obj.minAmplitude) == sign(obj.maxAmplitude)
                        obj.pulseVector = logspace(log10(obj.minAmplitude), log10(obj.maxAmplitude), obj.numberOfSteps);
                    else
                        nsteps = round(obj.numberOfSteps ./ 2);
                        pos_vector = logspace(log10(obj.min_of_log), log10(obj.maxAmplitude), nsteps);
                        neg_vector = -logspace(log10(obj.min_of_log), log10(abs(obj.minAmplitude)), obj.numberOfSteps - nsteps);
                        obj.pulseVector = [pos_vector neg_vector];
                    end
                elseif strcmp(obj.logGenerator, 'cubic')
                     obj.pulseVector = linspace(nthroot(obj.minAmplitude,3), nthroot(obj.maxAmplitude,3), obj.numberOfSteps) .^ 3;
                end
            end
            if ~obj.logScaling
                obj.interTimeVector = linspace(obj.minInterTime, obj.maxInterTime, obj.numberOfSteps);
            else
                obj.interTimeVector = logspace(log10(obj.minInterTime), log10(obj.maxInterTime), obj.numberOfSteps);
            end

        end
        
        function stim = createAmpStimulus(obj, ampName, index)
            stimCell = {};
            % create delay pulse
            % create background pulse
            genB = symphonyui.builtin.stimuli.PulseGenerator();
            
            genB.preTime = 0;
            genB.stimTime = obj.preTime+obj.stim1Time+obj.stim2Time+obj.maxInterTime+obj.tailTime;
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
            gen1.tailTime = obj.maxInterTime+obj.stim2Time+obj.tailTime;
            gen1.amplitude = obj.pulse1Curr;
            gen1.mean = 0;
            gen1.sampleRate = obj.sampleRate;
            gen1.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{2} = gen1.generate();
            
            % create inter time pulse
            genI = symphonyui.builtin.stimuli.PulseGenerator();
            
            genI.preTime = obj.preTime+obj.stim1Time;
            genI.stimTime = obj.currInterTime;
            genI.tailTime = (obj.maxInterTime-obj.currInterTime)+obj.stim2Time+obj.tailTime;
            genI.amplitude = obj.interTimeAmplitude;
            genI.mean = 0;
            genI.sampleRate = obj.sampleRate;
            genI.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{3} = genI.generate();
            
            
            % create stim 2 pulse
            gen2 = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen2.preTime = obj.preTime+obj.stim1Time+obj.currInterTime;
            gen2.stimTime = obj.stim2Time;
            gen2.tailTime = (obj.maxInterTime-obj.currInterTime)+obj.tailTime;
            gen2.amplitude = obj.pulse2Curr;
            gen2.mean = 0;
            gen2.sampleRate = obj.sampleRate;
            gen2.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{4} = gen2.generate();
            
            % create end inter time pulse
            genI2 = symphonyui.builtin.stimuli.PulseGenerator();
            
            genI2.preTime = obj.preTime+obj.stim1Time+obj.currInterTime+obj.stim2Time;
            genI2.stimTime = obj.maxInterTime - obj.currInterTime;
            genI2.tailTime = obj.tailTime;
            genI2.amplitude = obj.interTimeAmplitude;
            genI2.mean = 0;
            genI2.sampleRate = obj.sampleRate;
            genI2.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stimCell{5} = genI2.generate();
            
            % add together all five stimuli
            genSum = symphonyui.builtin.stimuli.SumGenerator();
            genSum.stimuli = stimCell;
            stim = genSum.generate();
        end
                
        function prepareEpoch(obj, epoch)
            
            % for each cycle generate a new random ordering
            index = mod(obj.numEpochsPrepared, obj.numberOfSteps);
            obj.pulseVector = sort(obj.pulseVector);
            obj.interTimeVector = sort(obj.interTimeVector);
            if index == 0  && obj.randomOrdering 
                obj.pulseVector = obj.pulseVector(randperm(obj.numberOfSteps));
                obj.interTimeVector = obj.interTimeVector(randperm(obj.numberOfSteps));
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
                epoch.addParameter('pulseVector', obj.pulseVector);
            elseif strcmp(obj.stepByStim, 'Stim 2')
                obj.pulse1Curr = obj.pulse1Amplitude;
                obj.pulse2Curr = obj.pulseVector(index+1);
                epoch.addParameter('pulseVector', obj.pulseVector);
            end
            if strcmp(obj.interTimeOpts, 'none')
                obj.currInterTime = 0;
            elseif strcmp(obj.interTimeOpts, 'constant')
                obj.currInterTime = obj.interTime;
            elseif strcmp(obj.interTimeOpts, 'variable')
                obj.currInterTime = obj.interTimeVector(index+1);
                epoch.addParameter('interTimeVector', obj.interTimeVector);
            end
            epoch.addParameter('pulse1Curr', obj.pulse1Curr);
            epoch.addParameter('pulse2Curr', obj.pulse2Curr);
            epoch.addParameter('currInterTime', obj.currInterTime);

            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            outputAmpName = sprintf('amp%g', obj.outputAmpSelection);
            
            epoch.addStimulus(obj.rig.getDevice(outputAmpName), obj.createAmpStimulus(outputAmpName));
            
            
        end
        
        % set dependent variables
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles*obj.numberOfSteps;
        end        
        function stimTime = get.stimTime(obj)
            stimTime = obj.stim1Time+obj.stim2Time+obj.maxInterTime;
        end   
        function responsePlotSplitParameter = get.responsePlotSplitParameter(obj)
            if strcmp(obj.interTimeOpts, 'variable')
                responsePlotSplitParameter = 'currInterTime';
            elseif strcmp(obj.stepByStim, 'Stim 2')
                responsePlotSplitParameter = 'pulse2Curr';
            else
                responsePlotSplitParameter = 'pulse1Curr';
            end
        end
    end
    
end

