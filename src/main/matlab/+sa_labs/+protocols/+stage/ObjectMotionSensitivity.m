classdef ObjectMotionSensitivity < sa_labs.protocols.StageProtocol
    
    
    properties
        %times in ms
        preTime = 1000;
        tailTime = 0;
        stimTime = 20000;
        
        intensity = 0.5;
        contrast = 1; % percentage around the mean
        
        motionAngle = 0;
        
        centerDiameter = 200;
        patternMode = 'grating'; % grating only for now
        patternDimension = 40; % µm, spatial scale
        gratingProfile = 'square'; %sine, square, or sawtooth
        
        figureBackgroundMode = 'aperture'; % use standard aperture or an actual moving object
        
        motionMode = 'random walk';
        
        motionSeedChangeModeCenter = 'increment only';
        motionStandardDeviationCenter = 400; % µm std or random walk or single step
        motionLowpassFilterPassbandCenter = 5; % Hz
        
        motionSeedModeSurround = 'same';
        motionStandardDeviationSurround = 400; % µm std or random walk step
        motionLowpassFilterPassbandSurround = 5; % Hz
        
        numberOfCycles = 3;
        numberOfEpochs = 20;
        
        resScaleFactor = 2; % factor to decrease computational load generating images
    end
    
    properties (Hidden)
        version = 1
        
        motionModeType = symphonyui.core.PropertyType('char','row',{'filtered noise','random walk','single step'});
        
        figureBackgroundModeType = symphonyui.core.PropertyType('char','row',{'aperture','object'});
        
        motionPathCenter
        motionSeedCenter
        motionFilterCenter
        motionSeedChangeModeCenterType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        
        motionPathSurround
        motionSeedSurround
        motionFilterSurround
        motionSeedModeSurroundType = symphonyui.core.PropertyType('char', 'row', {'same','offset','random'})
        
        patternModeType = symphonyui.core.PropertyType('char', 'row', {'grating','texture'});
        gratingProfileType = symphonyui.core.PropertyType('char', 'row', {'sine', 'square', 'sawtooth'});
        uniformDistribution = 1;
        
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'motionSeedCenter';
        
        patternSize = 1000;
        imageMatrixCenter
        imageMatrixSurround
    end
    
    
    properties (Hidden, Dependent)
        totalNumEpochs
        
    end
    
    methods
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case {'motionSeed','motionStandardDeviation','motionLowpassFilterPassband','motionLowpassFilterStopband'}
                    d.category = '5 Random Motion';
            end
            
        end
        
        function prepareRun(obj)
            
            % Call the base method.
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            
            % create the motion filters
            frameRate = 60;
            obj.motionFilterCenter = designfilt('lowpassfir','PassbandFrequency',obj.motionLowpassFilterPassbandCenter,...
                'StopbandFrequency',obj.motionLowpassFilterPassbandCenter*1.2,'SampleRate',frameRate);
            
            obj.motionFilterSurround = designfilt('lowpassfir','PassbandFrequency',obj.motionLowpassFilterPassbandSurround,...
                'StopbandFrequency',obj.motionLowpassFilterPassbandSurround*1.2,'SampleRate',frameRate);
            
        end
        
        function prepareEpoch(obj, epoch)
            
            % Select a center motion seeds
            if strcmp(obj.motionSeedChangeModeCenter, 'repeat only')
                seed = obj.motionSeedStart;
            elseif strcmp(obj.motionSeedChangeModeCenter, 'increment only')
                seed = obj.numEpochsCompleted + obj.motionSeedStart;
            else
                seedIndex = mod(obj.numEpochsCompleted,2);
                if seedIndex == 0
                    seed = obj.motionSeedStart;
                elseif seedIndex == 1
                    seed = obj.motionSeedStart + (obj.numEpochsCompleted + 1) / 2;
                end
            end
            obj.motionSeedCenter = seed;
            
            % make a surround motion seed
            switch obj.motionSeedModeSurround
                case 'same'
                    obj.motionSeedSurround = seed;
                case 'offset'
                    obj.motionSeedSurround = seed + 10;
                case 'random'
                    obj.motionSeedSurround = randi(1e4,1);
            end
            
            epoch.addParameter('motionSeedCenter', obj.motionSeedCenter);
            epoch.addParameter('motionSeedSurround', obj.motionSeedSurround);
            
            fprintf('Using seeds %g, %g\n', obj.motionSeedCenter, obj.motionSeedSurround);
            
            
            frameRate = 60;
            pathLength = round((obj.stimTime + obj.preTime)/1000 * frameRate + 100);
            switch obj.motionMode
                case 'single step'
                    % use mod to alternate which region makes step
                    if mod(obj.motionSeedCenter, 2) == 0
                        mpathc = zeros(pathLength,1);
                    else
                        mpathc = zeros(pathLength,1);
                        % shift motionStandardDeviationCenter after half
                        % stim length
                        changeFrame = round(obj.stimTime / 2 / 1000 * 60);
                        mpathc(changeFrame:end) = obj.motionStandardDeviationCenter;
                    end
                        
                    obj.motionPathCenter = mpathc;
                    
                    if mod(obj.motionSeedSurround, 2) == 0
                        mpaths = zeros(pathLength,1);
                    else
                        mpaths = zeros(pathLength,1);
                        % shift motionStandardDeviationSurround after half
                        % stim length
                        changeFrame = round(obj.stimTime / 2 / 1000 * 60);
                        mpaths(changeFrame:end) = obj.motionStandardDeviationSurround;
                    end
                        
                    obj.motionPathSurround = mpaths;                    
                        
                case 'filtered noise'
                    stream = RandStream('mt19937ar', 'Seed', obj.motionSeedCenter);
                    mpathc = obj.motionStandardDeviationCenter .* stream.randn(pathLength, 1);
                    obj.motionPathCenter = filtfilt(obj.motionFilterCenter, mpathc);
                    
                    stream = RandStream('mt19937ar', 'Seed', obj.motionSeedSurround);
                    mpaths = obj.motionStandardDeviationSurround .* stream.randn(pathLength, 1);
                    obj.motionPathSurround = filtfilt(obj.motionFilterSurround, mpaths);
                    
                case 'random walk'
                    stream = RandStream('mt19937ar', 'Seed', obj.motionSeedCenter);
                    mpathc = zeros(pathLength,1);
                    for i = 2:pathLength
                        if stream.rand(1) > 0.5
                            step = 1;
                        else
                            step = -1;
                        end
                        mpathc(i) = mpathc(i-1) + step * obj.motionStandardDeviationCenter;
                    end
                    obj.motionPathCenter = mpathc;
                    
                    stream = RandStream('mt19937ar', 'Seed', obj.motionSeedSurround);
                    mpaths = zeros(pathLength,1);
                    for i = 2:pathLength
                        if stream.rand(1) > 0.5
                            step = 1;
                        else
                            step = -1;
                        end
                        mpaths(i) = mpaths(i-1) + step * obj.motionStandardDeviationSurround;
                    end
                    obj.motionPathSurround = mpaths;
                    
                    
            end
            
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            
            % Create image matrices
            for csi = 1:2 % center surround index
                if strcmp(obj.patternModeType, 'grating')

                    x = linspace(0, 1, obj.patternSize);
                    y = cos(x ./ obj.patternDimension) * 0.5 * obj.contrast + obj.meanLevel; % to fix
                    M = repmat(y, [obj.patternSize, 1]);
                    
                    switch obj.gratingProfile
                        case 'square'
                            M = (M > 0) * 0.5 * obj.contrast + obj.meanLevel; % to fix
                    end

                else
                    % generate texture
                    sigma = obj.um2pix(0.5 * obj.patternDimension / obj.resScaleFactor);
                    res = round(obj.patternSize / obj.resScaleFactor);

                    fprintf('making texture (%d x %d) with blur sigma %d pixels\n', res(1), res(2), sigma);

                    patternStream = RandStream('mt19937ar','Seed',obj.randomSeed);

                    M = randn(patternStream, res);
                    defaultSize = 2*ceil(2*sigma)+1;
                    M = imgaussfilt(M, sigma, 'FilterDomain','frequency','FilterSize',defaultSize*2+1);

                    %             figure(99)
                    %             subplot(2,1,1)
                    %             imagesc(M)
                    %             caxis([-.1,.1])
                    % %             caxis([min(M(:)), max(M(:))/2])
                    %             colormap gray

                    if obj.uniformDistribution
                        bins = [-Inf prctile(M(:),1:1:100)];
                        M_orig = M;
                        for i=1:length(bins)-1
                            M(M_orig>bins(i) & M_orig<=bins(i+1)) = i*(1/(length(bins)-1));
                        end
                        M = M - min(M(:)); %set mins to 0
                        M = M./max(M(:)); %set max to 1;
                        M = M - mean(M(:)) + 0.5; %set mean to 0.5;
                    else % normal distribution
                        M = zscore(M(:)) * 0.3 + 0.5;
                        M = reshape(M, res);
                        M(M < 0) = 0;
                        M(M > 1) = 1;
                    end
                end
            
                if csi == 1
                    obj.imageMatrixCenter = uint8(255 * M);
                else
                    obj.imageMatrixSurround = uint8(255 * M);
                end
            end
            
            disp('done');
            
            % create objects to hold images
            patternSurround = stage.builtin.stimuli.Image(obj.imageMatrixSurround);
            patternSurround.orientation = obj.motionAngle + 90;
            patternSurround.size = fliplr(size(obj.imageMatrixSurround)) * obj.resScaleFactor;
            p.addStimulus(patternSurround);
            
            patternCenter = stage.builtin.stimuli.Image(obj.imageMatrixCenter);
            patternCenter.orientation = obj.motionAngle + 90;
            patternCenter.size = fliplr(size(obj.imageMatrixCenter)) * obj.resScaleFactor;
            p.addStimulus(patternCenter);
            
            % mask center pattern to a circle
            apertureDiameterRel = obj.centerDiameter / max(obj.patternSize);
            centerMask = stage.core.Mask.createAnnulus(-1, apertureDiameterRel, 2048);
            patternCenter.setMask(centerMask);
                        
            function im = imageMovementController(state, imageMatrix, scale, motionPath)
                if state.frame < 1
                    frame = 1;
                else
                    frame = state.frame;
                end
                
                pos = motionPath(frame);
                
                im = circshift(imageMatrix, pos * scale, 2); % second dim?
            end
            
            
            % Motion controllers
            motionScale = 10;
            controllerCenter = stage.builtin.controllers.PropertyController(patternCenter, ...
                'imageMatrix', @(s)imageMovementController(s, obj.imageMatrixCenter, motionScale, obj.motionPathCenter));
            p.addController(controllerCenter);
            
            controllerSurround = stage.builtin.controllers.PropertyController(patternCenter, ...
                'imageMatrix', @(s)imageMovementController(s, obj.imageMatrixSurround, motionScale, obj.motionPathSurround));
            p.addController(controllerSurround);
            
            
            
            obj.setOnDuringStimController(p, patternCenter);
            obj.setOnDuringStimController(p, patternSurround);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            
            totalNumEpochs = obj.numberOfCycles * obj.numberOfEpochs;
            
        end
        
        
    end
    
end