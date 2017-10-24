classdef SplitField < sa_labs.protocols.StageProtocol

    properties
        
        %times in ms
        preTime = 500 %will be rounded to account for frame rate
        tailTime = 250; %will be rounded to account for frame rate
        stimTime = 500;
        
        contrast = 0.5

        numberOfPositions = 9;
        barSeparation = 10; %microns
        
        numberOfAngles = 2;
        angleOffset = 0;
        barWidth = 3000; %microns
        barLength = 3000; %microns
        
        numberOfCycles = 3  % Number of times through the set
        
    end
    
    properties (Hidden)
        version = 1        
        curPosX
        curPosY   
        curStep
        curAngle
        stepList
        blackSideList
        angleList
        curBlackSide %0 = negative position side, 1 = positive position side

        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'barStep';       
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end    
    
    methods
        
        
        function prepareRun(obj)
            % Call the base method.
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            %set positions
            firstStep =  -floor(obj.numberOfPositions/2) * obj.barSeparation;          
            steps = firstStep:obj.barSeparation:firstStep+(obj.numberOfPositions-1)*obj.barSeparation;
            %these are the step distances from center
            
            %set angles
            angles = mod(round(0:180/obj.numberOfAngles:(180-.01)) + obj.angleOffset, 180);
            numberOfConditions = obj.numberOfAngles * obj.numberOfPositions * 2;
            %make the list of positions and angles and randomize
            z = 1;
            for i=1:obj.numberOfCycles
                R = randperm(numberOfConditions);
                for j=1:numberOfConditions
                    stepList_temp(z) = steps(rem(R(j), obj.numberOfPositions) + 1);
                    angleList_temp(z) = angles(rem(R(j), obj.numberOfAngles) + 1);
                    blackSideList_temp(z) = R(j) < numberOfConditions/2;
                    z=z+1;
                end
            end
                        
            obj.stepList = stepList_temp;
            obj.angleList = angleList_temp;
            obj.blackSideList = blackSideList_temp;

            
        end
        
        function prepareEpoch(obj, epoch)
            
            %current step and angle
            obj.curStep = obj.stepList(obj.numEpochsPrepared+1);
            obj.curAngle = obj.angleList(obj.numEpochsPrepared+1);
            obj.curBlackSide = obj.blackSideList(obj.numEpochsPrepared+1);

            %get current position
            obj.curPosX = obj.curStep * cosd(obj.curAngle);
            obj.curPosY = obj.curStep * sind(obj.curAngle);
            
            epoch.addParameter('positionX', obj.curPosX);
            epoch.addParameter('positionY', obj.curPosY);
            epoch.addParameter('barAngle', obj.curAngle);
            epoch.addParameter('barStep', obj.curStep);
            epoch.addParameter('blackSide', obj.curBlackSide);
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
                                    
            barOffsetFromCenter = [obj.barWidth * cosd(obj.curAngle), obj.barLength * sind(obj.curAngle)] / 2;
            barOffsetFromCenterPx = obj.um2pix(barOffsetFromCenter);
            curPosPx = obj.um2pix([obj.curPosX, obj.curPosY]);
            
            rect1 = stage.builtin.stimuli.Rectangle();
            rect1.size = [obj.um2pix(obj.barWidth), obj.um2pix(obj.barLength)];         
            rect1.position = canvasSize / 2 + curPosPx - barOffsetFromCenterPx;
            rect1.orientation = obj.curAngle;
            p.addStimulus(rect1);
            
            rect2 = stage.builtin.stimuli.Rectangle();
            rect2.size = [obj.um2pix(obj.barWidth), obj.um2pix(obj.barLength)];
            rect2.position = canvasSize / 2 + curPosPx + barOffsetFromCenterPx;
            rect2.orientation = obj.curAngle;
            p.addStimulus(rect2);
            
            function c = onDuringStim(state, preTime, stimTime, contrast, meanLevel)
                if state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3
                    c = meanLevel + meanLevel * contrast;
                else
                    c = meanLevel;
                end
            end
            
            
            if obj.curBlackSide
                controller1 = stage.builtin.controllers.PropertyController(rect2, 'color', @(s)onDuringStim(s, obj.preTime, obj.stimTime, obj.contrast, obj.meanLevel));
                controller2 = stage.builtin.controllers.PropertyController(rect1, 'color', @(s)onDuringStim(s, obj.preTime, obj.stimTime, -obj.contrast, obj.meanLevel));
            else
                controller1 = stage.builtin.controllers.PropertyController(rect1, 'color', @(s)onDuringStim(s, obj.preTime, obj.stimTime, obj.contrast, obj.meanLevel));
                controller2 = stage.builtin.controllers.PropertyController(rect2, 'color', @(s)onDuringStim(s, obj.preTime, obj.stimTime, -obj.contrast, obj.meanLevel));
            end
            
            p.addController(controller1);    
            p.addController(controller2);    

        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfAngles * obj.numberOfPositions * 2; %2 is for On and Off contrast flip
        end   
        

    end
    
end