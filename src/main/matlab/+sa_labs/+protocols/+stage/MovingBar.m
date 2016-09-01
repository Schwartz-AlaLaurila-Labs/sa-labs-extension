classdef MovingBar < sa_labs.protocols.StageProtocol

    properties
        preTime = 250                   % Bar leading duration (ms)
        tailTime = 500                  % Bar trailing duration (ms)
        intensity = 1.0                 % Bar light intensity (0-1)
        barLength = 300                 % Bar length size (um)
        barWidth = 50                   % Bar Width size (um)
        barSpeed = 1000                 % Bar speed (um / s)
        distance = 1000                 % Bar distance (um)
        numberOfAngles = 12
        numberOfCycles = 2
    end
    
    properties (Hidden)
        version = 3
        displayName = 'Moving Bar'
        angles                          % Moving bar with Number of angles range between [0 - 360]
        barAngle                        % Moving bar angle for the current epoch @see prepareEpoch 
        
        responsePlotMode = 'polar';
        responsePlotSplitParameter = 'barAngle';
    end
    
    properties (Dependent)
        stimTime                        % Bar duration (ms)
    end
    
    methods
               
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            obj.angles = round(0:360/obj.numberOfAngles:(360-.01));
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.meanLevel);
            
            bar = stage.builtin.stimuli.Rectangle();
            bar.color = obj.intensity;
            bar.orientation = obj.barAngle;
            bar.size = round([obj.um2pix(obj.barLength), obj.um2pix(obj.barWidth)]);
            p.addStimulus(bar);
            
            pixelSpeed = obj.um2pix(obj.barSpeed);
            xStep = cosd(obj.barAngle);
            yStep = sind(obj.barAngle);
            
            xPos = canvasSize(1)/2 - xStep * canvasSize(2)/2;
            yPos = canvasSize(2)/2 - yStep * canvasSize(2)/2;
            
            function pos = movementController(state, duration)
                pos = [NaN, NaN];
                if state.time >= obj.preTime * 1e-3 && state.time < (duration - obj.tailTime) * 1e-3
                    pos = [xPos + (state.time - obj.preTime * 1e-3) * pixelSpeed * xStep,...
                        yPos + (state.time - obj.preTime * 1e-3) * pixelSpeed* yStep];
                    
                end
            end
            
            barMovement = stage.builtin.controllers.PropertyController(bar, 'position', @(state)movementController(state, p.duration * 1e3));
            p.addController(barMovement);
           
        end
        
        function prepareEpoch(obj, epoch)
            
            index = mod(obj.numEpochsPrepared, obj.numberOfAngles);
            if index == 0
                obj.angles = obj.angles(randperm(obj.numberOfAngles));
            end
            
            obj.barAngle = obj.angles(index+1);
            epoch.addParameter('barAngle', obj.barAngle);

            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfCycles * obj.numberOfAngles;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfCycles * obj.numberOfAngles;
        end

        function stimTime = get.stimTime(obj)
            pixelSpeed = obj.um2pix(obj.barSpeed);
            pixelDistance = obj.um2pix(obj.distance);
            stimTime = round(1e3 * pixelDistance/pixelSpeed);
        end
    end
    
end

