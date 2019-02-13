classdef OffsetMovingBar < sa_labs.protocols.StageProtocol

    properties
        preTime = 250                   % Bar leading duration (ms)
        tailTime = 250                  % Bar trailing duration (ms)
        intensity = 1.0                 % Bar light intensity (0-1)
        barLength = 600                 % Bar length size (um)
        barSpeed = 1000                 % Bar speed (um / s)
        distance = 3000                 % Bar distance (um)
        offsetRange = [15, 200]       % Bar edge offset (smallest, largest), 0 always included automatically
        numberOfOffsets = 11         % Number of offset steps
        offsetSide = 'both'             % which side to move bar
        angleOffset = 0                 % Angle set offset (deg)
        numberOfAngles = 8              % Number of angles to stimulate
        numberOfCycles = 3              % Number of times through the set
        singleEdgeMode = false          % Only display leading edge of bar, set length > 2 * distance
    end
    
    properties (Hidden)
        version = 2                     % v1: initial version
                                        % v2: added log spacing of offsets
        angles                          % angles for epochs, range between [0 - 360]
        offsets
        sides
        barWidth = 3000       
        parameters                      % matrix of all epoch params, [angle, offset, side]
        currentParameters
        contrastDirectionType = symphonyui.core.PropertyType('char', 'row', {'both', 'left', 'right'})
       
        responsePlotMode = 'polar';
        responsePlotSplitParameter = 'barAngle';
    end
    
    properties (Dependent)
        stimTime                        % Bar duration (ms)
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
               
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            obj.angles = mod(round(0:360/obj.numberOfAngles:(360-.01)) + obj.angleOffset, 360);
%             obj.offsets = linspace(obj.offsetRange(1), obj.offsetRange(2), obj.numberOfOffsets);
            offs = logspace(log10(obj.offsetRange(1)), log10(obj.offsetRange(2)), floor(obj.numberOfOffsets / 2));
            
            obj.offsets = round([-1 * fliplr(offs), 0, offs]);
            disp(obj.offsets)
             
            if strcmp(obj.offsetSide, 'both')
                obj.sides = [0,1];
            elseif strcmp(obj.offsetSide, 'right')
                obj.sides = [1];
            else
                obj.sides = [0];
            end
        end
        
        function prepareEpoch(obj, epoch)
            
            index = mod(obj.numEpochsPrepared, obj.numberOfAngles);
            if index == 0
                obj.angles = obj.angles(randperm(obj.numberOfAngles));
                obj.offsets = obj.offsets(randperm(obj.numberOfOffsets));
                
                params = [];
                
                for ai = 1:length(obj.angles)
                    for si = 1:length(obj.sides)
                        for oi = 1:length(obj.offsets)
                            params = vertcat(params, [obj.angles(ai), obj.sides(si), obj.offsets(oi)]);
                        end
                    end
                end
                obj.parameters = params(randperm(size(params, 1)), :);

            end
            
            obj.currentParameters = obj.parameters(index + 1, :);
            
            epoch.addParameter('barAngle', obj.currentParameters(1));
            epoch.addParameter('offsetSide', obj.currentParameters(2));
            epoch.addParameter('offset', obj.currentParameters(3));
            
            fprintf('Next epoch: angle %g, offsetSide %g, offset %g\n', obj.currentParameters(1), obj.currentParameters(2), obj.currentParameters(3))
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end        
        
        function p = createPresentation(obj)
            barAngle = obj.currentParameters(1);
            offset = obj.currentParameters(3);
            
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            bar = stage.builtin.stimuli.Rectangle();
            bar.color = obj.intensity;
            bar.opacity = 1;
            bar.orientation = barAngle;
            bar.size = [obj.um2pix(obj.barLength), obj.um2pix(obj.barWidth)];
            p.addStimulus(bar);
            
            [~, pixelSpeed] = obj.um2pix(obj.barSpeed);
            [~, pixelDistance] = obj.um2pix(obj.distance);
            [~, pixelOffset] = obj.um2pix(offset + obj.barWidth / 2);
            
            xStep = pixelSpeed * cosd(barAngle);
            yStep = pixelSpeed * sind(barAngle);

            if obj.singleEdgeMode
                stepBack = obj.um2pix(obj.barLength / 2); % move bar back half a length to time-center leading edge
            else
                stepBack = 0;
            end
            
            if obj.currentParameters(2) == 1
                sideMultiplier = 1;
            else
                sideMultiplier = -1;
            end
            xStartPos = canvasSize(1)/2 - (pixelDistance / 2 + stepBack) * cosd(barAngle) + pixelOffset * sideMultiplier * cosd(barAngle - 90);
            yStartPos = canvasSize(2)/2 - (pixelDistance / 2 + stepBack) * sind(barAngle) + pixelOffset * sideMultiplier * sind(barAngle - 90);
            
            function pos = movementController(state)
                pos = [NaN, NaN];
                t = state.time - obj.preTime * 1e-3;
                if t >= 0 && t < obj.stimTime * 1e-3
                    pos = [xStartPos + t * xStep, yStartPos + t * yStep];
                end
            end
            
            barMovement = stage.builtin.controllers.PropertyController(bar, 'position', @(state)movementController(state));
            p.addController(barMovement);
            
            
            % shared code for multi-pattern objects
            obj.setColorController(p, bar);
            
        end
                
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * (obj.numberOfAngles * length(obj.sides) * obj.numberOfOffsets);
        end        

        function stimTime = get.stimTime(obj)
            t = obj.distance / obj.barSpeed;
            stimTime = 1e3 * t;
        end
    end
    
end

