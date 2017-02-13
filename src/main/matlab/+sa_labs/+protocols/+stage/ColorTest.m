classdef ColorTest < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 200	% Spot leading duration (ms)
        stimTime = 500	% Spot duration (ms)
        tailTime = 200	% Spot trailing duration (ms)

    end
    
    properties (Hidden)
        
        responsePlotMode = false;
        responsePlotSplitParameter = '';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

%             p.setbackgroundPatternIndex(obj.meanLevel);

%             p.setbackgroundPatternIndex('blue');
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();

            siz = 500;
            spot0 = stage.builtin.stimuli.Ellipse();
            spot0.radiusX = round(obj.um2pix(siz / 2));
            spot0.radiusY = spot0.radiusX;
            spot0.color = 1;
            spot0.position = canvasSize / 2 - [round(obj.um2pix(siz)/2), 0];
            p.addStimulus(spot0);
            
            spot1 = stage.builtin.stimuli.Ellipse();
            spot1.radiusX = round(obj.um2pix(siz / 2));
            spot1.radiusY = spot1.radiusX;
            spot1.color = 1;
            spot1.position = canvasSize / 2;
            p.addStimulus(spot1);
                        
            function c = patternSelect(state, activePatternNumber)
                c = 1 * (state.pattern == activePatternNumber - 1);
            end
                        
            pattern = obj.primaryObjectPattern;
            controller0 = stage.builtin.controllers.PropertyController(spot0, 'opacity', ...
                @(s)patternSelect(s, pattern));
            
            pattern = obj.secondaryObjectPattern;
            controller1 = stage.builtin.controllers.PropertyController(spot1, 'opacity', ...
                @(s)patternSelect(s, pattern));
            
            p.addController(controller0);
            p.addController(controller1);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = 9999;
        end
        
        
    end
    
end