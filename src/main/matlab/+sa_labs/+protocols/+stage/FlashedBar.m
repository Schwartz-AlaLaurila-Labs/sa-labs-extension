classdef FlashedBar < sa_labs.protocols.StageProtocol

    properties
        preTime = 250                   % Bar leading duration (ms)
        tailTime = 500                  % Bar trailing duration (ms)
        stimTime = 1000                 % Bar on time (ms)
        intensity = 1.0                 % Bar light intensity (0-1)
        barLength = 300                 % Bar length size (um)
        barWidth = 50                   % Bar Width size (um)
        numberOfAngles = 6
        numberOfCycles = 2
    end
    
    properties (Hidden)
        version = 2
        displayName = 'Flashed Bar'
        angles                          % Moving bar with Number of angles range between [0 - 360]
        barAngle                        % Moving bar angle for the current epoch @see prepareEpoch 
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'barAngle';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
               
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            obj.angles = round(0:180/obj.numberOfAngles:(180-.01));
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            bar = stage.builtin.stimuli.Rectangle();
            bar.orientation = obj.barAngle;
            bar.size = round([obj.um2pix(obj.barLength), obj.um2pix(obj.barWidth)]);
            bar.position = canvasSize / 2;
            p.addStimulus(bar);
                   
            obj.setOnDuringStimController(p, bar);
            
           % shared code for multi-pattern objects
            obj.setColorController(p, bar);
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
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfAngles;
        end

    end
    
end

