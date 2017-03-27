classdef TextureMatrix < sa_labs.protocols.StageProtocol
        
    properties
        %times in ms
        preTime =50;
        tailTime = 50;
        stimTime = 1000;
        
        %in microns, use rigConfig to set microns per pixel
        apertureDiameter = 800; %um
        
        minTextureScale = 80; %um
        maxTextureScale = 80
        numOfScaleSteps = 1;
        logScaling = false;
        numRandomSeeds = 2;
        
        uniformDistribution = true;
        singleDimension = false;
%         singleAngle = -1; % set to a positive value to use a single fixed angle
%         numberOfAngles = 12;       
        numberOfCycles = 2;
        resScaleFactor = 2; % factor to decrease computational load


        
    end
    
    properties (Hidden)
        version = 1 %Adam 3/21/17, based on "ImageCycler" and "drifting Texture"
        imageMatrices
        textureScale
        randomSeed
        curImageMatrix
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'textureScale';
        orderOfImages
    end
    
    properties (Hidden, Dependent)
%         numScales
%         numSeeds
        numConditions
        totalNumEpochs
    end
    
    methods
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);        
%             
%             switch name
%                 case {'randomMotion','motionSeed','motionLowpassFilterParams'}
%                     d.category = '5 Random Motion';
%                 case {'movementSensitivity','numberOfMovementSensitivitySteps','movementSensitivityStepSize'}
%                     d.category = '6 Motion Sensitivity';
%             end
            
        end
        
        function prepareRun(obj)
            % Call the base method.
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            %set textureScale and randomSeed
            if ~obj.logScaling
                obj.textureScale = linspace(obj.minTextureScale, obj.maxTextureScale, obj.numOfScaleSteps);
            else
                obj.textureScale = logspace(obj.minTextureScale, obj.maxTextureScale, obj.numOfScaleSteps);
            end
            obj.randomSeed = (1:obj.numRandomSeeds)*907;
            

            for scaleInd = 1:obj.numOfScaleSteps
                for seedInd = 1:obj.numRandomSeeds
                    % generate texture
                    canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
                    sigma = obj.um2pix(0.5 * obj.textureScale(scaleInd) / obj.resScaleFactor);
                    res = [max(canvasSize) * 1.42,...
                        max(canvasSize) * 1.42]; % pixels
                    res = round(res / obj.resScaleFactor);
                    
                    fprintf('making texture (%d x %d) with blur sigma %d pixels\n', res(1), res(2), sigma);
                    
                    stream = RandStream('mt19937ar','Seed',obj.randomSeed(seedInd));
                    if obj.singleDimension
                        M = randn(stream, [res(1), 1]);
                        M = repmat(M, [1, res(2)]);
                    else
                        M = randn(stream, res);
                    end
                    %Make pre-filtering matrix binary... 
                    M(M <= 0) = 0;
                    M(M > 0) = 1;
                    
                    defaultSize = 2*ceil(2*sigma)+1;
                    M = imgaussfilt(M, sigma, 'FilterDomain','frequency','FilterSize',defaultSize*2+1);
                    
                    %             figure(99)
                    %             subplot(2,1,1)
                    %             imagesc(M)
                    %             caxis([-.1,.1])
                    % %             caxis([min(M(:)), max(M(:))/2])
                    %             colormap gray
                    
                    if obj.uniformDistribution
                        %Consider only pixels within apperture
%                         appRadius = obj.um2pix(0.5 * obj.apertureDiameter/obj.resScaleFactor);
%                         Mcenter = res./2;
%                         [X,Y] = meshgrid(1:res(1),1:res(2));
%                         M_in_app = M(((X-Mcenter(1)).^2+(Y-Mcenter(2)).^2)<=appRadius^2);
%                         bins = [-Inf prctile(M_in_app,1:1:100)];
                        % % %
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
                    
                    %Mapping of image parameters(3) to linear index (1) defined here
                    %[scale, seed, "positive or negative" image] --> linear index
                    linearIndex = sub2ind([obj.numOfScaleSteps,obj.numRandomSeeds,2], scaleInd, seedInd, 1);                     
                    obj.imageMatrices(:,:, linearIndex) = uint8(255 * M);
                    linearIndex = sub2ind([obj.numOfScaleSteps,obj.numRandomSeeds,2], scaleInd, seedInd, 2);
                    obj.imageMatrices(:,:, linearIndex) = uint8(255 * (1-M));
                    disp('done');
                end;
            end;

        end
        
        function prepareEpoch(obj, epoch)
%             
%             % Randomize angles if this is a new set
%             index = mod(obj.numEpochsPrepared, obj.numberOfAngles);
%             if index == 0
%                 obj.angles = obj.angles(randperm(obj.numberOfAngles));
%             end
% 
%             obj.curAngle = obj.angles(index+1); %make it a property so preparePresentation has access to it
%             epoch.addParameter('textureAngle', obj.curAngle);
%             
%             if obj.movementSensitivity
%                 index = mod(obj.numEpochsPrepared, obj.numberOfMovementSensitivitySteps);
%                 if index == 0
%                     obj.sensitivitySteps = obj.sensitivitySteps(randperm(obj.numberOfMovementSensitivitySteps));
%                 end
%                 obj.curSensitivityStep = obj.sensitivitySteps(index+1);
%             end
%             epoch.addParameter('motionSensitivityStep', obj.curSensitivityStep);
%             
            epochIndex = mod(obj.numEpochsPrepared, obj.numConditions)+1;
            if epochIndex == 1
                obj.orderOfImages = randperm(obj.numConditions);
            end;
            imagelinearIndex = obj.orderOfImages(epochIndex);
            %Add order randomization later!
            obj.curImageMatrix = obj.imageMatrices(:,:,imagelinearIndex);
            [scaleInd,seedInd,posOrNegImage_Ind] = ind2sub([obj.numOfScaleSteps,obj.numRandomSeeds,2],imagelinearIndex);
            epoch.addParameter('textureScale', obj.textureScale(scaleInd));
            epoch.addParameter('randomSeed',obj.randomSeed(seedInd));
            epoch.addParameter('negativeImage',posOrNegImage_Ind == 2);
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);           
            
            im = stage.builtin.stimuli.Image(uint8(obj.curImageMatrix));
            im.size = fliplr(size(obj.curImageMatrix)) * obj.resScaleFactor;
            im.position = canvasSize / 2;
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
            imVisible = stage.builtin.controllers.PropertyController(im, 'opacity', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(imVisible);
        end
        
%         function numScales = get.numScales(obj)
%             numScales = length(obj.textureScale);
%         end
%         
%         function numSeeds = get.numSeeds(obj)
%             numSeeds = length(obj.randomSeed);
%         end
        
        function numConditions = get.numConditions(obj)
           numConditions = obj.numOfScaleSteps*obj.numRandomSeeds*2; 
           %x2 is for pos and neg images
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numConditions;
        end
        
    end
end

