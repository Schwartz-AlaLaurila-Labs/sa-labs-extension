classdef SplitField < sa_labs.protocols.StageProtocol

    properties
        
        %times in ms
        preTime = 500 %will be rounded to account for frame rate
        tailTime = 500; %will be rounded to account for frame rate
        stimTime = 1000;
        
        contrast = 0.3

        Npositions = 2;
        barSeparation = 20; %microns
        
        Nangles = 2;
        barWidth = 1500; %microns
        barLength = 3000; %microns
        
        numberOfCycles = 3              % Number of times through the set
        
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
       
    end
    
    properties (Dependent)
        Nconditions
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end    
    
    methods
        
        
        function prepareRun(obj)
            % Call the base method.
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            %set positions
            pixelStep = round(obj.barSeparation / obj.rigConfig.micronsPerPixel);           
            firstStep =  -floor(obj.Npositions/2) * pixelStep;          
            steps = firstStep:pixelStep:firstStep+(obj.Npositions-1)*pixelStep;  
            %these are the step distances from center
            
            %set angles
            angles = round(0:180/obj.Nangles:179); %degrees
            
            %make the list of positions and angles and randomize
            z = 1;
            for i=1:obj.numberOfCycles
                R = randperm(obj.Nconditions);
                for j=1:obj.Nconditions
                    stepList_temp(z) = steps(rem(R(j), obj.Npositions) + 1);
                    angleList_temp(z) = angles(rem(R(j), obj.Nangles) + 1);
                    blackSideList_temp(z) = R(j)<obj.Nconditions/2;
                    z=z+1;
                end
            end
                        
            obj.stepList = stepList_temp(1:obj.numberOfAverages);
            obj.angleList = angleList_temp(1:obj.numberOfAverages);
            obj.blackSideList = blackSideList_temp(1:obj.numberOfAverages);

            
        end
        
        function prepareEpoch(obj, epoch)
            
           
            %current step and angle
            obj.curStep = obj.stepList(obj.numEpochsQueued+1);
            obj.curAngle = obj.angleList(obj.numEpochsQueued+1);
            obj.curBlackSide = obj.blackSideList(obj.numEpochsQueued+1);

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
                                    
            barOffset = [obj.barWidth * cosd(obj.curAngle), obj.barLength * sind(obj.curAngle)];
            barOffsetPx = obj.um2pix(barOffset);
            curPosPx = obj.um2pix([obj.curPosX, obj.curPosY]);
            
            rect1 = stage.builtin.stimuli.Rectangle();
            rect1.size = [obj.um2pix(obj.barWidth), obj.um2pix(obj.barLength)];         
            rect1.position = canvasSize / 2 + curPosPx - barOffsetPx;
            rect1.orientation = obj.curAngle;
            p.addStimulus(rect1);
            
            rect2 = stage.builtin.stimuli.Rectangle();
            rect2.size = [obj.um2pix(obj.barWidth), obj.um2pix(obj.barLength)];
            rect2.position = canvasSize / 2 + curPosPx + barOffsetPx;
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
            totalNumEpochs = obj.numberOfCycles * obj.Nangles * obj.Npositions * 2; %2 is for On and Off contrast flip
        end   
        

    end
    
end