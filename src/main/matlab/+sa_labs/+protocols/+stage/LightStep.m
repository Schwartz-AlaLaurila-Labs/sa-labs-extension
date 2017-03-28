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
            
            function c = patternSelect(state, activePatternNumber)
                c = 1 * (state.pattern == activePatternNumber - 1);
            end

            function c = onDuringStim(state, preTime, stimTime)
                c = 1 * (state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3);
            end
                        
            if obj.numberOfPatterns > 1
                pattern = obj.currentSpotPattern;
                
                if strcmp(obj.colorCombinationMode, 'replace')
                    patternController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                        @(s)(obj.intensity * patternSelect(s, pattern)));
                    p.addController(patternController);
                else % add
                    bgPattern = obj.backgroundPattern;
                    patternController = stage.builtin.controllers.PropertyController(spot, 'color', ...
                        @(s)(obj.intensity * patternSelect(s, pattern) + obj.meanLevel * patternSelect(s, bgPattern)));
                    p.addController(patternController);
                end
            end
                        
            controller = stage.builtin.controllers.PropertyController(spot, 'opacity', ...
                @(s)onDuringStim(s, obj.preTime, obj.stimTime));
            p.addController(controller);

        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end

    end
    
end