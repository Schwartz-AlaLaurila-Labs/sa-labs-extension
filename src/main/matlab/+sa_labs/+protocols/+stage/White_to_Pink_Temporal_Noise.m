classdef White_to_Pink_Temporal_Noise < sa_labs.protocols.StageProtocol
    properties
        % Timing parameters (milliseconds)
        preTime = 500;    
        time1 = 3000;     
        time2 = 10000;    
        tailTime = 500;   

        % Noise parameters
        stimContrast1 = 0.36; 
        stimContrast2 = 0.36; 
        beta1 = 0;       
        beta2 = 1;       
        spotMeanLevel = 0.15; 

        % Stimulus properties
        aperture = 2000;  
        frameDwell = 1;   

        % Seed control
        seedStartValue = 1; 
        seedChangeMode = 'increment only';
        numberOfEpochs = uint16(30);
    end    

    properties (Hidden)
        version = 1;
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'});
        noiseSeed;
        noiseStream;
        stimNoise;
    end

    methods
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);

            % Define frame parameters
            frame_rate = round(obj.frameRate);
            stimFrames1 = round(frame_rate * (obj.time1 / 1e3));
            stimFrames2 = round(frame_rate * (obj.time2 / 1e3));
            preFrames = round(frame_rate * (obj.preTime / 1e3));
            tailFrames = round(frame_rate * (obj.tailTime / 1e3));

            % Generate noise sequences
            obj.stimNoise = [ ...
                obj.generateOneOverFNoise(frame_rate, preFrames + tailFrames, obj.beta1, obj.stimContrast1, obj.seedStartValue + 200), ...
                obj.generateOneOverFNoise(frame_rate, stimFrames1, obj.beta1, obj.stimContrast1, obj.seedStartValue), ...
                obj.generateOneOverFNoise(frame_rate, stimFrames2, obj.beta2, obj.stimContrast2, obj.seedStartValue + 500), ...
                obj.generateOneOverFNoise(frame_rate, preFrames + tailFrames, obj.beta1, obj.stimContrast1, obj.seedStartValue + 200) ...
            ];

            disp('Noise sequences generated successfully.');
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);

            % Update noise seed based on change mode
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
            p = stage.core.Presentation((obj.preTime + obj.time1 + obj.time2 + obj.tailTime) * 1e-3);

            % Create spot stimulus
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.aperture / 2));
            spot.radiusY = spot.radiusX;
            spot.position = canvasSize / 2;
            p.addStimulus(spot);

            % Add intensity controller
            spotIntensityController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                @(state) obj.getIntensity(state.frame));
            p.addController(spotIntensityController);
        end

        function intensity = getIntensity(obj, frame)
            frame_rate = round(obj.frameRate);
            stimFrames1 = round(frame_rate * (obj.time1 / 1e3));
            stimFrames2 = round(frame_rate * (obj.time2 / 1e3));
            preFrames = round(frame_rate * (obj.preTime / 1e3));

            if frame < preFrames  
                intensity = obj.spotMeanLevel;
            elseif frame < (preFrames + stimFrames1)  
                stimFrame = frame - preFrames + 1;
                intensity = obj.stimNoise(preFrames + stimFrame);
            elseif frame < (preFrames + stimFrames1 + stimFrames2)  
                stimFrame = frame - preFrames - stimFrames1 + 1;
                intensity = obj.stimNoise(preFrames + stimFrames1 + stimFrame);
            else  
                intensity = obj.spotMeanLevel;
            end

            intensity = obj.clipIntensity(intensity);
        end

        function intensity = clipIntensity(~, intensity)
            intensity = min(max(intensity, 0), 1); 
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
            raw_noise = real(ifft([spectrum, conj(spectrum(end-1:-1:2))]));
            raw_noise = raw_noise(1:stimFrames);
            std_noise = std(raw_noise, 1);
            if std_noise == 0
                std_noise = 1;
            end
            raw_noise = raw_noise / std_noise;

            noise_intensity_adj = obj.spotMeanLevel * (1 + contrast * raw_noise);
            noise_intensity = repelem(noise_intensity_adj, obj.frameDwell);
        end
    end
end
