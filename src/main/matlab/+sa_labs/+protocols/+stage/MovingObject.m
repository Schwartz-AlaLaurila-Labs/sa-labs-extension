classdef MovingObject < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 50                     % Object leading duration (ms)
        tailTime = 50                    % Object trailing duration (ms)
        stimTime = 800
        intensity = 1.0                 % Object light intensity (0-1)
        setDirections = 8               % num directions in circle, or standard range
        setSpeeds = [1000,1000,1]                %
        setDiameters = [100,100,1]              % Object diameter (um)
        setOffsets = [0,0,0]
        setShapes = 'circle'
        centerTimeShift = -200;         % bias stimulus to before crossing the center (ms)
        numberOfCycles = 3              % Number of times through the set
    end
    
    properties (Hidden)
        version = 1                     % v1: initial version
        parameters = []                      % matrix of all epoch params, [angle, offset, side]
        currentParameters
        setShapesType = symphonyui.core.PropertyType('char', 'row', {'circle', 'rectangle'})
        
        responsePlotMode = 'polar';
        responsePlotSplitParameter = 'direction';
    end
    
    properties (Dependent)
        directions
        speeds
        offsets
        diameters
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        
        
        
        function prepareRun(obj)
            obj.generateParameters();
            fprintf('Generated %g parameter sets\n', size(obj.parameters, 1))
            prepareRun@sa_labs.protocols.StageProtocol(obj);
        end
        
        function generateParameters(obj)
%             obj.directions = obj.directions(randperm(length(obj.directions)));
%             obj.speeds = obj.speeds(randperm(length(obj.speeds)));
%             obj.offsets = obj.offsets(randperm(length(obj.offsets)));
%             obj.diameters = obj.diameters(randperm(length(obj.diameters)));
            
            params = [];
            
            for di = randperm(length(obj.directions))
                for si = randperm(length(obj.speeds))
                    for oi = randperm(length(obj.offsets))
                        for diami = randperm(length(obj.diameters))
                            params = vertcat(params, [obj.directions(di), obj.speeds(si), obj.offsets(oi), obj.diameters(diami)]);
                        end
                    end
                end
            end
            obj.parameters = params(randperm(size(params, 1)), :);
            
        end
        
        function prepareEpoch(obj, epoch)
            
            index = mod(obj.numEpochsPrepared, size(obj.parameters, 1));
            if index == 0
                obj.generateParameters();
            end
            
            obj.currentParameters = obj.parameters(index + 1, :);
            
            epoch.addParameter('direction', obj.currentParameters(1));
            epoch.addParameter('speed', obj.currentParameters(2));
            epoch.addParameter('offset', obj.currentParameters(3));
            epoch.addParameter('diameter', obj.currentParameters(4));
            
            fprintf('Next epoch: direction %g, speed %g, offset %g, diameter %g\n', obj.currentParameters(1), obj.currentParameters(2), obj.currentParameters(3), obj.currentParameters(4))
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function p = createPresentation(obj)
            currentDirection = obj.currentParameters(1);
            currentSpeed = obj.currentParameters(2);
            currentOffset = obj.currentParameters(3);
            currentDiameter = obj.currentParameters(4);
            
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            object = stage.builtin.stimuli.Ellipse();
            object.radiusX = round(obj.um2pix(currentDiameter / 2));
            object.radiusY = object.radiusX;
            object.color = obj.intensity;
            object.opacity = 1;
            object.orientation = 0;
            p.addStimulus(object);
            
            
            distance = (obj.stimTime/1000) * currentSpeed;
            
            [~, pixelSpeed] = obj.um2pix(currentSpeed);
            [~, pixelDistance] = obj.um2pix(distance);
            [~, pixelOffset] = obj.um2pix(currentOffset);
            
            xStep = pixelSpeed * cosd(currentDirection);
            yStep = pixelSpeed * sind(currentDirection);
            
            cts = obj.centerTimeShift;
            
            xStartPos = canvasSize(1)/2 - (pixelDistance / 2) * cosd(currentDirection) + pixelOffset * cosd(currentDirection - 90);
            yStartPos = canvasSize(2)/2 - (pixelDistance / 2) * sind(currentDirection) + pixelOffset * sind(currentDirection - 90);
            
            function pos = movementController(state)
                pos = [NaN, NaN];
                t = state.time - obj.preTime * 1e-3 + cts * 1e-3;
                if t >= 0 && t < obj.stimTime * 1e-3
                    pos = [xStartPos + t * xStep, yStartPos + t * yStep];
                end
            end
            
            objectMovement = stage.builtin.controllers.PropertyController(object, 'position', @(state)movementController(state));
            p.addController(objectMovement);
            
            obj.setOnDuringStimController(p, object);
            
            % shared code for multi-pattern objects
            obj.setColorController(p, object);
            
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
                totalNumEpochs = obj.numberOfCycles * size(obj.parameters, 1);
            end
            
            %         function stimTime = get.stimTime(obj)
            %             % to be written
            %             stimTime = 1000;
            %         end
            
            
            function out = parseParamInput(~, inpt, logScale, twoSided)
                if nargin < 2
                    logScale = 0;
                end
                if nargin < 3
                    twoSided = 0;
                end
                
                l = length(inpt);
                switch l
                    case 0
                        out = 0;
                    case 1
                        out = inpt(1);
                    case 2
                        if logScale
                            out = logspace(log10(inpt(1)), log10(inpt(2)), 8);
                        else
                            out = linspace(inpt(1), inpt(2), 8);
                        end
                    case 3
                        if logScale
                            out = logspace(log10(inpt(1)), log10(inpt(2)), inpt(3));
                        else
                            out = linspace(inpt(1), inpt(2), inpt(3));
                        end
                end
                
                if twoSided % mostly for offset
                    out = horzcat(-1*fliplr(out), 0, out); % don't repeat middle value
                end
            end
            
            function directions = get.directions(obj)
                if length(obj.setDirections) == 1
                    numberOfAngles = obj.setDirections(1);
                    directions = round(0:360/numberOfAngles:(360-.01));
                else
                    directions = obj.parseParamInput(obj.setDirections);
                    %                 numberOfAngles = obj.setDirections(3);
                    %                     d = obj.setDirections(2) - obj.setDirections(1);
                    %                     directions = round(obj.setDirections(1):d/numberOfAngles:((obj.setDirections(2)-.01)));
                end
            end
            
            
            function speeds = get.speeds(obj)
                speeds = obj.parseParamInput(obj.setSpeeds, 1, 0);
            end
            
            function offsets = get.offsets(obj)
                offsets = obj.parseParamInput(obj.setOffsets, 1, 1);
            end
            
            function diameters = get.diameters(obj)
                diameters = obj.parseParamInput(obj.setDiameters, 1, 0);
            end
        end
        
    end
    
