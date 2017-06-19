classdef DriftingTexture < sa_labs.protocols.StageProtocol
    
    
    properties
        %times in ms
        preTime = 250;
        tailTime = 250;
        stimTime = 5000;
        
        movementDelay = 200;
        
        %in microns, use rigConfig to set microns per pixel
        apertureDiameter = 0; %um
        textureScale = 60; %um
        speed = 1000; %um/s
        uniformDistribution = true;
        randomSeed = 1;
        singleDimension = false;
        chirpStart = false;
        singleAngle = -1; % set to a positive value to use a single fixed angle
        numberOfAngles = 12;       
        
        randomMotion = false;
        motionSeed = 1;
        motionLowpassFilterParams = [2,4];
        
        movementSensitivity = false;
        numberOfMovementSensitivitySteps = 5;
        movementSensitivityStepSize = 10; % um
        
        numberOfCycles = 2;
        
        resScaleFactor = 2; % factor to decrease computational load
    end
    
    properties (Hidden)
        version = 3 % add random motion
        curAngle
        angles
        imageMatrix
        moveDistance
        motionPath
        randomMotionDimensions = 1; % keep at 1, doesn't work yet
        sensitivitySteps
        curSensitivityStep = -1;
        
        responsePlotMode = 'polar';
        responsePlotSplitParameter = 'textureAngle';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);        
            
            switch name
                case {'randomMotion','motionSeed','motionLowpassFilterParams'}
                    d.category = '5 Random Motion';
                case {'movementSensitivity','numberOfMovementSensitivitySteps','movementSensitivityStepSize'}
                    d.category = '6 Motion Sensitivity';
            end
            
        end
        
        function prepareRun(obj)
            % set the figure split value
            if obj.movementSensitivity 
                obj.responsePlotSplitParameter = 'motionSensitivityStep';
            end
            
            % Call the base method.
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            %set directions
            obj.angles = rem(0:round(360/obj.numberOfAngles):359, 360);
            if obj.singleAngle >= 0
                obj.angles = obj.singleAngle * ones(size(obj.angles));
            end
            if obj.movementSensitivity 
                obj.sensitivitySteps = (1:obj.numberOfMovementSensitivitySteps) * obj.movementSensitivityStepSize;
            end
            
            % generate texture
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            sigma = obj.um2pix(0.5 * obj.textureScale / obj.resScaleFactor);
            if ~obj.randomMotion
                dist = obj.speed * obj.stimTime / 1000; % um / sec
            else
                dist = obj.speed * 5;
            end
            obj.moveDistance = dist;
            res = [max(canvasSize) * 1.42 + obj.um2pix(dist),...
                max(canvasSize) * 1.42, ]; % pixels
            res = round(res / obj.resScaleFactor);
            
            fprintf('making texture (%d x %d) with blur sigma %d pixels\n', res(1), res(2), sigma);
            
            stream = RandStream('mt19937ar','Seed',obj.randomSeed);
            if obj.singleDimension
                M = randn(stream, [res(1), 1]);
                M = repmat(M, [1, res(2)]);
            else
                M = randn(stream, res);
            end
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
            
            if obj.chirpStart
                chirpTime = 4;
                meanTime = 3;
                chirpLengthPix = round(obj.um2pix(obj.speed * chirpTime / obj.resScaleFactor));
                t = linspace(0, chirpTime, chirpLengthPix);
                ch = chirp(t, .1, chirpTime, 4, 'linear', pi);
                ch = ch > 0;
                ch = horzcat(obj.meanLevel * ones(1, round(obj.um2pix(obj.speed * meanTime / obj.resScaleFactor))), ch);
                ch = repmat(ch, [res(2), 1]);
                ch = ch';
                M(1:size(ch,1), 1:size(ch,2)) = ch;
            end
            
            obj.imageMatrix = uint8(255 * M);
            disp('done');
            
            % if using random motion, create the motion path here
            if obj.randomMotion
                motionFilter = designfilt('lowpassfir','PassbandFrequency',obj.motionLowpassFilterParams(1),'StopbandFrequency',obj.motionLowpassFilterParams(2),'SampleRate',60);
                stream = RandStream('mt19937ar', 'Seed', obj.motionSeed);
                obj.motionPath = stream.randn((obj.stimTime + obj.preTime)/1000 * 60 + 200, obj.randomMotionDimensions);
                obj.motionPath = filtfilt(motionFilter, obj.motionPath);
            else
                obj.motionPath = [];
            end
        end
        
        function prepareEpoch(obj, epoch)
            
            % Randomize angles if this is a new set
            index = mod(obj.numEpochsPrepared, obj.numberOfAngles);
            if index == 0
                obj.angles = obj.angles(randperm(obj.numberOfAngles));
            end

            obj.curAngle = obj.angles(index+1); %make it a property so preparePresentation has access to it
            epoch.addParameter('textureAngle', obj.curAngle);
            
            if obj.movementSensitivity
                index = mod(obj.numEpochsPrepared, obj.numberOfMovementSensitivitySteps);
                if index == 0
                    obj.sensitivitySteps = obj.sensitivitySteps(randperm(obj.numberOfMovementSensitivitySteps));
                end
                obj.curSensitivityStep = obj.sensitivitySteps(index+1);
            end
            epoch.addParameter('motionSensitivityStep', obj.curSensitivityStep);
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);           
            
            im = stage.builtin.stimuli.Image(obj.imageMatrix);
            im.orientation = obj.curAngle + 90;
            im.size = fliplr(size(obj.imageMatrix)) * obj.resScaleFactor;
            p.addStimulus(im);
            
            % circular aperture mask (only gratings in center)
            %             if obj.apertureDiameter > 0
            %                 apertureDiameterRel = obj.apertureDiameter / max(im.size);
            %                 mask = stage.core.Mask.createCircularEnvelope(2048, apertureDiameterRel);
            % %                 mask = stage.core.Mask.createCircularEnvelope();
            %                 im.setMask(mask);
            %             end
            
            if obj.apertureDiameter > 0
                % this is a gray square over the center of the display,
                % with a circle open in the middle
                maskRes = max(canvasSize) + 500;
                apertureDiameterRel = obj.um2pix(obj.apertureDiameter) / maskRes;
                %                 mask = Mask.createCircularEnvelope(max(im.size), apertureDiameterRel);
                mask = stage.core.Mask.createAnnulus(apertureDiameterRel, 10, maskRes);
                %                 mask.invert();
                
                aperture = stage.builtin.stimuli.Rectangle();
                aperture.color = obj.meanLevel;
                aperture.size = [maskRes, maskRes];
                aperture.position = canvasSize/2;
                aperture.setMask(mask);
                p.addStimulus(aperture);
            end
            
            %             circular block mask (only texture outside center)
            %             function opacity = onDuringStim(state, preTime, stimTime, tailTime)
            %                 if state.time>preTime*1e-3 && state.time<=(preTime+stimTime+tailTime)*1e-3
            %                     opacity = 1;
            %                 else
            %                     opacity = 0;
            %                 end
            %             end
            if obj.apertureDiameter < 0
                spot = stage.builtin.stimuli.Ellipse();
                spot.radiusX = round(obj.um2pix(obj.apertureDiameter) / 2); %convert to pixels
                spot.radiusY = spot.radiusX;
                spot.color = obj.meanLevel;
                spot.position = canvasSize/2;
                spot.opacity = 1;
                p.addStimulus(spot);
                %                 centerCircleController = stage.builtin.controllers.PropertyController(spot, 'opacity', @(s)onDuringStim(s, obj.preTime, obj.stimTime, obj.tailTime));
                %                 p.addController(centerCircleController);
            end
           
            
            % drift controller
            function pos = movementController(state, stimTime, preTime, movementDelay, pixelSpeed, angle, center, randomMotion, motionPath, movementSensitivity, sensitivityStep)
                t = state.time;
                duration = stimTime / 1000;
                shapeOnTime = preTime / 1000;
                startMovementTime = shapeOnTime + movementDelay/1000;
                endMovementTime = startMovementTime + stimTime/1000;
                
                if randomMotion

                    % random motion
                    if state.frame < 1
                        frame = 1;
                    else
                        frame = state.frame;
                    end
                    if size(motionPath,2) == 1
                        y = sind(angle) * pixelSpeed * motionPath(frame);
                        x = cosd(angle) * pixelSpeed * motionPath(frame);
                    else
                        y = sind(angle) * pixelSpeed * motionPath(frame, 1);
                        x = cosd(angle) * pixelSpeed * motionPath(frame, 2);
                    end
                    pos = [x,y] + center;
                    
                elseif movementSensitivity
                    disp(sensitivityStep)
                    if t < shapeOnTime
                        pos = [NaN, NaN];
                    elseif t < startMovementTime
                        pos = center;
                    elseif t < endMovementTime
                        x = cosd(angle) * sensitivityStep;
                        y = sind(angle) * sensitivityStep;
                        pos = [x,y] + center;
                    else
                        pos = [nan,nan];
                    end
                else % standard drift mode
                    if t < shapeOnTime
                        pos = [NaN, NaN];
                    elseif t < startMovementTime
                        y = pixelSpeed * sind(angle) * (0 - duration/2);
                        x = pixelSpeed * cosd(angle) * (0 - duration/2);
                        pos = [x,y] + center;
                        %                 else
                    elseif t < endMovementTime
                        timeFromStartMovement = t - startMovementTime;
                        y = pixelSpeed * sind(angle) * (timeFromStartMovement - duration/2);
                        x = pixelSpeed * cosd(angle) * (timeFromStartMovement - duration/2);
                        pos = [x,y] + center;
                    else
                        pos = [NaN, NaN];
                    end
                end
            end
            pixelSpeed = -1*obj.um2pix(obj.speed);
            controller = stage.builtin.controllers.PropertyController(im, ...
                'position', @(s)movementController(s, obj.stimTime, obj.preTime, ...
                obj.movementDelay, pixelSpeed, obj.curAngle, canvasSize/2, ...
                obj.randomMotion, obj.motionPath,...
                obj.movementSensitivity, obj.curSensitivityStep));
            p.addController(controller);
            
            %             obj.addFrameTracker(p);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            
            totalNumEpochs = obj.numberOfCycles * obj.numberOfAngles;
            if obj.movementSensitivity
                totalNumEpochs = obj.numberOfCycles * obj.numberOfMovementSensitivitySteps;
            end
        end
        
    end
    
end