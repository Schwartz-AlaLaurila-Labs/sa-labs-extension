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
        permutationseed
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
                incCounter = 0;  % keeps track of how many times we've incremented so far
                
                for i = 1:length(allBetas)
                    switch obj.seedChangeMode
                        case 'repeat only'
                            % same seed every time
                            seed = obj.seedStartValue;
                
                        case 'increment only'
                            % strictly increasing seed on every epoch
                            seed = obj.seedStartValue + (i - 1);
                
                        case 'repeat & increment'
                            % every 3rd epoch => seedStartValue
                            % otherwise => incremented seed
                            if mod(i, 3) == 0
                                % on epochs 3,6,9,... use the start value again
                                seed = obj.seedStartValue;
                            else
                                % on all other epochs, increment from last time
                                seed = obj.seedStartValue + incCounter;
                                incCounter = incCounter + 1;
                            end
                
                        otherwise
                            error('Invalid seed change mode. Choose one of "repeat only", "repeat & increment", or "increment only".');
                    end
                
                    allSeeds(i) = seed;
                end
                
                obj.permutationseed = mod(round(now*1e4),2^30);
                stream = RandStream('twister', 'Seed', obj.permutationseed); %seed should change every min or so
                permutationIndices = randperm(stream, length(allBetas));
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

            % Built over the RandStream handle rather than obj so the handle
            % stays serializable (see createPresentation).
            stream = obj.noiseStream;
            switch obj.colorNoiseDistribution
                case 'uniform'
                    obj.noiseFn = @() 2 * stream.rand() - 1; % Uniform from [-1, 1]
                case 'gaussian'
                    obj.noiseFn = @() sa_labs.util.randn(stream); % Gaussian noise
                case 'binary'
                    obj.noiseFn = @() 2 * (stream.rand() > .5) - 1; % Binary {+1, -1}
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
            % The controller closure is serialized to the Stage server: it
            % captures plain values only, never obj or a nested function
            % (which shares this workspace and drags obj along). The 1/f
            % series is a deterministic function of the seed, so it is
            % generated once here instead of on every noise update; the
            % values are identical. Per-frame logic is in the package function
            % sa_labs.controllers.Temporal_Noise_1_f_noiseIntensity.
            frameDwell = obj.frameDwell;
            spotMeanLevel = obj.spotMeanLevel;
            noise_series = sa_labs.protocols.stage.Temporal_Noise_1_f.generateOneOverFNoise( ...
                obj.noiseSeed, obj.beta, spotMeanLevel, obj.contrast, frameDwell, frame_rate, stimFrames);
            spotIntensityController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                @(state) sa_labs.controllers.Temporal_Noise_1_f_noiseIntensity( ...
                state.frame - preFrames, stimFrames, frameDwell, spotMeanLevel, noise_series));
            p.addController(spotIntensityController);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochsPerBeta * length(obj.betas);
        end
    end

    methods (Static)
        % Protocol-side precompute of the 1/f noise series, called from
        % createPresentation (never from a controller closure, so it may
        % stay a class method). The per-frame controller logic is in the
        % package functions sa_labs.controllers.Temporal_Noise_1_f_noiseIntensity
        % and Temporal_Noise_1_f_clipIntensity.

        function noise_intensity = generateOneOverFNoise(noiseSeed, beta, spotMeanLevel, contrast, frameDwell, frame_rate, stimFrames)
            stream = RandStream('mt19937ar', 'Seed', noiseSeed);
            % Generate 1/f^beta noise in the frequency domain
            freqs = linspace(0, frame_rate/2, floor(stimFrames/2) + 1);
            amplitudes = zeros(size(freqs));
            amplitudes(2:end) = freqs(2:end) .^ (-beta / 2); % Avoid divide by zero

            % Generate random phases
            phases = exp(1i * 2 * pi *  rand(stream, 1, length(freqs)));

            % Construct spectrum
            spectrum = amplitudes .* phases;

            % Convert back to time domain. The mirrored half must give exactly
            % stimFrames samples: for odd stimFrames the Nyquist bin is absent,
            % so mirror from the last bin (the old form was one sample short
            % and indexed out of range for odd frame counts).
            if mod(stimFrames, 2) == 0
                fullSpectrum = [spectrum, conj(spectrum(end-1:-1:2))];
            else
                fullSpectrum = [spectrum, conj(spectrum(end:-1:2))];
            end
            raw_noise = real(ifft(fullSpectrum));
            raw_noise = raw_noise(1:stimFrames); % Ensure correct length
            raw_noise = raw_noise / std(raw_noise,1); % Normalize to unit variance

            % Apply contrast scaling
            noise_intensity_adj = spotMeanLevel * (1 + contrast * raw_noise);
            noise_intensity = repelem(noise_intensity_adj, frameDwell);
        end
    end
end
