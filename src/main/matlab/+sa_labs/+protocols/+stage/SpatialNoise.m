classdef SpatialNoise < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500 % ms
        stimTime = 10000 % ms
        tailTime = 500 % ms
        
        resolutionX = 10 % number of stimulus segments
        resolutionY = 10 % number of stimulus segments
        sizeX = 1000 % um
        sizeY = 1000 % um
    end
    
    properties (Dependent)
        pixelWidth %um, the size of each checker in the checkerboard
        pixelHeight %um, the size of each checker in the checkerboard
    end
    
    properties
        contrast = 1;
        
        frameDwell = 1 % Frames per noise update, use only 1 when colorMode is 2 pattern
        seedStartValue = 1
        seedChangeMode = 'increment only';
        colorNoiseMode = '1 pattern';
        colorNoiseDistribution = 'binary'
        
        
        numberOfEpochs = uint16(30) % number of epochs to queue
        
        subsampleX = uint8(10) %number of steps to shift stimulus in X (min. 1)
        subsampleY = uint8(10) %number of steps to shift stimulus in X (min. 1)
        
        % offsetDelta = 0 %um
        % maxOffset = 100 %um
    end
    
    properties (Transient)
        subsampleT = uint8(10) %number of time steps per frame to use for display
        RFMemory = uint8(120) %total number of time steps to use for display
    end
    
    properties (Hidden)
        version = 1;
        
        seedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        locationModeType = symphonyui.core.PropertyType('char', 'row', {'Center', 'Surround', 'Center-Surround'})
        colorNoiseModeType = symphonyui.core.PropertyType('char', 'row', {'1 pattern', '2 patterns'})
        colorNoiseDistributionType = symphonyui.core.PropertyType('char', 'row', {'uniform', 'gaussian', 'binary'})
        
        noiseSeed
        noiseStream
        
        noiseFn
        
        offsetSeed
        offsetStream
        
        responsePlotMode = false;
        % responsePlotMode = 'cartesian';
        % responsePlotSplitParameter = 'noiseSeed';
    end
    
    properties (Dependent, Hidden)
        totalNumEpochs
    end
    
    methods
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if strcmp(obj.colorNoiseMode, '1 pattern')
                meanLevel_ = obj.meanLevel;
                contrast_ = obj.contrast;
            else
                meanLevel_ = [obj.meanLevel1, obj.meanLevel2];
                contrast_ = [obj.contrast1, obj.contrast2];
            end
            
            for ci = 1%:4
                ampName = obj.(['chan' num2str(ci)]);
                ampMode = obj.(['chan' num2str(ci) 'Mode']);
                if ~(strcmp(ampName, 'None') || strcmp(ampMode, 'Off'));
                    device = obj.rig.getDevice(ampName);
                    obj.showFigure('sa_labs.figures.SpatialNoiseFigure', device, ampMode, ...
                        'totalNumEpochs', obj.totalNumEpochs,...
                        'preTime', obj.preTime,...
                        'stimTime', obj.stimTime,...
                        'tailTime', obj.tailTime,...
                        'frameRate', obj.frameRate,...
                        'dimensions', [obj.resolutionX, obj.resolutionY],...
                        'extent', [obj.sizeX, obj.sizeY],...
                        'colorNoiseDistribution', obj.colorNoiseDistribution,...
                        'colorNoiseMode', obj.colorNoiseMode,...
                        'frameDwell', obj.frameDwell,...
                        'meanLevel', meanLevel_,...
                        'contrast', contrast_,...
                        'spatialSubsample', [obj.subsampleX, obj.subsampleY],...
                        'temporalSubsample', obj.subsampleT,...
                        'memory', obj.RFMemory,...
                        'spikeThreshold', obj.spikeThreshold, 'spikeDetectorMode', obj.spikeDetectorMode);
                end
            end
        end
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case {'contrast'}
                    if obj.numberOfPatterns > 1
                        d.isHidden = true;
                    end
            end
        end
        
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
            if strcmp(obj.seedChangeMode, 'repeat only')
                seed = obj.seedStartValue;
            elseif strcmp(obj.seedChangeMode, 'increment only')
                seed = obj.numEpochsCompleted + obj.seedStartValue;
            else
                seedIndex = mod(obj.numEpochsCompleted,2);
                if seedIndex == 0
                    seed = obj.seedStartValue;
                elseif seedIndex == 1
                    seed = obj.seedStartValue + (obj.numEpochsCompleted + 1) / 2;
                end
            end
            
            obj.noiseSeed = seed;
            obj.offsetSeed = 2^32 - seed;
            fprintf('Using seed %g\n', obj.noiseSeed);
            
            %at start of epoch, set random streams using this cycle's seeds
            obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.noiseSeed);
            obj.offsetStream = RandStream('mt19937ar', 'Seed', obj.offsetSeed);
            epoch.addParameter('noiseSeed', obj.noiseSeed);
            epoch.addParameter('offsetSeed', obj.offsetSeed);
            
            % noiseFn is captured by the image controller closure, which is
            % serialized to the Stage server: build it over the RandStream
            % handle itself (which serializes), never over obj.
            stream = obj.noiseStream;
            switch obj.colorNoiseDistribution
                case 'uniform'
                    obj.noiseFn = @(x) 2 * stream.rand(x) - 1;
                case 'gaussian'
                    obj.noiseFn = @(x) stream.randn(x);
                case 'binary'
                    obj.noiseFn = @(x) 2 * (stream.rand(x) > .5) - 1;
            end
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            preFrames = round(obj.frameRate * (obj.preTime/1e3));
            
            % create shapes
            % checkerboard is filled from top left (is 1,1)
            checkerboard = stage.builtin.stimuli.Image(uint8(zeros(obj.resolutionY, obj.resolutionX)));
            checkerboard.position = canvasSize / 2;
            checkerboard.size = obj.um2pix([obj.sizeX, obj.sizeY]);
            checkerboard.setMinFunction(GL.NEAREST);
            checkerboard.setMagFunction(GL.NEAREST);
            p.addStimulus(checkerboard);
            
            % add controllers
            % Controller closures are serialized to the Stage server: they
            % capture plain values and the RandStream handles only (never
            % obj, and no nested functions, which share this workspace and
            % drag obj along). Per-frame logic is in the package functions
            % sa_labs.controllers.SpatialNoise_noiseImage / _noiseImage2Pattern /
            % _noiseOffset; the noise comes from the same stream as before via
            % noiseFn, which prepareEpoch built over obj.noiseStream.
            dimensions = [obj.resolutionY, obj.resolutionX]; % dimensions are swapped correctly
            frameDwell = obj.frameDwell;
            noiseFn = obj.noiseFn;
            if strcmp(obj.colorNoiseMode, '1 pattern')
                meanLevel = obj.meanLevel;   %#ok<*PROP>
                contrast = obj.contrast;
                checkerboardImageController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                    @(state) sa_labs.controllers.SpatialNoise_noiseImage( ...
                    state.frame - preFrames, dimensions, frameDwell, meanLevel, contrast, noiseFn));
            else
                % 2 pattern controller:
                meanLevel1 = obj.meanLevel1;
                contrast1 = obj.contrast1;
                meanLevel2 = obj.meanLevel2;
                contrast2 = obj.contrast2;
                checkerboardImageController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                    @(state) sa_labs.controllers.SpatialNoise_noiseImage2Pattern( ...
                    state.frame - preFrames, state.pattern + 1, dimensions, frameDwell, meanLevel1, contrast1, meanLevel2, contrast2, noiseFn));
            end
            p.addController(checkerboardImageController);

            ppm = 1./ obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');

            ss = double([obj.subsampleX, obj.subsampleY]);
            pFactor = [obj.sizeX ./ obj.resolutionX ./ ss(1), obj.sizeY ./ obj.resolutionY ./ ss(2)];

            if (obj.subsampleX ~= 1) && ((obj.subsampleY ~= 1))
                offsetStream = obj.offsetStream;
                offsetController = stage.builtin.controllers.PropertyController(checkerboard,'position',...
                    @(state) sa_labs.controllers.SpatialNoise_noiseOffset( ...
                    state.frame - preFrames, state.pattern, canvasSize, frameDwell, ppm, pFactor, ss, offsetStream));
                p.addController(offsetController);
            end


            obj.setOnDuringStimController(p, checkerboard);

        end
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
        
        function pixelWidth = get.pixelWidth(obj)
            pixelWidth = obj.sizeX / obj.resolutionX;
        end
        
        
        function pixelWidth = get.pixelHeight(obj)
            pixelWidth = obj.sizeY / obj.resolutionY;
        end

    end

end