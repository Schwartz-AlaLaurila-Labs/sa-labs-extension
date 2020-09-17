classdef ObjectMotionSensitivity < sa_labs.protocols.StageProtocol
    
    
    properties
        %times in ms
        preTime = 500;
        tailTime = 500;
        stimTime = 4000;
        startMotionTime = 1000;
        
        intensity = 0.5;
        contrast = 1; % change around the mean
        
        motionAngle = 0;
        
        motionIncludeCenter = true; % 1
        motionIncludeSurround = true; % 2
        motionIncludeGlobal = true; % 3
        motionIncludeDifferential = true; % 4
        motionIncludeStatic = true; % 5
        
        figureBackgroundMode = 'aperture'; % use standard aperture or an actual moving object
        
        motionPathMode = 'random walk';
        motionSeedStart = 1;
        motionCenterDelayFrames = 0;
        
        motionSeedChangeModeCenter = 'increment only';
        motionStandardDeviation = 1; % µm noise std, or random walk step, or contrast reverse step
        motionLowpassFilterPassband = 5;
        
        centerDiameter = 200; % µm
        annulusThickness = 0; % µm
        patternMode = 'grating'; %
        patternSpatialScale = 100; % µm, spatial scale
        gratingProfile = 'sine'; %sine, square, or sawtooth
        
        numberOfCycles = 5;
    end
    
    properties (Hidden)
        version = 4
        % v4: add center delay frames & annulus thickness
        
        motionPathModeType = symphonyui.core.PropertyType('char','row',{'filtered noise','random walk','contrast reverse'});
        
        motionModes
        motionModeNames = {'center','surround','global','differential','static'};
        curMotionMode
        numberOfMotionModes = 5;
        
        figureBackgroundModeType = symphonyui.core.PropertyType('char','row',{'aperture','object'});
        
        motionPathCenter
        motionSeedCenter
        motionFilter
        motionSeedChangeModeCenterType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        
        motionPathSurround
        motionSeedSurround
        
        patternModeType = symphonyui.core.PropertyType('char', 'row', {'grating','texture'});
        gratingProfileType = symphonyui.core.PropertyType('char', 'row', {'sine', 'square'});
        uniformDistribution = 1;
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'motionMode';
        
        patternSizeMicrons = [2000,2000];
        
        imageMatrixDimensions = [500,500];
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
            if strcmp(obj.motionPathMode, 'filtered noise')
                obj.motionFilter = designfilt('lowpassfir','PassbandFrequency',obj.motionLowpassFilterPassband,...
                    'StopbandFrequency',obj.motionLowpassFilterPassband*1.2,...
                    'FilterOrder', 20, 'SampleRate',frameRate);
            end
            
            % create the set of motion mode options
            obj.motionModes = [];
            if obj.motionIncludeCenter
                obj.motionModes = horzcat(obj.motionModes, 1);
            end
            if obj.motionIncludeSurround
                obj.motionModes = horzcat(obj.motionModes, 2);
            end
            if obj.motionIncludeGlobal
                obj.motionModes = horzcat(obj.motionModes, 3);
            end
            if obj.motionIncludeDifferential
                obj.motionModes = horzcat(obj.motionModes, 4);
            end
            if obj.motionIncludeStatic
                obj.motionModes = horzcat(obj.motionModes, 5);
            end
            obj.numberOfMotionModes = length(obj.motionModes);
            
            fprintf('enabled motion modes: ');
            disp(obj.motionModes)
            
        end
        
        function prepareEpoch(obj, epoch)
            % Randomize motion modes if this is a new set
            fprintf('epoch %g\n', obj.numEpochsPrepared)
            
            index = mod(obj.numEpochsPrepared, obj.numberOfMotionModes) + 1;
            if index == 1
                obj.motionModes = obj.motionModes(randperm(obj.numberOfMotionModes)); 
            end
            
            %get current epoch mode
            obj.curMotionMode = obj.motionModes(index);
            epoch.addParameter('motionMode', obj.curMotionMode);
            fprintf('current motion mode: %s\n', obj.motionModeNames{obj.curMotionMode});
            
            % Select a center motion seed (probably not correctly incrementing now)
            if strcmp(obj.motionSeedChangeModeCenter, 'repeat only')
                centerSeed = obj.motionSeedStart;
            elseif strcmp(obj.motionSeedChangeModeCenter, 'increment only')
                centerSeed = obj.numEpochsCompleted + obj.motionSeedStart;
            else
                seedIndex = mod(obj.numEpochsCompleted,2);
                if seedIndex == 0
                    centerSeed = obj.motionSeedStart;
                elseif seedIndex == 1
                    centerSeed = obj.motionSeedStart + (obj.numEpochsCompleted + 1) / 2;
                end
            end
            obj.motionSeedCenter = centerSeed;
            
            % make a surround motion seed
            switch obj.curMotionMode
                case 1 % center only
                    obj.motionSeedSurround = -1;
                case 2 % surround only
                    obj.motionSeedSurround = centerSeed;
                    obj.motionSeedCenter = -1;
                case 3 % global
                    obj.motionSeedSurround = centerSeed;
                case 4 % differential
                    obj.motionSeedSurround = centerSeed + 1;
                case 5 % static
                    obj.motionSeedCenter = -1;
                    obj.motionSeedSurround = -1;
            end
            
            epoch.addParameter('motionSeedCenter', obj.motionSeedCenter);
            epoch.addParameter('motionSeedSurround', obj.motionSeedSurround);
            
            fprintf('Using motion path seeds %g, %g (-1 is static)\n', obj.motionSeedCenter, obj.motionSeedSurround);
            
            
            frameRate = 60;
            pathLength = round((obj.stimTime + obj.preTime)/1000 * frameRate + 100);
            
            switch obj.motionPathMode
                case 'contrast reverse'
                    T = (0:(pathLength-1)) ./ frameRate;
                    stepInterval = 2.0; % sec
                    
                    obj.motionPathCenter = zeros(pathLength,1);
                    if obj.motionSeedCenter > 0
                        obj.motionPathCenter = obj.motionStandardDeviation * (sin(3.141 * T ./ stepInterval) > 0);
                    end
                    
                    obj.motionPathSurround = zeros(pathLength,1);
                    if obj.motionSeedSurround > 0
                        if obj.curMotionMode ~= 4
                            obj.motionPathSurround = obj.motionStandardDeviation * (sin(3.141 * T ./ stepInterval) > 0);
                        else % differential mode offset steps by half of stepInterval
                            obj.motionPathSurround = obj.motionStandardDeviation * (sin(3.141 * (T - stepInterval/2) ./ stepInterval) > 0);
                        end
                    end
                    
                case 'filtered noise'
                    if obj.motionSeedCenter > 0
                        stream = RandStream('mt19937ar', 'Seed', obj.motionSeedCenter);
                        mpathc = obj.motionStandardDeviation .* stream.randn(pathLength, 1);
                        obj.motionPathCenter = filtfilt(obj.motionFilter, mpathc);
                    else
                        obj.motionPathCenter = zeros(pathLength, 1);
                    end
                    
                    if obj.motionSeedSurround > 0
                        stream = RandStream('mt19937ar', 'Seed', obj.motionSeedSurround);
                        mpaths = obj.motionStandardDeviation .* stream.randn(pathLength, 1);
                        obj.motionPathSurround = filtfilt(obj.motionFilter, mpaths);
                    else
                        obj.motionPathSurround = zeros(pathLength, 1);
                    end                        
                    
                case 'random walk'
                    if obj.motionSeedCenter > 0
                        stream = RandStream('mt19937ar', 'Seed', obj.motionSeedCenter);
                        mpathc = zeros(pathLength,1);
                        for i = 2:pathLength
                            if stream.rand(1) > 0.5
                                step = 1;
                            else
                                step = -1;
                            end
                            mpathc(i) = mpathc(i-1) + step * obj.motionStandardDeviation;
                        end
                        obj.motionPathCenter = mpathc;
                    else
                        obj.motionPathCenter = zeros(pathLength, 1);
                    end
                    
                    if obj.motionSeedSurround > 0
                        stream = RandStream('mt19937ar', 'Seed', obj.motionSeedSurround);
                        mpaths = zeros(pathLength,1);
                        for i = 2:pathLength
                            if stream.rand(1) > 0.5
                                step = 1;
                            else
                                step = -1;
                            end
                            mpaths(i) = mpaths(i-1) + step * obj.motionStandardDeviation;
                        end
                        obj.motionPathSurround = mpaths;
                    else
                        obj.motionPathSurround = zeros(pathLength, 1);
                    end                      
                    
            end

            % below I have some start position code, not sure what problem
            % it solves. Probably needs a better solution if the problem is
            % still around after disabling this
%             startCenter = mean([obj.motionPathCenter(1), obj.motionPathSurround(1)]);
%             obj.motionPathCenter(1) = startCenter;
%             obj.motionPathSurround(1) = startCenter;
            obj.motionPathCenter = obj.um2pix(obj.motionPathCenter);
            obj.motionPathSurround = obj.um2pix(obj.motionPathSurround);
                        
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            
            % Create image matrices
            for csi = 1:2 % center surround index
                if strcmp(obj.patternMode, 'grating')

                    x = linspace(0, obj.patternSizeMicrons(1), obj.imageMatrixDimensions(1)); %in µm
                    y = ((cos(x * 2 * 3.141 / obj.patternSpatialScale)) * obj.contrast + 1) * obj.meanLevel; % to fix
                    M = repmat(y, [obj.imageMatrixDimensions(2),1]);
                    
                    switch obj.gratingProfile
                        case 'square'
                            M(M>obj.meanLevel) = obj.meanLevel * (1+obj.contrast);
                            M(M<=obj.meanLevel) = obj.meanLevel * (1-obj.contrast);
                    end

                else
                    % generate texture
                    sigma = obj.patternSpatialScale / obj.patternSizeMicrons(1) * obj.imageMatrixDimensions(1);

                    fprintf('making texture (%d x %d) with blur sigma %d pixels\n', obj.imageMatrixDimensions(1), obj.imageMatrixDimensions(2), sigma);

                    patternStream = RandStream('mt19937ar','Seed',max(obj.motionSeedCenter, obj.motionSeedSurround));

                    M = randn(patternStream, obj.imageMatrixDimensions);
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
                        M = reshape(M, obj.imageMatrixDimensions);
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
            
            
            % create object to hold images for surround
            patternSurround = stage.builtin.stimuli.Image(obj.imageMatrixSurround);
            patternSurround.position = canvasSize / 2;
            patternSurround.orientation = obj.motionAngle;
            patternSurround.size = obj.um2pix(obj.patternSizeMicrons);
            p.addStimulus(patternSurround);

            % draw annulus circle
            if obj.annulusThickness > 0
                annulus = stage.builtin.stimuli.Ellipse();
                annulus.radiusX = round(obj.um2pix(obj.patternSizeMicrons / 2 + obj.annulusThickness));
                annulus.radiusY = annulus.radiusX;
                annulus.color = obj.meanLevel;
                annulus.position = canvasSize / 2;
                p.addStimulus(annulus);
            end
            
            % create object to hold images for center
            patternCenter = stage.builtin.stimuli.Image(obj.imageMatrixCenter);
            patternCenter.position = canvasSize / 2;
            patternCenter.orientation = obj.motionAngle;
            patternCenter.size = obj.um2pix(obj.patternSizeMicrons);
            p.addStimulus(patternCenter);
            
            % mask center pattern to a circle
            apertureDiameterRel = obj.centerDiameter / max(obj.patternSizeMicrons);
            centerMask = stage.core.Mask.createAnnulus(-1, apertureDiameterRel, 1024);
            patternCenter.setMask(centerMask);
            
            
            function im = imageMovementController(state, startMotionTime, imageMatrix, scale, motionPath, centerDelayFrames)
                if state.time < startMotionTime / 1000
                    frame = 1;
                else
                    frame = 1+round(state.frame - 60 * (startMotionTime / 1000)) + centerDelayFrames;
                end

                im = circshift(imageMatrix, round(motionPath(frame) * scale), 2); % second dim
            end

            function pos = objectMovementController(state, startMotionTime, center, angle, motionPathPixels, centerDelayFrames)

                if state.time < startMotionTime / 1000
                    frame = 1;
                else
                    frame = 1+round(state.frame - 60 * (startMotionTime / 1000)) + centerDelayFrames;
                end
                
                y = sind(angle) * motionPathPixels(frame);
                x = cosd(angle) * motionPathPixels(frame);
                pos = [x,y] + center;
                    
            end

            % Motion controllers
            
            % center
            motionScale = obj.imageMatrixDimensions(1) / obj.patternSizeMicrons(1); % convert image pixel shift to world um shift
            switch obj.figureBackgroundMode
                case 'aperture'
                    controllerCenter = stage.builtin.controllers.PropertyController(patternCenter, ...
                        'imageMatrix', @(s)imageMovementController(s, obj.startMotionTime+obj.preTime, obj.imageMatrixCenter, motionScale, obj.motionPathCenter, obj.motionCenterDelayFrames));
                case 'object'
                    motionPathPixels = obj.um2pix(obj.motionPathCenter);
                    controllerCenter = stage.builtin.controllers.PropertyController(patternCenter, ...
                        'position', @(s)objectMovementController(s, obj.startMotionTime+obj.preTime, canvasSize/2, obj.motionAngle, motionPathPixels, obj.motionCenterDelayFrames));
            end
            p.addController(controllerCenter);
            
            % annulus moves in center-object mode
            if obj.annulusThickness > 0 && strcmp(obj.figureBackgroundMode, 'object')
                motionPathPixels = obj.um2pix(obj.motionPathCenter);
                controllerAnnulus = stage.builtin.controllers.PropertyController(annulus, ...
                    'position', @(s)objectMovementController(s, obj.startMotionTime+obj.preTime, canvasSize/2, obj.motionAngle, motionPathPixels, obj.motionCenterDelayFrames));
                p.addController(controllerAnnulus);
            end
            
            % surround
            controllerSurround = stage.builtin.controllers.PropertyController(patternSurround, ...
                'imageMatrix', @(s)imageMovementController(s, obj.startMotionTime+obj.preTime, obj.imageMatrixSurround, motionScale, obj.motionPathSurround, 0));
            p.addController(controllerSurround);
            
            
            obj.setOnDuringStimController(p, patternCenter);
            if obj.annulusThickness > 0
                obj.setOnDuringStimController(p, annulus);
            end
            obj.setOnDuringStimController(p, patternSurround);

            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfMotionModes;
        end
                
        
    end
    
end