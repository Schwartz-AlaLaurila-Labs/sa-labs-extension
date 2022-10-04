classdef SpotGridAndChirp < sa_labs.protocols.StageProtocol

    properties
        chirpSize = 100
        spotSize = 30
        spotCountInX = 4
        spotCountInY = 4

        gridX = 60 %um
        gridY = 60 %um

        spotStimFrames = 15
        spotPreFrames = 15
        spotTailFrames = 60

        spotIntensity = .5
        chirpIntensity = .5

        numberOfChirps = 8
        numberOfGrids = 20
    end
    
    properties (Hidden)
        chirpPattern = [];
        trialTypes = [];
        trialType = 'grid';
        cx = [];
        cy = [];
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'trialType';
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
            
            freqT = 0:dt:8;
            freqChange = linspace(0, 8, length(freqT));
            freqPhase = cumsum(freqChange*dt);
            freqPattern = obj.chirpIntensity*-sin(2*pi*freqPhase + pi) + obj.chirpIntensity;
            
            contrastT = 0:dt:8;
            contrastChange = linspace(0, 1, length(contrastT));
            contrastPattern = contrastChange.*obj.chirpIntensity.*-sin(4*pi.*contrastT + pi) + obj.chirpIntensity;

            obj.chirpPattern = [prePattern, posStepPattern, negStepPattern, interPattern...
                freqPattern, interPattern, contrastPattern, interPattern, tailPattern];


                
            cx_ = linspace(0,obj.gridX, obj.spotCountInX) - obj.gridX/2;
            cy_ = linspace(0,obj.gridY, obj.spotCountInY) - obj.gridY/2;
            [cx_,cy_] = meshgrid(cx_,cy_);
            cx_ = obj.um2pix(cx_(:));
            cy_ = obj.um2pix(cy_(:));
            while length(obj.cx_)*(obj.spotPreFrames + obj.spotStimFrames + obj.spotTailFrames)/obj.frameRate < 35
                % we have some extra frames to spare
                obj.cx = [obj.cx; cx_];
                obj.cy = [obj.cx; cy_];
            end

            obj.trialTypes = vertcat(zeros(obj.numberOfChirps,1), ones(obj.numberOfGrids,1));
            obj.trialTypes = obj.trialTypes(randperm(length(obj.trialTypes)));
        end
        
        function prepareEpoch(obj, epoch)
            index = obj.numEpochsPrepared + 1;
            obj.trialType = obj.trialTypes(index);
            if obj.trialType
                epoch.addParameter('trialType', "grid");
                
                i = randperm(length(obj.cx));
                obj.cx = obj.cx(i);
                obj.cy = obj.cy(i);
                
                epoch.addParameter('cx', obj.cx);
                epoch.addParameter('cy', obj.cy);
                
            else
                epoch.addParameter('trialType', "chirp");
            end

            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function p = createPresentation(obj)
            
            canvasSize = reshape(obj.rig.getDevice('Stage').getCanvasSize(),2,1);
                       
            function i = getChirpIntensity(obj, state)
                %clip the time axis to [1, T]
                frame=max(1, min(state.frame+1, numel(obj.chirpPattern)));
                i = obj.chirpPattern(frame);
            end

            function xy = getSpotPosition(obj, state)
                i = min(floor(state.frame / (obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames)) + 1, length(obj.cx));
                % i = min(mod(state.frame, obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames) + 1, length(obj.cx));
                
                % canvasSize / 2 + self.um2pix(self.currSpot(1:2));
                xy = canvasSize/2 + [obj.cx(i); obj.cy(i)];
            end
            
            function c = getSpotIntensity(obj, state)
                i = mod(state.frame, obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames);

                if i < obj.spotPreFrames || i >=(obj.spotPreFrames + obj.spotStimFrames)
                    c = 0;
                else
                    c = obj.spotIntensity;
                end
            end

            spot = stage.builtin.stimuli.Ellipse();
            p = stage.core.Presentation(35);

            if obj.trialType % grid
                spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
                spot.radiusY = spot.radiusX;
                spot.opacity = 1;
                spot.color = 0;
                
                spotIntensity_ = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getSpotIntensity(obj, state));
                spotPosition = stage.builtin.controllers.PropertyController(spot, 'position',...
                    @(state)getSpotPosition(obj, state));
                
                p.addStimulus(spot);

                p.addController(spotIntensity_);
                p.addController(spotPosition);
            else %chirp
                spot.radiusX = round(obj.um2pix(obj.chirpSize / 2));
                spot.radiusY = spot.radiusX;
                spot.opacity = 1;
                spot.color = 0;
                spot.position = canvasSize/2;
                spotIntensity_ = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getChirpIntensity(obj, state));                    
                
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
            totalNumEpochs = obj.numberOfChirps + obj.numberOfGrids;
        end
        
    end
    
end