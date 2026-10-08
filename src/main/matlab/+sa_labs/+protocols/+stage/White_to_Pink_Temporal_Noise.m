classdef White_to_Pink_Temporal_Noise < sa_labs.protocols.StageProtocol
    % Presents a spot with temporal noise (1/f^beta) that transitions to a
    % second arrangement after a predefined time. 
    %
    % This protocol can be used to study:
    %   - Adaptation to temporal statistics (switching from beta = 0 (WN) to beta = 1 (pink noise))
    %   - Contrast adaptation (contrast1 = low contrast, contrast2 = high contrast)
    %
    properties
        % Timing parameters (milliseconds)
        preTime = 500   % Pre-stimulus period (constant intensity)
        time1 = 3000    % First segment duration (ms)
        time2 = 10000   % Second segment duration (ms)
        tailTime = 500  % Post-stimulus period (constant intensity)

        % Noise parameters
        stimContrast1  = .36 % Contrast for first noise segment
        stimContrast2 = .36 % Contrast for second noise segment
        beta1 = 0       % Spectral slope of first noise segment (0 = white noise)
        beta2 = 1       % Spectral slope of second noise segment (1 = pink noise)
        spotMeanLevel = 0.15 % Mean intensity of the light spot

        % Stimulus properties
        aperture = 2000  % Spot diameter in microns
        frameDwell = 1   % Number of frames before updating the noise

        % Seed control
        seedStartValue = 1 % Initial noise seed
        seedChangeMode = 'increment only';
        numberOfEpochs = uint16(30) % Number of epochs to queue
    end    

    properties (Hidden)
        version = 1;
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        noiseSeed
        noiseStream
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'noiseSeed';
    end

    properties (Dependent)
        totalNumEpochs
        stimTime
    end
    
    methods
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
            % Set seed based on change mode
            if strcmp(obj.seedChangeMode, 'repeat only')
                obj.noiseSeed = obj.seedStartValue;
            elseif strcmp(obj.seedChangeMode, 'increment only')
                obj.noiseSeed = obj.numEpochsCompleted + obj.seedStartValue;
            else
                % Repeat first seed every 3rd epoch
                if mod(obj.numEpochsCompleted, 3) == 2
                    obj.noiseSeed = obj.seedStartValue;
                else
                    obj.noiseSeed = obj.seedStartValue + obj.numEpochsCompleted;
                end
            end
            
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            preFrames = round(obj.frameRate * (obj.preTime / 1e3));
            tailFrames = round(obj.frameRate * (obj.tailTime/1e3));
            stimFrames1 = round(obj.frameRate * (obj.time1 / 1e3));
            stimFrames2 = round(obj.frameRate * (obj.time2 / 1e3));
            frame_rate = round(obj.frameRate);

            % Generate noise sequences
            noise1 = generateOneOverFNoise(obj, frame_rate, stimFrames1, obj.beta1, obj.stimContrast1 , obj.noiseSeed);
            noise2 = generateOneOverFNoise(obj, frame_rate, stimFrames2, obj.beta2, obj.stimContrast2, obj.noiseSeed + 500); % Ensure independent noise
            noise1_pre_tail = generateOneOverFNoise(obj, obj.frameRate, preFrames + tailFrames, obj.beta1, obj.stimContrast1, obj.noiseSeed + 200);

            % Concatenate noise segments for future slicing
            stimNoise = [noise1_pre_tail, noise1, noise2, noise1_pre_tail];


            % Create spot stimulus
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.aperture / 2));
            spot.radiusY = spot.radiusX;
            spot.position = canvasSize / 2;
            spot.opacity = 1;
            
            p.addStimulus(spot);
            
            % Add intensity controller
            % The controller closure is serialized to the Stage server: it
            % captures plain values only, never obj or a nested function
            % (which shares this workspace and drags obj along). Per-frame
            % logic is in the package function
            % sa_labs.controllers.White_to_Pink_Temporal_Noise_noiseIntensity.
            spotMeanLevel = obj.spotMeanLevel;
            spotIntensityController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                @(state) sa_labs.controllers.White_to_Pink_Temporal_Noise_noiseIntensity( ...
                state.frame, preFrames, stimFrames1, stimFrames2, stimNoise, spotMeanLevel));
            p.addController(spotIntensityController);
        end
        
        
        function noise_intensity = generateOneOverFNoise(obj, frame_rate, stimFrames, beta, contrast, noiseSeed)
            stream = RandStream('mt19937ar', 'Seed', noiseSeed);
            freqs = linspace(0, frame_rate / 2, floor(stimFrames / 2) + 1);
            
            % Apply spectral shaping
            amplitudes = zeros(size(freqs));
            amplitudes(2:end) = freqs(2:end) .^ (-beta / 2);
            
            % Generate random phases
            phases = exp(1i * 2 * pi * rand(stream, 1, length(freqs)));
            
            % Convert noise from frequency to time domain
            spectrum = amplitudes .* phases;
            % The mirrored half must give exactly stimFrames samples: for odd
            % stimFrames the Nyquist bin is absent, so mirror from the last bin
            % (the old form was one sample short and indexed out of range).
            if mod(stimFrames, 2) == 0
                fullSpectrum = [spectrum, conj(spectrum(end-1:-1:2))];
            else
                fullSpectrum = [spectrum, conj(spectrum(end:-1:2))];
            end
            raw_noise = real(ifft(fullSpectrum));
            raw_noise = raw_noise(1:stimFrames);
            raw_noise = raw_noise / std(raw_noise, 1);

            % Apply contrast scaling
            noise_intensity_adj = obj.spotMeanLevel * (1 + contrast * raw_noise);
            noise_intensity = repelem(noise_intensity_adj, obj.frameDwell);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs; 
        end

        function stimTime = get.stimTime(obj)
            stimTime = obj.time1 + obj.time2;
        end
    end

end
