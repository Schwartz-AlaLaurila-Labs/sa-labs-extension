classdef TemporalNoise < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500 % ms
        stimTime = 30000 % ms
        tailTime = 500 % ms
        
        contrast = .25 % weber contrast
        spotMeanLevel = 0.1 % Mean intensity of the light spot

        aperture = 2000 % um diameter
        
        frameDwellMode = 'Shuffle' % Mode to select frame dwell ('Shuffle' or 'Constant')
        constantFrameDwell = 1 % User-defined constant frame dwell
        frameDwells = [2, 4, 8, 15] % Set of frame dwells for shuffle mode
        seedStartValue = 1
        seedChangeMode = 'increment only';
        colorNoiseMode = '1 pattern';
        colorNoiseDistribution = 'gaussian'
        
        numberOfEpochsPerFrameDwell = uint16(30) % Number of epochs for each frame dwell
    end    
    
    properties (Hidden)
        version = 1;
        
        frameDwellModeType = symphonyui.core.PropertyType('char', 'row', {'Shuffle', 'Constant'})
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        colorNoiseModeType = symphonyui.core.PropertyType('char', 'row', {'1 pattern', '2 patterns'})
        colorNoiseDistributionType = symphonyui.core.PropertyType('char', 'row', {'uniform', 'gaussian', 'binary'})
        frameDwell
        noiseSeed
        noiseStream
        
        noiseFn
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'noiseSeed';
        
        permutedFrameDwells
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
        
        function prepareRun(obj)
            % Call the superclass's prepareRun method
            prepareRun@sa_labs.protocols.StageProtocol(obj);

            % Handle frame dwell mode selection
            if strcmp(obj.frameDwellMode, 'Shuffle')
                % Step 1: Create all frame dwells
                allFrameDwells = repelem(obj.frameDwells, obj.numberOfEpochsPerFrameDwell); 

                % Step 2: Create allSeeds according to the seed change mode
                allSeeds = zeros(size(allFrameDwells));
                for i = 1:length(allFrameDwells)
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
                permutationIndices = randperm(stream, length(allFrameDwells)); % One permutation for both

                % Apply the same permutation to both frame dwells and seeds
                obj.permutedFrameDwells = allFrameDwells(permutationIndices);
                obj.permutedSeeds = allSeeds(permutationIndices);

            elseif strcmp(obj.frameDwellMode, 'Constant')
                % Constant mode: Use a single frame dwell for all epochs
                if isempty(obj.constantFrameDwell)
                    error('Constant frame dwell must be specified as a non-empty scalar.');
                end
            else
                error('Invalid frame dwell mode. Choose either "Shuffle" or "Constant".');
            end
        end


        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            % Get the current epoch index (since MATLAB is 1-indexed)
            currentEpochIndex = obj.numEpochsCompleted + 1;

            % Select frame dwell and seed from the precomputed lists
            obj.frameDwell = obj.permutedFrameDwells(currentEpochIndex);
            obj.noiseSeed = obj.permutedSeeds(currentEpochIndex);

            % Print the frame dwell and seed for the current epoch
            fprintf('Epoch %d: Frame dwell = %d, Seed = %d\n', currentEpochIndex, obj.frameDwell, obj.noiseSeed);

            % Track parameters for this epoch
            epoch.addParameter('frameDwell', obj.frameDwell); 
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
                    intensity = clipIntensity(intensity, obj.spotMeanLevel);
                else
                    if mod(frame, obj.frameDwell) == 0
                        intensity = obj.spotMeanLevel + obj.spotMeanLevel * obj.contrast * obj.noiseFn();
                        intensity = clipIntensity(intensity, obj.spotMeanLevel);
                    end
                end
                i = intensity;
            end
            
            function intensity = clipIntensity(intensity, mn)
                intensity(intensity > mn * 2) = mn * 2;
                intensity(intensity < 0) = 0;
                intensity(intensity > 1) = 1;
            end
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochsPerFrameDwell * length(obj.frameDwells);
        end
    end
end
