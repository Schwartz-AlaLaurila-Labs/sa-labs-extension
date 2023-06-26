classdef SpatialNoise < sa_labs.protocols.StageProtocol
    
    %TODO: trial length should be in frames, not ms?
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
        contrast = 1; % max. of 1

        frameDwell = 1 % Duration of each pattern in frames
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

            for ci = 1:4
                ampName = obj.(['chan' num2str(ci)]);
                ampMode = obj.(['chan' num2str(ci) 'Mode']);
                if ~(strcmp(ampName, 'None') || strcmp(ampMode, 'Off'));
                    device = obj.rig.getDevice(ampName);    
                    obj.showFigure(sprintf('sa_labs.figures.SpatialNoiseFigure%d', ci), device, ampMode, ...
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

            switch obj.colorNoiseDistribution
                case 'uniform'
                    obj.noiseFn = @(x) 2 * obj.noiseStream.rand(x) - 1;
                case 'gaussian'
                    obj.noiseFn = @(x) obj.noiseStream.randn(x);
                case 'binary'
                    obj.noiseFn = @(x) 2 * (obj.noiseStream.rand(x) > .5) - 1;
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
            % dimensions are swapped correctly
            if strcmp(obj.colorNoiseMode, '1 pattern')
                checkerboardImageController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                    @(state)getImageMatrix(obj, state.frame - preFrames, [obj.resolutionY, obj.resolutionX]));
            else
                % 2 pattern controller:
                checkerboardImageController = stage.builtin.controllers.PropertyController(checkerboard, 'imageMatrix',...
                @(state)getImageMatrix2Pattern(obj, state.frame - preFrames, state.pattern + 1, [obj.resolutionY, obj.resolutionX]));
            end
            p.addController(checkerboardImageController);

            if (obj.subsampleX ~= 1) || ((obj.subsampleY ~= 1))
                offsetController = stage.builtin.controllers.PropertyController(checkerboard,'position',...
                    @(state) getPosition(obj, state.frame - preFrames, state.pattern));
                p.addController(offsetController);
            end
            
            obj.setOnDuringStimController(p, checkerboard);

            %max offset should be the pixel width....
            ppm = 1./ obj.rig.getDevice('Stage').getConfigurationSetting('micronsPerPixel');
    
            ss = double([obj.subsampleX, obj.subsampleY]);
            pFactor = [obj.sizeX ./ obj.resolutionX ./ ss(1), obj.sizeY ./ obj.resolutionY ./ ss(2)];


            function p = getPosition(obj, frame, pattern)
                persistent position;
                if frame<0 %pre frames. frame 0 starts stimPts
                    position = canvasSize/2;
                elseif pattern == 0 %only want to move once per update?
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        % position = canvasSize/2 + ppm*...
                        %     (obj.offsetDelta * obj.offsetStream.randi(2*obj.maxOffset/obj.offsetDelta - 1,1,2) - obj.maxOffset);

                        position = canvasSize/2 + ppm.*pFactor.*[obj.offsetStream.randi(2*ss(1) - 1) - ss(1), obj.offsetStream.randi(2*ss(2) - 1) - ss(2)];
                    end
                end
                p = position;
            end
            
            % TODO: verify X vs Y in matrix
            
            function i = getImageMatrix(obj, frame, dimensions)
                persistent intensity;
                if frame < 0 %pre frames. frame 0 starts stimPts
                    intensity = obj.meanLevel;
                    intensity = clipIntensity(intensity, obj.meanLevel);
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity = obj.meanLevel + ... 
                            obj.contrast * obj.meanLevel * obj.noiseFn(dimensions);
                        intensity = clipIntensity(intensity, obj.meanLevel);
                    end
                end
%                 intensity = imgaussfilt(intensity, 1);
                i = intensity;
            end
                       
            
            function i = getImageMatrix2Pattern(obj, frame, pattern, dimensions)
                persistent intensity;
                if isempty(intensity)
                    intensity = cell(2,1);
                end
                if pattern == 1
                    mn = obj.meanLevel1;
                    c = obj.contrast1;
                else
                    mn = obj.meanLevel2;
                    c = obj.contrast2;
                end
                
                if frame<0 %pre frames. frame 0 starts stimPts
                    intensity{pattern} = mn;                    
                    intensity{pattern} = clipIntensity(intensity{pattern}, mn);
                else %in stim frames
                    if mod(frame, obj.frameDwell) == 0 %noise update
                        intensity{pattern} = mn + c * mn * obj.noiseFn(dimensions);                        
                        intensity{pattern} = clipIntensity(intensity{pattern}, mn);
                    end
                end
          
                i = intensity{pattern};
            end

            
            function intensity = clipIntensity(intensity, mn)
                intensity(intensity < 0) = 0;
                intensity(intensity > mn * 2) = mn * 2;
                intensity(intensity > 1) = 1;
                intensity = uint8(255 * intensity);
            end

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