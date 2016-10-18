classdef LightStep < sa_labs.protocols.StageProtocol

    properties
        %times in ms
        preTime = 250	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 500	% Spot trailing duration (ms)
        
        intensity = 0.5;
        
        spotSize = 200; % um
        numberOfEpochs = 500;
    end
    
    properties (Hidden)
        version = 4
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = '';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
      
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

            %set bg
            p.setBackgroundColor(obj.meanLevel);
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            %spot.color = obj.intensity;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            function c = onDuringStim(state, preTime, stimTime, intensity, meanLevel)
                if state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3
                    c = intensity;
                else
                    c = meanLevel;
                end
            end
            
            controller = stage.builtin.controllers.PropertyController(spot, 'color', @(s)onDuringStim(s, obj.preTime, obj.stimTime, obj.intensity, obj.meanLevel));
            p.addController(controller);

        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end

    end
    
end