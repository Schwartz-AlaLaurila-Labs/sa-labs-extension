classdef ColorResponse < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 250                  % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 1000                 % Spot trailing duration (ms)
        
        baseColor = [0.5, 0.5];
        contrast = 0.9;
        spotDiameter = 200              % Spot diameter (um)
        numberOfCycles = 3               % Number of cycles through all contrasts
    end
    
    properties (Hidden)
        spotContrasts
        currentColors
    
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'sortColors';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if obj.numberOfPatterns == 1
                error('Must have > 1 pattern enabled to use color stim');
            end
            
            c1 = 1 + obj.contrast;
            c2 = 1 - obj.contrast;
            obj.spotContrasts = [[c1,1];
                              [1,c1];
                              [c1,c1];
                              [c2,1];
                              [1,c2];
                              [c2,c2];
                              [c1,c2];
                              [c2,c1]];
            
        end

        function prepareEpoch(obj, epoch)

            index = mod(obj.numEpochsPrepared, 8) + 1;
            obj.currentColors = obj.baseColor .* obj.spotContrasts(index, :);

            epoch.addParameter('colors', obj.currentColors);
            epoch.addParameter('sortColors', sum([100,1] .* round(obj.currentColors*100))); % for plot display
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            surround = stage.builtin.stimuli.Ellipse();
            surround.color = 1;
            surround.opacity = 1;
            surround.radiusX = obj.um2pix(1200);
            surround.radiusY = surround.radiusX;
            surround.position = canvasSize / 2;
            p.addStimulus(surround);
            
            function c = surroundColor(state, backgroundColor)
                c = backgroundColor(state.pattern + 1);
            end
                    
            surroundColorController = stage.builtin.controllers.PropertyController(surround, 'color',...
                @(s) surroundColor(s, obj.baseColor));
            p.addController(surroundColorController);            
            
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.color = 1;
            spot.opacity = 1;
            spot.radiusX = obj.um2pix(obj.spotDiameter/2);
            spot.radiusY = spot.radiusX;
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            function c = spotColor(state, onColor, backgroundColor)
                if state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3
                    c = onColor(state.pattern + 1);
                else
                    c = backgroundColor(state.pattern + 1);
                end
            end
                    
            spotColorController = stage.builtin.controllers.PropertyController(spot, 'color',...
                @(s) spotColor(s, obj.currentColors, obj.baseColor));
            p.addController(spotColorController);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = 8 * obj.numberOfCycles;
        end
   
        
    end
    
end

