classdef PairedBars < sa_labs.protocols.StageProtocol

    properties
        preTime = 250                   % Bar leading duration (ms)
        tailTime = 500                  % Bar trailing duration (ms)
        stimTime = 1000                 % Bar on time (ms)
        intensity = 1.0                 % Bar light intensity (0-1)
        barLength = 500                 % Bar length size (um)
        barWidth = 15                  % Bar Width size (um)
        numberOfAngles = 4

        spacingIncrement = 16           %minimum separation between bars (um)
        numberOfPositions = 7           %number of different bars to test, centered on offsetX/offsetY
        numberOfCycles = 3
    end
    
    properties (Hidden)
        version = 1
    end
    
    properties (Hidden, Transient)
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'none';

        angles
        positions

        barAngle
        bar1Position
        bar2Position
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
               
        function prepareRun(obj)            
            prepareRun@sa_labs.protocols.StageProtocol(obj);

            obj.angles = linspace(0,pi,obj.numberOfAngles + 1);
            obj.angles(end) = [];
            
            % R2018b does not support combinations()
            obj.positions = perms(1:obj.numberOfPositions);
            obj.positions(3:end) = [];
            obj.positions = sort(obj.positions,2);
            obj.positions = unique(obj.positions,'rows');

            obj.positions = obj.positions - (obj.numberOfPositions + 1)/2;
            obj.positions = obj.positions * obj.spacingIncrement;

            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            bar1 = stage.builtin.stimuli.Rectangle();
            bar1.orientation = obj.barAngle;
            bar1.size = round([obj.um2pix(obj.barLength), obj.um2pix(obj.barWidth)]);

            %x = rcos(t), y = rsin(t)
            [~,p1] = obj.um2pix(obj.bar1Position);
            bar1.position = canvasSize / 2 + p1.*[cos(obj.barAngle), sin(obj.barAngle)];
            p.addStimulus(bar1);
            obj.setOnDuringStimController(p, bar1);


            bar2 = stage.builtin.stimuli.Rectangle();
            bar2.orientation = obj.barAngle;
            bar2.size = round([obj.um2pix(obj.barLength), obj.um2pix(obj.barWidth)]);

            %x = rcos(t), y = rsin(t)
            [~,p2] = obj.um2pix(obj.bar2Position);
            bar2.position = canvasSize / 2 + p2.*[cos(obj.barAngle), sin(obj.barAngle)];
            p.addStimulus(bar2);
            obj.setOnDuringStimController(p, bar2);
        end
        
        function prepareEpoch(obj, epoch)
            % every nchoose2 trials, shuffle the bar positions

            index = mod(obj.numEpochsPrepared, nchoosek(obj.numberOfPositions,2));
            if index == 0
                obj.positions = obj.positions(randperm(nchoosek(obj.numberOfPositions,2)),:);
            end
            obj.bar1Position = obj.positions(index+1,1);
            obj.bar2Position = obj.positions(index+1,2);
            epoch.addParameter('bar1Position', obj.bar1Position);
            epoch.addParameter('bar2Position', obj.bar2Position);


            % every nchoose2 * numberOfAngles trials, shuffle the angles
            index = mod(obj.numEpochsPrepared, obj.numberOfAngles * nchoosek(obj.numberOfPositions,2));
            if index == 0
                obj.angles = obj.angles(randperm(obj.numberOfAngles));
            end

            obj.barAngle = obj.angles(floor(index / nchoosek(obj.numberOfPositions,2))+1);

            epoch.addParameter('barAngle', obj.barAngle);

            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfAngles * nchoosek(obj.numberOfPositions,2);
        end

    end
    
end

