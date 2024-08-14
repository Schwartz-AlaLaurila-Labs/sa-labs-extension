classdef PairedBars < sa_labs.protocols.StageProtocol

    properties
        preTime = 250                   % Bar leading duration (ms)
        tailTime = 500                  % Bar trailing duration (ms)
        intensity = 1.0                 % Bar light intensity (0-1)
        barLength = 500                 % Bar length size (um)
        barWidth = 15                  % Bar Width size (um)
        numberOfAngles = 4
        phase = 0                       % degrees anticlockwise from x-axis of first angle in sequence 
        
        paired = true                   % if false, does unpaired bar
        barDuration = 1000                 %duration of each bar (ms)
        
        spacingIncrement = 16           %minimum separation between bars (um)
        numberOfPositions = 7           %number of different bars to test, centered on offsetX/offsetY
        numberOfCycles = 3
        
        numberOfDelays = 1
        delayIncrement = 0              %minimum separation between bars (ms)
    end
    
    properties (Hidden)
        version = 1
    end
    
    properties (Hidden, Transient)
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'bar1Position';

        angles
        positions
        delays

        barAngle
        bar1Position
        bar2Position
        delay
    end
    
    properties (Dependent)
        stimTime
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
               
        function prepareRun(obj)            
            prepareRun@sa_labs.protocols.StageProtocol(obj);

            obj.angles = linspace(0,180,obj.numberOfAngles + 1) + obj.phase;
            obj.angles(end) = [];
            
            % R2018b does not support combinations()
            if obj.paired
                obj.positions = perms(1:obj.numberOfPositions);
                obj.positions(:,3:end) = [];
                obj.positions = sort(obj.positions,2);
                obj.positions = unique(obj.positions,'rows');
            else
                obj.positions = (1:obj.numberOfPositions)';
            end

            obj.positions = obj.positions - (obj.numberOfPositions + 1)/2;
            obj.positions = obj.positions * obj.spacingIncrement;

            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            bar1 = stage.builtin.stimuli.Rectangle();
            bar1.orientation = obj.barAngle;
            [~, bar1.size(1)] = obj.um2pix(obj.barLength);
            [~, bar1.size(2)] = obj.um2pix(obj.barWidth);
%             bar1.size = round([obj.um2pix(obj.barLength), obj.um2pix(obj.barWidth)]);

            %x = rcos(t), y = rsin(t)
            [~,p1] = obj.um2pix(obj.bar1Position);
%             bar1.position = canvasSize / 2 + [0,p1];
            bar1.position = canvasSize / 2 + p1.*[cosd(obj.barAngle + 90), sind(obj.barAngle + 90)];
            p.addStimulus(bar1);
            obj.setOnDuringStimController(p, bar1);

            if obj.paired
                bar2 = stage.builtin.stimuli.Rectangle();
                bar2.orientation = obj.barAngle;
                [~,bar2.size(1)] = obj.um2pix(obj.barLength);
                [~,bar2.size(2)] = obj.um2pix(obj.barWidth);
    %             bar2.size = round([obj.um2pix(obj.barLength), obj.um2pix(obj.barWidth)]);

                %x = rcos(t), y = rsin(t)
                [~,p2] = obj.um2pix(obj.bar2Position);
    %             bar2.position = canvasSize / 2 + [0,p2];
                bar2.position = canvasSize / 2 + p2.*[cosd(obj.barAngle + 90), sind(obj.barAngle + 90)];
                p.addStimulus(bar2);
                obj.setOnDuringStimController(p, bar2);
            end
        end
        
        function prepareEpoch(obj, epoch)
            % every nchoose2 trials, shuffle the bar positions

            index = mod(obj.numEpochsPrepared, nchoosek(obj.numberOfPositions, obj.paired + 1));
            if index == 0
                obj.positions = obj.positions(randperm(nchoosek(obj.numberOfPositions, obj.paired + 1)),:);
            end
            obj.bar1Position = obj.positions(index+1,1);
            epoch.addParameter('bar1Position', obj.bar1Position);
            if obj.paired                
                obj.bar2Position = obj.positions(index+1,2);
                epoch.addParameter('bar2Position', obj.bar2Position);
            else
                epoch.addParameter('bar2Position', obj.bar1Position);
            end


            % every nchoose2 * numberOfAngles trials, shuffle the angles
            index = mod(obj.numEpochsPrepared, obj.numberOfAngles * nchoosek(obj.numberOfPositions, obj.paired + 1));
            if index == 0
                obj.angles = obj.angles(randperm(obj.numberOfAngles));
            end

            obj.barAngle = obj.angles(floor(index / nchoosek(obj.numberOfPositions, obj.paired + 1))+1);

            epoch.addParameter('barAngle', obj.barAngle);
            
            epoch.addParameter('delay', 0); %TODO: implement this

            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfAngles * nchoosek(obj.numberOfPositions, obj.paired + 1);
        end
        
        function stimTime = get.stimTime(obj)
            stimTime = obj.barDuration;
        end

    end
    
end

