classdef WhiteToPinkNoisePulse < sa_labs.protocols.BaseProtocol
    properties
        outputAmpSelection = 1
        preTime = 500
        stimTime = 1000
        tailTime = 500
        amplitude = 0 %pA
        std = 20 %pA
        frequency = 100 %Hz
        betas = [0,1] % Spectral slope of the noise (0=white, 1=pink)
        numberOfEpochsPerBeta = uint16(5) % Number of epochs for each Beta value
        seedStartValue = 1
        seedChangeMode = 'increment only';
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian'
        responsePlotSplitParameter = ''; %'pulseAmplitude';
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only',});
        noiseSeed
        noiseStream
        beta
        permutedBetas
        permutedSeeds
    end

    properties (Dependent)
        totalNumEpochs
    end
    
    methods
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.BaseProtocol(obj);
            allBetas = repelem(obj.betas, obj.numberOfEpochsPerBeta);
             % Step 2: Create allSeeds according to the seed change mode
            allSeeds = zeros(size(allBetas));
            for i = 1:length(allBetas)
                if strcmp(obj.seedChangeMode, 'repeat only')
                    seed = obj.seedStartValue; % Same seed every time
                elseif strcmp(obj.seedChangeMode, 'increment only')
                    seed = obj.seedStartValue + i - 1; % Increment seed on every epoch
                elseif strcmp(obj.seedChangeMode, 'repeat & increment')
                    seedIndex = mod(i - 1, 4); % Cycle every 2 epochs
                    if seedIndex == 0
                        seed = obj.seedStartValue;
                    else
                        seed = obj.seedStartValue + floor((i + 1) / 2);
                    end
                else
                    error('Invalid seed change mode. Choose one of "repeat only", "repeat & increment", or "increment only".');
                end
                allSeeds(i) = seed;
            end
            % Step 3: Generate one permutation for both frame dwells and seeds
            stream = RandStream('twister', 'Seed', obj.seedStartValue+20); % Use local stream
            permutationIndices = randperm(stream, length(allBetas)); % One permutation for both

            % Apply the same permutation to both frame dwells and seeds
            obj.permutedBetas = allBetas(permutationIndices);
            obj.permutedSeeds = allSeeds(permutationIndices);
        end
        
    

        function stim = createAmpStimulus(obj, ampName)
            stream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            sample_rate = obj.sampleRate;
            n_stimpoints = round(obj.stimTime * sample_rate / 1E3); 
            n_prestimpoints = round(obj.preTime * sample_rate / 1E3);
            n_tailstimpoints = round(obj.tailTime * sample_rate / 1E3);

            % Determine noise generation rate
            rate = max(1, round(sample_rate / obj.frequency));  
            n_noise_points = ceil(n_stimpoints / rate);

            % Generate 1/f^beta noise spectrum
            freqs = linspace(0, rate/2, floor(n_noise_points/2) + 1);
            amplitudes = zeros(size(freqs));
            amplitudes(2:end) = freqs(2:end) .^ (-obj.beta / 2); 
            amplitudes(1) = 0; % Avoid DC offset

            % Random phase for each frequency component
            phases = exp(1i * 2 * pi * rand(stream, 1, length(freqs)));

            % Construct symmetric frequency spectrum for real-valued IFFT
            spectrum = [amplitudes .* phases, conj(amplitudes(end-1:-1:2) .* phases(end-1:-1:2))];

            % Convert to time domain & normalize
            raw_noise = real(ifft(fftshift(spectrum), 'symmetric')); 
            raw_noise = raw_noise / std(raw_noise, 1); 

            % Upsample noise before truncation to match n_stimpoints
            time_noise = linspace(0, obj.stimTime, length(raw_noise));
            time_interp = linspace(0, obj.stimTime, n_stimpoints);
            stim_wave = interp1(time_noise, raw_noise, time_interp, 'linear', 'extrap'); 

            % Scale by std and amplitude
            noise_intensity_adj = obj.amplitude + obj.std * stim_wave;

            % Construct full waveform
            totalWave = [zeros(1, n_prestimpoints), noise_intensity_adj, zeros(1, n_tailstimpoints)];

            % Create waveform stimulus
            gen = symphonyui.builtin.stimuli.WaveformGenerator();
            gen.sampleRate = sample_rate;
            gen.units = obj.rig.getDevice(ampName).background.displayUnits;
            gen.waveshape = totalWave;
            stim = gen.generate();
        end

        
        function prepareEpoch(obj, epoch)
            
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            outputAmpName = sprintf('amp%g', obj.outputAmpSelection);
            currentEpochIndex = obj.numEpochsPrepared ;
%             disp(['Total Epochs Completed: ', num2str(obj.numEpochsCompleted)]);
%             disp(['Total Epochs prepared: ', num2str(obj.numEpochsPrepared )]);
%             disp(['Total Epochs computed: ', num2str(obj.totalNumEpochs )]);
            % Select frame dwell and seed from the precomputed lists
            obj.beta = obj.permutedBetas(currentEpochIndex);
            obj.noiseSeed = obj.permutedSeeds(currentEpochIndex);

            % Print the frame dwell and seed for the current epoch
            fprintf('Epoch %d: Beta = %d, Seed = %d\n', currentEpochIndex, obj.beta, obj.noiseSeed)
            % Track parameters for this epoch
            epoch.addParameter('beta', obj.beta); 
            epoch.addParameter('noiseSeed', obj.noiseSeed);

            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            epoch.addStimulus(obj.rig.getDevice(outputAmpName), obj.createAmpStimulus(outputAmpName));
            
            % if obj.numEpochsCompleted < obj.numEpochsPrepared
            %     pause(obj.stimTime / 1000)
            %     disp('Pausing to catch up hehe')
            % end
            
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochsPerBeta * length(obj.betas);
        end
        
        
    end
end