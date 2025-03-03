classdef Temporal_Noise_1_f < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500 % ms
        stimTime = 3000 % ms
        tailTime = 500 % ms
        
        contrast = .36 % weber contrast
        spotMeanLevel = 0.5 % Mean intensity of the light spot
        betas = [0, 1] % Spectral slope of the noise (0=white, 1=pink)
        numberOfEpochsPerBeta = uint16(30) % Number of epochs for each frame dwell
        
        aperture = 2000 % um diameter
        frameDwell = 1 %  The number of times each frame is repeated
        seedStartValue = 1
        seedChangeMode = 'increment only';
        colorNoiseMode = '1 pattern';
        colorNoiseDistribution = 'gaussian'
        
    end    
    
    properties (Hidden)
        version = 1;
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        colorNoiseModeType = symphonyui.core.PropertyType('char', 'row', {'1 pattern', '2 patterns'})
        colorNoiseDistributionType = symphonyui.core.PropertyType('char', 'row', {'uniform', 'gaussian', 'binary'})
        beta
        noiseSeed
        noiseStream
        noiseFn
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'noiseSeed';
        
        permutedBetas
        permutedSeeds
    end
    
    properties (Dependent)
        totalNumEpochs
    end
    
    methods
       
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case {'contrast'}
                    if obj.numberOfPatterns > 1
                        d.isHidden = true;
                    end
            end
        end
        
        function prepareRun(obj) % randomly permuts over betas. 
            prepareRun@sa_labs.protocols.StageProtocol(obj);

                % Step 1: Create all betas
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


        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            % Get the current epoch index (since MATLAB is 1-indexed)
            currentEpochIndex = obj.numEpochsCompleted + 1;

            % Select frame dwell and seed from the precomputed lists
            obj.beta = obj.permutedBetas(currentEpochIndex);
            obj.noiseSeed = obj.permutedSeeds(currentEpochIndex);

            % Print the frame dwell and seed for the current epoch
            fprintf('Epoch %d: Beta = %d, Seed = %d\n', currentEpochIndex, obj.beta, obj.noiseSeed);

            % Track parameters for this epoch
            epoch.addParameter('beta', obj.beta); 
            epoch.addParameter('noiseSeed', obj.noiseSeed);

            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);

            
            switch obj.colorNoiseDistribution
                case 'uniform'
                    obj.noiseFn = @() 2 * obj.noiseStream.rand() - 1; % Uniform from [-1, 1]
                case 'gaussian'
                    obj.noiseFn = @() sa_labs.util.randn(obj.noiseStream); % Gaussian noise
                case 'binary'
                    obj.noiseFn = @() 2 * (obj.noiseStream.rand() > .5) - 1; % Binary {+1, -1}
                otherwise
                    error('Invalid color noise distribution. Choose "uniform", "gaussian", or "binary".');
            end
        end

        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            preFrames = round(obj.frameRate * (obj.preTime / 1e3));
            stimFrames = round(obj.frameRate * (obj.stimTime / 1e3));
            frame_rate = round(obj.frameRate);
            % Create shapes
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.aperture / 2));
            spot.radiusY = spot.radiusX;
            spot.position = canvasSize / 2;
            spot.opacity = 1;
            
            p.addStimulus(spot);
            
            % Add controllers
            spotIntensityController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                @(state) getIntensity(obj, state.frame - preFrames));
            p.addController(spotIntensityController);
            
            function i = getIntensity(obj, frame)
                persistent intensity;
                if (frame < 0) || (frame > stimFrames)
                    intensity = obj.spotMeanLevel;
                else
                    if mod(frame, obj.frameDwell) == 0
                        noise_series = generateOneOverFNoise(obj, stimFrames);
                        if frame < length(noise_series) % Ensure valid indexing
                            intensity = noise_series(frame + 1);
                        else
                            intensity = noise_series(end); % Prevent out-of-bounds error
                        end
                    end
                end
                i = intensity;
                intensity = clipIntensity(intensity, obj.spotMeanLevel);
            end
            
            function intensity = clipIntensity(intensity, mn)
                intensity(intensity > mn * 2) = mn * 2;
                intensity(intensity < 0) = 0;
                intensity(intensity > 1) = 1;
            end

            function noise_intensity = generateOneOverFNoise(obj, frame_rate, stimFrames)
                stream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
                % Generate 1/f^beta noise in the frequency domain
                freqs = linspace(0, frame_rate/2, floor(stimFrames/2) + 1);
                amplitudes = zeros(size(freqs));
                amplitudes(2:end) = freqs(2:end) .^ (-obj.beta / 2); % Avoid divide by zero
            
                % Generate random phases
                phases = exp(1i * 2 * pi *  rand(stream, 1, length(freqs)));
            
                % Construct spectrum
                spectrum = amplitudes .* phases;
            
                % Convert back to time domain
                raw_noise = real(ifft([spectrum, conj(spectrum(end-1:-1:2))]));
                raw_noise = raw_noise(1:stimFrames); % Ensure correct length
                raw_noise = raw_noise / std(raw_noise,1); % Normalize to unit variance
            
                % Apply contrast scaling
                noise_intensity_adj = obj.spotMeanLevel * (1 + obj.contrast * raw_noise);
                noise_intensity = repelem(noise_intensity_adj, obj.frameDwell);
            end
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochsPerBeta * length(obj.betas);
        end
    end
end
