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
        chirpInensity = .5

        numberOfChirps = 8
        numberOfGrids = 20
    end
    
    properties (Hidden)
        chirpPattern = [];
        trialTypes = [];
        trialType = '';
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
            tailPattern = zeros(1, round(2*obj.frameRate));
            posStepPattern = ones(1, round(3*obj.frameRate))*(obj.chirpIntensity+(obj.chirpIntensity*obj.contrastMax));
            negStepPattern = ones(1, round(3*obj.frameRate))*(obj.chirpIntensity-(obj.chirpIntensity*obj.contrastMax));
            
            freqT = 0:dt:8;
            freqChange = linspace(0, 8, length(freqT));
            freqPhase = cumsum(freqChange*dt);
            freqPattern = obj.contrastMax*obj.chirpIntensity*-sin(2*pi*freqPhase + pi) + obj.chirpIntensity;
            
            contrastT = 0:dt:8;
            contrastChange = linspace(0, 1, length(contrastT));
            contrastPattern = contrastChange.*obj.chirpIntensity.*-sin(4*pi.*contrastT + pi) + cobj.chirpIntensity;

            obj.chirpPattern = [prePattern, posStepPattern, negStepPattern, interPattern...
                freqPattern, interPattern, contrastPattern, interPattern, tailPattern];


                
            cx = linspace(0,obj.gridX, obj.spotCountInX) - obj.gridX/2;
            cy = linspace(0,obj.gridY, obj.spotCountInY) - obj.gridY/2;
            [obj.cx,obj.cy] = meshgrid(cx,cy);
            obj.cx = obj.cx(:);
            obj.cy = obj.cy(:);

            obj.trialTypes = vertcat(zeros(obj.numberOfChirps,1), ones(obj.numberOfGrids,1));
            obj.trialTypes = obj.TrialTypes(randperm(length(obj.trialTypes)));
        end
        
        function prepareEpoch(obj, epoch)
            index = self.numEpochsPrepared + 1;
            obj.trialType = obj.trialTypes(index);
            if obj.trialType
                epoch.addParameter('trialType', 'grid');
                
                i = randperm(length(obj.cx));
                obj.cx = obj.cx(i);
                obj.cy = obj.cy(i);
                
                epoch.addParameter('cx', obj.cx);
                epoch.addParameter('cy', obj.cx);
                
            else
                epoch.addParameter('trialType', 'chirp');
            end

            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function p = createPresentation(obj)
            
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
                       
            function i = getChirpIntensity(obj, state)
                %clip the time axis to [1, T]
                frame=max(1, min(state.frame+1, numel(obj.chirpPattern)));
                i = obj.chirpPattern(frame);
            end

            function xy = getSpotPosition(obj, state)
                i = min(floor(state.frame / (obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames)) + 1, length(obj.cx));
                % i = min(mod(state.frame, obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames) + 1, length(obj.cx));

                % canvasSize / 2 + self.um2pix(self.currSpot(1:2));
                xy = canvasSize/2 + self.um2pix([obj.cx(i), obj.cy(i)]);
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

            if obj.trialType % grid
                p = stage.core.Presentation(obj.stimTime);
                spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
                spot.radiusY = spot.radiusX;
                spot.opacity = 1;
                
                spotIntensity = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getSpotIntensity(obj, state));
                spotPosition = stage.builtin.controllers.PropertyController(spot, 'position',...
                    @(state)getSpotPosition(obj, state));

                p.addController(spotIntensity);
                p.addController(spotPosition);
            else %chirp
                p = stage.core.Presentation(32);
                spot.radiusX = round(obj.um2pix(obj.chirpSize / 2));
                spot.radiusY = spot.radiusX;
                spot.opacity = 1;
                spot.position = canvasSize/2;
                spotIntensity = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getChirpIntensity(obj, state));                    
            
                p.addController(spotIntensity);
            end

            p.addStimulus(spot);
        end

        function preTime = get.preTime(obj)
            preTime = 0;
        end
        
        function tailTime = get.tailTime(obj)
            tailTime = 0;
        end

        function stimTime = get.stimTime(obj)
            stimTime = obj.spotCountInX * obj.spotCountInY * (obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames) / obj.frameRate;
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfChirps + obj.numberOfGrids;
        end
        
    end
    
end