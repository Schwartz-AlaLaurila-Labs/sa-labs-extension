classdef PairedSpotField < sa_labs.protocols.StageProtocol
    properties
        
        preTime = 100
        tailTime = 100

        spotSize = 30
        
        spotStimFrames = 15
        spotPreFrames = 15
        spotTailFrames = 45
        
        numSpotsPerEpoch = 30
        numRepeats = 3
        
        seed = -1 %-1 to use global stream, else a non-negative integer
        
        intensity = 1
        
    end
    
    
    properties (Dependent)
        
        stimTime
        
        spotStimTime
        spotPreTime
        spotTailTime
        
        totalNumEpochs
        
    end
    
    properties (Hidden, Transient)
        
        responsePlotMode = false;
        
        spotPairs = [] %size N-by-(a,b)-by-(x,y)
        spotPairsType = symphonyui.core.PropertyType('denserealdouble', 'matrix')
        
    end

    properties (Hidden)
        version = 2; % fixed bug with pre and tail times
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
            obj.index = reshape(i(1:totalSpots), obj.numSpotsPerEpoch, obj.totalNumEpochs);
            
        end
        
        function prepareEpoch(obj, epoch)
            obj.cx = obj.spotPairs(obj.index(:,obj.numEpochsPrepared + 1), :, 1);
            obj.cy = obj.spotPairs(obj.index(:,obj.numEpochsPrepared + 1), :, 2);
            
            
            epoch.addParameter('cx', obj.cx);
            epoch.addParameter('cy', obj.cy);
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj,epoch)
        end
        
        
        function p = createPresentation(obj)
            
            canvasSize = reshape(obj.rig.getDevice('Stage').getCanvasSize(),2,1);
            [~,cx_] = obj.um2pix(obj.cx);
            [~,cy_] = obj.um2pix(obj.cy);
            
            preFrames = obj.preTime * 1e-3 * obj.frameRate;
            stimFrames = obj.stimTime * 1e-3 * obj.frameRate;
            spotPre = obj.spotPreFrames;
            spotPreStim = obj.spotPreFrames + obj.spotStimFrames;
            spotPreStimPost = obj.spotPreFrames + obj.spotStimFrames + obj.spotTailFrames;
            
            function xy = getSpotPosition(frame, spot)
                if (frame < 0) || (frame >= stimFrames)
                    xy = [0;0];
                    return
                end
                i = min(floor(frame / spotPreStimPost) + 1, length(cx_));
                xy = canvasSize/2 + [cx_(i, spot); cy_(i, spot)];
            end
            
            bg = obj.meanLevel;
            sI = obj.intensity;
            function c = getSpotIntensity(frame)
                if (frame < 0) || (frame >= stimFrames)
                    c = bg;
                    return
                end
                i = mod(frame, spotPreStimPost);
                if (i < spotPre) || (i >= spotPreStim)
                    c = bg;
                else
                    c = sI;
                end
            end
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            spotA = stage.builtin.stimuli.Ellipse();
            
            [~,spotA.radiusX] = obj.um2pix(obj.spotSize / 2);
            spotA.radiusY = spotA.radiusX;
            spotA.opacity = 1;
            spotA.color = 0;
            
            spotAIntensity_ = stage.builtin.controllers.PropertyController(spotA, 'color',...
                @(state)getSpotIntensity(state.frame - preFrames));
            spotAPosition = stage.builtin.controllers.PropertyController(spotA, 'position',...
                @(state)getSpotPosition(state.frame - preFrames,1));
            
            p.addStimulus(spotA);
            
            p.addController(spotAIntensity_);
            p.addController(spotAPosition);
            
            
            spotB = stage.builtin.stimuli.Ellipse();
            
            [~,spotB.radiusX] = obj.um2pix(obj.spotSize / 2);
            spotB.radiusY = spotB.radiusX;
            spotB.opacity = 1;
            spotB.color = 0;
            
            spotBIntensity_ = stage.builtin.controllers.PropertyController(spotB, 'color',...
                @(state)getSpotIntensity(state.frame - preFrames));
            spotBPosition = stage.builtin.controllers.PropertyController(spotB, 'position',...
                @(state)getSpotPosition(state.frame - preFrames,2));
            
            p.addStimulus(spotB);
            
            p.addController(spotBIntensity_);
            p.addController(spotBPosition);
                        
        end

        function stimTime = get.stimTime(obj)
            stimTime = (obj.spotStimFrames + obj.spotPreFrames + obj.spotTailFrames) / obj.frameRate * 1e3 * obj.numSpotsPerEpoch;
        end
        
        function spotStimTime = get.spotStimTime(obj)
            spotStimTime = obj.spotStimFrames / obj.frameRate * 1e3;
        end
        
        function spotPreTime = get.spotPreTime(obj)
            spotPreTime = obj.spotPreFrames / obj.frameRate * 1e3;
        end
        
        function spotTailTime = get.spotTailTime(obj)
            spotTailTime = obj.spotTailFrames / obj.frameRate * 1e3;
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = ceil(size(obj.spotPairs,1) * obj.numRepeats / obj.numSpotsPerEpoch);
        end
        
        function set.spotPairs(self, pairs)
            self.spotPairs = reshape(pairs,[],2,2);
        end

    end
    
end
