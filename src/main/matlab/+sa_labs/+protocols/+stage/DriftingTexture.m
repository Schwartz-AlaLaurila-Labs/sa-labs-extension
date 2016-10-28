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

        numberOfAngles = 12;
        numberOfCycles = 2;
        
        resScaleFactor = 2; % factor to decrease computational load
    end
    
    properties (Hidden)
       curAngle
       angles 
       imageMatrix
       moveDistance
       
       responsePlotMode = 'polar';
       responsePlotSplitParameter = 'textureAngle';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        function prepareRun(obj)
            % Call the base method.
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            %set directions
            obj.angles = rem(0:round(360/obj.numberOfAngles):359, 360);

            % generate texture
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            sigma = obj.um2pix(0.5 * obj.textureScale / obj.resScaleFactor);
            dist = obj.speed * obj.stimTime / 1000; % um / sec
            obj.moveDistance = dist;
            res = [max(canvasSize) * 1.42 + obj.um2pix(dist),...
                   max(canvasSize) * 1.42, ]; % pixels
            res = round(res / obj.resScaleFactor);
            
            fprintf('making texture (%d x %d) with blur sigma %d pixels\n', res(1), res(2), sigma);

            stream = RandStream('mt19937ar','Seed',obj.randomSeed);
            M = randn(stream, res);
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

%             figure(99)
%             subplot(2,1,2)
%             imagesc(M)
% %             caxis([min(M(:)), max(M(:))/2])
%             colormap gray
            
            obj.imageMatrix = uint8(255 * M);
            disp('done');
     

        end
        
        function prepareEpoch(obj, epoch)

            % Randomize angles if this is a new set
            index = mod(obj.numEpochsPrepared, obj.numberOfAngles);
            if index == 0
                obj.angles = obj.angles(randperm(obj.numberOfAngles));
            end
            
            obj.curAngle = obj.angles(index+1); %make it a property so preparePresentation has access to it
            epoch.addParameter('textureAngle', obj.curAngle);
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
                        
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.meanLevel);
            

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
            function pos = movementController(state, stimTime, preTime, movementDelay, pixelSpeed, angle, center)
                t = state.time;
                duration = stimTime / 1000;
                shapeOnTime = preTime / 1000;
                startMovementTime = shapeOnTime + movementDelay/1000;
                endMovementTime = startMovementTime + stimTime/1000;
                
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
            pixelSpeed = obj.um2pix(obj.speed);           
            controller = stage.builtin.controllers.PropertyController(im, ...
                'position', @(s)movementController(s, obj.stimTime, obj.preTime, ...
                obj.movementDelay, pixelSpeed, obj.curAngle, canvasSize/2));
            p.addController(controller);
 
%             obj.addFrameTracker(p);
        end

        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfAngles;
        end

    end
    
end