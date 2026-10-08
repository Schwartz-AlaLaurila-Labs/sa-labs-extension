classdef CenterSurround < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 500	% Spot trailing duration (ms)
        
        %intensity value for green and uv LEDs
        intensityGreen = 0.5;
        intensityUV = 0.5;
        
        centerDiameter = 200;
        surroundInnerDiameter = 300;
        surroundOuterDiameter = 2000;
        
        numberOfCycles = 2;
    end
    
    properties (Hidden)
        curPattern
        centerIntensity
        surroundIntensity
        
        %0 = G, 1 = UV, 2 = B
        %all UV, UV inner, UV outer, all green, green inner, green outer,
        %uv/green, green/uv        
        patternM=[0 1 2; 1 0 2]; % center, surround, background
        patternLabel=[112;102];
        patternVec
        patternText = {'center green, surround UV','center UV, surround green'};
        centerPatternIndex
        surroundPatternIndex
        backgroundPatternIndex
        
        responsePlotMode = false;
        responsePlotSplitParameter = 'patternFull';
    end
    
    %     properties (Dependent)
    %         CenterR
    %         CenterM
    %         CenterS
    %         SurroundR
    %         SurroundM
    %         SurroundS
    %         MeanR
    %         MeanM
    %         MeanS
    %     end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    
    methods
        
        function prepareEpoch(obj, epoch)
            
            % Randomize patterns if this is a new set
            index = mod(obj.numEpochsPrepared, size(obj.patternM, 1)) + 1;
            obj.patternVec = 1:size(obj.patternM, 1);
%             if index == 1
%                 obj.patternVec = randperm(size(obj.patternM, 1));
%             end
            
            %get current pattern
            obj.curPattern = obj.patternVec(index);
            
            %label patterns (figure handler doesn't like strings)
            epoch.addParameter('patternFull', obj.patternLabel(obj.curPattern));
            
            obj.centerPatternIndex = obj.patternM(obj.curPattern, 2);
            obj.surroundPatternIndex = obj.patternM(obj.curPattern, 1);
            obj.backgroundPatternIndex = obj.patternM(obj.curPattern, 3);
                        
            disp(obj.patternText{index});
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end        
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();

            spotOuter = stage.builtin.stimuli.Ellipse();
            spotOuter.radiusX = round(obj.um2pix(obj.surroundOuterDiameter / 2));
            spotOuter.radiusY = spotOuter.radiusX;
            spotOuter.color = 0;%TEMP
            spotOuter.position = canvasSize / 2;
            p.addStimulus(spotOuter);
            
            spotBorder = stage.builtin.stimuli.Ellipse();
            spotBorder.radiusX = round(obj.um2pix((obj.surroundInnerDiameter) / 2));
            spotBorder.radiusY = spotBorder.radiusX;
            spotBorder.color = obj.meanLevel;
            spotBorder.position = canvasSize / 2;
            p.addStimulus(spotBorder);
            
            spotInner = stage.builtin.stimuli.Ellipse();
            spotInner.radiusX = round(obj.um2pix(obj.centerDiameter / 2));
            spotInner.radiusY = spotInner.radiusX;
            spotInner.color = 0;%TEMP
            spotInner.position = canvasSize / 2;
            p.addStimulus(spotInner);

            if obj.patternM(obj.curPattern, 1) == 0
                obj.surroundIntensity = obj.intensityGreen;
            elseif obj.patternM(obj.curPattern, 1) == 1
                obj.surroundIntensity = obj.intensityUV;
            else
                obj.surroundIntensity = 0;
            end
            if obj.patternM(obj.curPattern, 2) == 0
                obj.centerIntensity = obj.intensityGreen;
            elseif obj.patternM(obj.curPattern, 2) == 1
                obj.centerIntensity = obj.intensityUV;
            else
                obj.centerIntensity = 0;
            end
            
            fprintf('INTENSITY: center: %g, surround: %g, background: %g\n', obj.centerPatternIndex, obj.surroundPatternIndex, obj.backgroundPatternIndex);

            % Controller closures are serialized to the Stage server: capture
            % plain values and call the package function
            % sa_labs.controllers.CenterSurround_onDuringStim (not a class method,
            % so the Stage server never has to load this classdef), never obj
            % or a nested function (which shares this workspace and drags obj
            % along, failing on the server with no frames drawn).
            preTime = obj.preTime;   %#ok<*PROP>
            stimTime = obj.stimTime;
            meanLevel = obj.meanLevel;
            backgroundPattern = obj.patternM(obj.curPattern, 3);
            centerIntensity = obj.centerIntensity;
            centerPattern = obj.centerPatternIndex;
            surroundIntensity = obj.surroundIntensity;
            surroundPattern = obj.surroundPatternIndex;

            controllerBackground = stage.builtin.controllers.PropertyController(spotBorder, 'color', ...
                @(s)sa_labs.controllers.CenterSurround_onDuringStim(s, preTime, stimTime, meanLevel, backgroundPattern, backgroundPattern, meanLevel));

            controllerInner = stage.builtin.controllers.PropertyController(spotInner, 'color', ...
                @(s)sa_labs.controllers.CenterSurround_onDuringStim(s, preTime, stimTime, centerIntensity, centerPattern, backgroundPattern, meanLevel));

            controllerOuter = stage.builtin.controllers.PropertyController(spotOuter, 'color',...
                @(s)sa_labs.controllers.CenterSurround_onDuringStim(s, preTime, stimTime, surroundIntensity, surroundPattern, backgroundPattern, meanLevel));

            p.addController(controllerBackground);
            p.addController(controllerOuter);
            p.addController(controllerInner);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * size(obj.patternM, 1);
        end


    end

end