classdef SpotFieldAndChirpAndBars < sa_labs.protocols.StageProtocol

    properties
        chirpSize = 100
        spotSize = 30

        extentX = 60 %um
        extentY = 60 %um
        
        barLength = 600                 % Bar length size (um)
        barWidth = 200                  % Bar Width size (um)

        spotStimFrames = 15
        spotPreFrames = 15
        spotTailFrames = 45

        spotIntensity = .5
        chirpIntensity = .5
        barIntensity = .5

        numberOfChirps = 8
        numberOfFields = 20
        numberOfBars = 2
    end
    
    properties (Hidden)
        chirpPattern = [];
        trialTypes = [];
        trialType = 0;
        numSpotsPerEpoch = NaN;
        
        cx = [];
        cy = [];

        theta = [];

        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'trialType';

        barSpeed = 1000 % um / s
        barDistance = 3000 % um
    end
    
    properties (Dependent) 
        stimTime
        preTime
        tailTime
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);

            dt = 1/obj.frameRate; % assume frame rate in Hz
            
            % *0.001 is to make in terms of seconds
            prePattern = zeros(1, round(2*obj.frameRate));
            interPattern = ones(1, round(2*obj.frameRate))*obj.chirpIntensity;
            tailPattern = zeros(1, round(5*obj.frameRate));
            posStepPattern = ones(1, round(3*obj.frameRate))*2*obj.chirpIntensity;
            negStepPattern = zeros(1, round(3*obj.frameRate));
            
            freqT = dt:dt:8;
            freqChange = linspace(0, 8, length(freqT));
            freqPhase = cumsum(freqChange*dt);
            freqPattern = obj.chirpIntensity*-sin(2*pi*freqPhase + pi) + obj.chirpIntensity;
            
            contrastT = dt:dt:8;
            contrastChange = linspace(0, 1, length(contrastT));
            contrastPattern = contrastChange.*obj.chirpIntensity.*-sin(4*pi.*contrastT + pi) + obj.chirpIntensity;

            obj.chirpPattern = [prePattern, posStepPattern, negStepPattern, interPattern...
                freqPattern, interPattern, contrastPattern, interPattern, tailPattern];


            obj.theta = linspace(0,2*pi,11);
            obj.theta(end) = [];
                   
            % cx_ = linspace(0,obj.gridX, obj.spotCountInX) - obj.gridX/2;
            % cy_ = linspace(0,obj.gridY, obj.spotCountInY) - obj.gridY/2;
            % [cx_,cy_] = meshgrid(cx_,cy_);
            % cx_ = cx_(:);
            % cy_ = cy_(:);
            % while length(obj.cx)*(obj.spotPreFrames + obj.spotStimFrames + obj.spotTailFrames)/obj.frameRate < 35
            %     % we have some extra frames to spare
            %     obj.cx = [obj.cx; cx_];
            %     obj.cy = [obj.cy; cy_];
            % end
            
%             obj.numSpotsPerEpoch = floor((obj.spotPreFrames + obj.spotStimFrames + obj.spotTailFrames)/obj.frameRate/35);
            obj.numSpotsPerEpoch = floor(35 * obj.frameRate / (obj.spotPreFrames + obj.spotStimFrames + obj.spotTailFrames));

            obj.trialTypes = vertcat(zeros(obj.numberOfChirps,1), ones(obj.numberOfFields,1), 2*ones(obj.numberOfBars,1));
            obj.trialTypes = obj.trialTypes(randperm(length(obj.trialTypes)));
        end
        
        function prepareEpoch(obj, epoch)
            index = obj.numEpochsPrepared + 1;
            obj.trialType = obj.trialTypes(index);
            if obj.trialType == 1
                epoch.addParameter('trialType', "field");

                
                obj.cx = rand(obj.numSpotsPerEpoch, 1) * obj.extentX - obj.extentX/2;
                obj.cy = rand(obj.numSpotsPerEpoch, 1) * obj.extentY - obj.extentY/2;

                epoch.addParameter('cx', obj.cx);
                epoch.addParameter('cy', obj.cy);
                
            elseif obj.trialType == 2
                epoch.addParameter('trialType', "bars");

                obj.theta = obj.theta(randperm(length(obj.theta)));

                epoch.addParameter('theta', obj.theta)

            else
                epoch.addParameter('trialType', "chirp");
            end

            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function p = createPresentation(obj)
            
            canvasSize = reshape(obj.rig.getDevice('Stage').getCanvasSize(),2,1);
            [~,cx_] = obj.um2pix(obj.cx);
            [~,cy_] = obj.um2pix(obj.cy);
            
            nFrames = numel(obj.chirpPattern);            
            chirpPattern_ = obj.chirpPattern;
            function i = getChirpIntensity(state)
                %clip the time axis to [1, T]
                frame=max(1, min(state.frame+1, nFrames));
                i = chirpPattern_(frame);
            end

            spotPre = obj.spotPreFrames;
            spotPreStim = obj.spotPreFrames+ obj.spotStimFrames;
            spotPreStimPost = obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames;
            function xy = getSpotPosition(state)
                i = min(floor(state.frame / spotPreStimPost) + 1, length(cx_));
                % i = min(mod(state.frame, obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames) + 1, length(obj.cx));
                
                % canvasSize / 2 + self.um2pix(self.currSpot(1:2));
                xy = canvasSize/2 + [cx_(i); cy_(i)];
            end
            
            sI = obj.spotIntensity;
            function c = getSpotIntensity(state)
                if state.frame >= nFrames - 1
                    c = 0;
                    return
                end
                
                i = mod(state.frame, spotPreStimPost);

                if i < spotPre || i >= spotPreStim
                    c = 0;
                else
                    c = sI;
                end
            end
            
            bI = obj.barIntensity;
            function c = getBarIntensity(state)
                if state.frame >= nFrames - 1
                    c = 0;
                    return
                end

                i = mod(state.frame, 210); % TODO: this assumes frame rate of 60 / bar speed 1mm/s
                if i < 15 || i >= 195
                    c = 0;
                else
                    c = bI;
                end

            end

            [~, pixelSpeed] = obj.um2pix(obj.barSpeed); %pix/s
            pixelSpeed = pixelSpeed / obj.frameRate; % pix/frame
            [~, pixelDistance] = obj.um2pix(obj.barDistance); %pix
            xStep = pixelSpeed * cos(obj.theta);
            yStep = pixelSpeed * sin(obj.theta);

            xStartPos = canvasSize(1)/2 - (pixelDistance / 2) * cos(obj.theta);
            yStartPos = canvasSize(2)/2 - (pixelDistance / 2) * sin(obj.theta);
           

            function xy = getBarPosition(state)
                xy = [NaN, NaN];

                i = mod(state.frame, 210); % TODO: this assumes frame rate of 60 / bar speed 1mm/s
                t = floor(state.frame, 210) + 1;

                if i >= 15 && i < 195
                    xy = [xStartPos(t) + (i-15) * xStep(t), yStartPos(t) + (i-15) * yStep(t)];
                end
            end
            
            theta_ = obj.theta;
            function th = getBarOrientation(state)
                t = floor(state.frame, 210) + 1;
                th = theta_(t);
            end

            p = stage.core.Presentation(35);

            if obj.trialType == 1 % grid
                spot = stage.builtin.stimuli.Ellipse();
            
                [~,spot.radiusX] = obj.um2pix(obj.spotSize / 2);
                spot.radiusY = spot.radiusX;
                spot.opacity = 1;
                spot.color = 0;
                
                spotIntensity_ = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getSpotIntensity(state));
                spotPosition = stage.builtin.controllers.PropertyController(spot, 'position',...
                    @(state)getSpotPosition(state));
                
                p.addStimulus(spot);

                p.addController(spotIntensity_);
                p.addController(spotPosition);
            elseif obj.trialType == 2
                bar = stage.builtin.stimuli.Rectangle();

                bar.color = 0;
                bar.opacity = 1;
                % bar.orientation = obj.barAngle;
                [~, barLength_] = obj.um2pix(obj.barLength);
                [~, barWidth_] = obj.um2pix(obj.barWidth);
                bar.size = [barLength_, barWidth_];
                p.addStimulus(bar);

                barIntensity_ = stage.builtin.controllers.PropertyController(bar, 'color',...
                    @(state)getBarIntensity(state));
                barPosition = stage.builtin.controllers.PropertyController(bar, 'position',...
                    @(state)getBarPosition(state));
                barOrientation = stage.builtin.controllers.PropertyController(bar, 'orientation',...
                    @(state)getBarOrientation(state));
                    

                p.addController(barIntensity_);
                p.addController(barPosition);
                p.addController(barOrientation);
            else %chirp
                spot = stage.builtin.stimuli.Ellipse();
            
                [~,spot.radiusX] = obj.um2pix(obj.chirpSize / 2);
                spot.radiusY = spot.radiusX;
                spot.opacity = 1;
                spot.color = 0;
                spot.position = canvasSize/2;
                spotIntensity_ = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getChirpIntensity(state));                    
                
                p.addStimulus(spot);
                p.addController(spotIntensity_);
            end

        end

        function preTime = get.preTime(obj)
            % if strcmp(obj.trialType,'chirp')
            %     preTime = 2000;
            % else
                preTime = 0;
            % end
        end
        
        function tailTime = get.tailTime(obj)
            % if strcmp(obj.trialType,'chirp')
            %     tailTime = 2000;
            % else
                tailTime = 0;
            % end
        end

        function stimTime = get.stimTime(obj)
            
            % if strcmp(obj.trialType,'chirp')
                stimTime = 35000;
            % else
            %     stimTime = obj.spotCountInX * obj.spotCountInY * (obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames) / obj.frameRate * 1e3;
            % end
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfChirps + obj.numberOfFields;
        end
        
    end
    
end