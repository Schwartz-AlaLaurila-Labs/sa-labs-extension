classdef WhiteNoisePulse < sa_labs.protocols.BaseProtocol
    properties
        outputAmpSelection = 1
        preTime = 500
        stimTime = 1000
        tailTime = 500
        amplitude = 0 %pA
        std = 20 %pA
        frequency = 100 %Hz
        numberOfEpochs = 5
        seedStartValue = 1
        seedChangeMode = 'increment only';
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian'
        responsePlotSplitParameter = ''; %'pulseAmplitude';
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only',});
        randomSeed;
    end
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.BaseProtocol(obj);
            % obj.responseFigure = obj.showFigure('sa_labs.figures.WhiteNoisePulseFigure', obj.devices, ...
            %         'totalNumEpochs',obj.totalNumEpochs,...
            %         'analysisRegion', 1e-3 * [obj.preTime, obj.preTime + obj.stimTime],...
            %         'responseMode',obj.chan1Mode,... % TODO: different modes for multiple amps
            %         'spikeThreshold', obj.spikeThreshold, ...
            %         'spikeDetectorMode', obj.spikeDetectorMode);
        end
        
    

        function stim = createAmpStimulus(obj, ampName)
            %Create white noise with pre and tail time with chosen frequency;
            
            sample_rate = obj.sampleRate;
            prestim_wave = repelem(0, obj.preTime * sample_rate / 1E3);
            tailstim_wave = repelem(0, obj.tailTime * sample_rate / 1E3);
            rate = 1;
            if sample_rate > obj.frequency
                rate = ceil(sample_rate / obj.frequency);
            end
            n_stimpoints = obj.stimTime * sample_rate / 1E3;
            random_stream = RandStream("twister", 'Seed', obj.randomSeed);
            white_noise_wave = sa_labs.util.randn(random_stream, 1, n_stimpoints) .* obj.std + obj.amplitude;
            down_sample_wave = downsample(white_noise_wave, rate); %this is so convoluted lol can do the other way but oh well...
            stim_wave = repelem(down_sample_wave, rate);
            if length(stim_wave) > n_stimpoints
                stim_wave = stim_wave(1 : n_stimpoints); %may introduce bug teehee
            end
            
            totalWave = horzcat(prestim_wave, stim_wave, tailstim_wave); 
            
            
            %Create Waveform stimulus
            gen = symphonyui.builtin.stimuli.WaveformGenerator();
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(ampName).background.displayUnits;
            gen.waveshape = totalWave;
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            outputAmpName = sprintf('amp%g', obj.outputAmpSelection);

            if strcmp(obj.seedChangeMode, 'repeat only')
                seed = obj.seedStartValue;
            elseif strcmp(obj.seedChangeMode, 'increment only')
                seed = obj.numEpochsPrepared + obj.seedStartValue;
            else
                seedIndex = mod(obj.numEpochsPrepared,2);
                if seedIndex == 0
                    seed = obj.seedStartValue;
                elseif seedIndex == 1
                    seed = obj.seedStartValue + (obj.numEpochsPrepared + 1) / 2;
                end
            end
            
            obj.randomSeed = seed;
            epoch.addParameter('randomSeed', obj.randomSeed);
            fprintf('Using seed %d\n', obj.randomSeed);
            epoch.addStimulus(obj.rig.getDevice(outputAmpName), obj.createAmpStimulus(outputAmpName));
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
        
    end
end