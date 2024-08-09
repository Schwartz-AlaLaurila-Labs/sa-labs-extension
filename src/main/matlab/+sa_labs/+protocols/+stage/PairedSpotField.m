classdef PairedSpotField < sa_labs.protocols.StageProtocol
    properties
        
        spotStimFrames = 15
        spotPreFrames = 15
        spotTailFrames = 45

        numSpotsPerEpoch = 30
        numRepeats = 3

        spotPairs = [] %size N-by-(a,b)-by-(x,y) 

        seed = -1 %-1 to use global stream, else a non-negative integer

    end


    properties (Dependent)

        stimTime
        preTime
        tailTime

        spotStimTime
        spotPreTime
        spotTailTime

        totalNumEpochs

    end

    properties (Hidden)

        responsePlotMode = false;

    end

    properties (Hidden, Transient, Access = private)

        cx = [];
        cy = [];
        
        index = [];

    end

    methods
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj)
            %%
            
            if obj.seed >= 0
                randStream = RandStream('mt19937ar','seed',obj.seed);
            else
                randStream = RandStream.getGlobalStream();
            end

            % create the cycles and shuffle them
            totalSpots = obj.numSpotsPerEpoch * obj.totalNumEpochs;
            [~,i] = sort(rand(randStream, size(obj.spotPairs,1), ceil(totalSpots / size(obj.spotPairs,1))));
            obj.index = reshape(i, obj.numSpotsPerEpoch, obj.totalNumEpochs);            

        end

        function prepareEpoch(obj)
            obj.cx = obj.spotPairs(obj.index(obj.numEpochsPrepared + 1), :, 1);
            obj.cy = obj.spotPairs(obj.index(obj.numEpochsPrepared + 1), :, 2);

            
            epoch.addParameter('cx', obj.cx);
            epoch.addParameter('cy', obj.cy);

            prepareEpoch@sa_labs.protocols.StageProtocol(obj,epoch)
        end

        
        function p = createPresentation(obj)
            
            canvasSize = reshape(obj.rig.getDevice('Stage').getCanvasSize(),2,1);
            [~,cx_] = obj.um2pix(obj.cx);
            [~,cy_] = obj.um2pix(obj.cy);
                       
            spotPre = obj.spotPreFrames;
            spotPreStim = obj.spotPreFrames + obj.spotStimFrames;
            spotPreStimPost = obj.spotPreFrames + obj.spotStimFrames + obj.spotTailFrames;
                        
            function xy = getSpotPosition(state, spot)
                i = min(floor(state.frame / spotPreStimPost) + 1, length(cx_));
                xy = canvasSize/2 + [cx_(i, spot); cy_(i, spot)];
            end
            
            sI = obj.spotIntensity;
            function c = getSpotIntensity(state)
                i = mod(state.frame, spotPreStimPost);
                if (i < spotPre) || (i >= spotPreStim)
                    c = 0;
                else
                    c = sI;
                end
            end
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

            spotA = stage.builtin.stimuli.Ellipse();
        
            [~,spotA.radiusX] = obj.um2pix(obj.spotSize / 2);
            spotA.radiusY = spot.radiusX;
            spotA.opacity = 1;
            spotA.color = 0;
            
            spotAIntensity_ = stage.builtin.controllers.PropertyController(spotA, 'color',...
                @(state)getSpotIntensity(state));
            spotAPosition = stage.builtin.controllers.PropertyController(spotA, 'position',...
                @(state)getSpotPosition(state,1));
            
            p.addStimulus(spotA);

            p.addController(spotAIntensity_);
            p.addController(spotAPosition);


            spotB = stage.builtin.stimuli.Ellipse();
        
            [~,spotB.radiusX] = obj.um2pix(obj.spotSize / 2);
            spotB.radiusY = spot.radiusX;
            spotB.opacity = 1;
            spotB.color = 0;
            
            spotBIntensity_ = stage.builtin.controllers.PropertyController(spotB, 'color',...
                @(state)getSpotIntensity(state));
            spotBPosition = stage.builtin.controllers.PropertyController(spotB, 'position',...
                @(state)getSpotPosition(state,2));
            
            p.addStimulus(spotB);

            p.addController(spotBIntensity_);
            p.addController(spotBPosition);

        end

    end
    
    function stimTime = get.stimTime(obj)
        stimTime = (spotStimFrames + spotPreFrames + spotTailFrames) / obj.frameRate * obj.numSpotsPerEpoch;
    end

    function preTime = get.preTime(obj)
        preTime = 0;
    end

    function tailTime = get.tailTime(obj)
        tailTime = 0;
    end

    function spotStimTime = get.spotStimTime(obj)
        spotStimTime = spotStimFrames;
    end

    function spotPreTime = get.spotPreTime(obj)
        spotPreTime = spotPreFrames;
    end

    function spotTailTime = get.spotTailTime(obj)
        spotTailTime = spotTailFrames;
    end

    function totalNumEpochs = get.totalNumEpochs(obj)
        totalNumEpochs = ceil(size(obj.spotPairs,1) * obj.numRepeats / obj.numSpotsPerEpoch);
    end


end
