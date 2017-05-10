classdef LightStep < sa_labs.protocols.StageProtocol

    properties
        %times in ms
        preTime = 500	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 1000	% Spot trailing duration (ms)
        
        intensity = 0.5;
        
        spotSize = 200; % um
        numberOfEpochs = 500;
        
        alternatePatterns = false % alternates spot pattern between PRIMARY and SECONDARY OBJECT PATTERNS
    end
    
    properties (Hidden)
        version = 4
        currentSpotPattern
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'currentSpotPattern';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareEpoch(obj, epoch)
            obj.currentSpotPattern = obj.primaryObjectPattern;
            if obj.numberOfPatterns > 1
                if obj.alternatePatterns
                    if mod(obj.numEpochsPrepared, 2) == 1
                        obj.currentSpotPattern = obj.secondaryObjectPattern;
                        currentSpotColor = obj.colorPattern2;
                    else
                        obj.currentSpotPattern = obj.primaryObjectPattern;
                        currentSpotColor = obj.colorPattern1;
                    end
                    disp(currentSpotColor)
                end
            end
            epoch.addParameter('currentSpotPattern', obj.currentSpotPattern);
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
                        
        end        
      
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            spot.color = obj.intensity;
            spot.opacity = 1;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            obj.setOnDuringStimController(p, spot);
            
            % shared code for multi-pattern objects
            obj.setColorController(p, spot);

        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end

    end
    
end