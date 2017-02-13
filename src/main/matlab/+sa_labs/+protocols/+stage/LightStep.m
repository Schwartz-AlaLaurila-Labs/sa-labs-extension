classdef LightStep < sa_labs.protocols.StageProtocol

    properties
        %times in ms
        preTime = 500	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 1000	% Spot trailing duration (ms)
        
        intensity = 0.5;
        
        spotSize = 200; % um
        numberOfEpochs = 500;
    end
    
    properties (Hidden)
        version = 4
        
        responsePlotMode = false;%'cartesian';
        responsePlotSplitParameter = '';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
      
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            spot.color = obj.intensity;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            function c = opaqueDuringStim(state, preTime, stimTime)
                c = 1 * (state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3);
            end
            
            function c = patternSelect(state, activePatternNumber)
                c = 1 * (state.pattern == activePatternNumber - 1);
            end
                        
            if obj.numberOfPatterns > 1
                pattern = obj.primaryObjectPattern;
                controller = stage.builtin.controllers.PropertyController(spot, 'color', ...
                    @(s)(opaqueDuringStim(s, obj.preTime, obj.stimTime) && patternSelect(s, pattern)));
            else
                controller = stage.builtin.controllers.PropertyController(spot, 'opacity', ...
                    @(s)opaqueDuringStim(s, obj.preTime, obj.stimTime));
            end
            p.addController(controller);

        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end

    end
    
end