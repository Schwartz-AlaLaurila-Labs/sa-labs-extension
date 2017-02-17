classdef DriftingGratings < sa_labs.protocols.StageProtocol
    
    properties
        %times in ms
        preTime = 250; %ms
        tailTime = 250; %ms
        stimTime = 5000; %ms
        
        movementDelay = 200;
        
        %in microns, use rigConfig to set microns per pixel
        gratingWidth = 3000; %um
        gratingLength = 3000; %um
        gratingSpeed = 1200; %um/s
        cycleHalfWidth = 300; %um
        apertureDiameter = 0; %um, pos: gratings in center, neg: gratings outside center
        gratingProfile = 'square'; %sine, square, or sawtooth
        contrast = 1;
        
        numberOfAngles = 12;
        numberOfCycles = 2;
    end
    
    properties (Dependent)
        spatialFreq %cycles/degree
        temporalFreq %cycles/s (Hz)
        totalNumEpochs
    end
    
    properties (Hidden)
        version = 4
        curAngle
        angles
        gratingProfileType = symphonyui.core.PropertyType('char', 'row', {'sine', 'square', 'sawtooth'})
   
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'gratingAngle';
    end
    
    methods
        
        function prepareRun(obj)
            % Call the base method.
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            %set directions
            obj.angles = rem(0:round(360/obj.numberOfAngles):359, 360);
            
        end
        
        function prepareEpoch(obj, epoch)
            % Randomize angles if this is a new set
            index = mod(obj.numEpochsPrepared, obj.numberOfAngles);
            if index == 0
                obj.angles = obj.angles(randperm(obj.numberOfAngles));
            end
            
            obj.curAngle = obj.angles(index+1); %make it a property so preparePresentation has access to it
            epoch.addParameter('gratingAngle', obj.curAngle);
            epoch.addParameter('anglesLikeMovingBar',1);
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);            
        end
        
        function p = createPresentation(obj)
            centerPos = obj.rig.getDevice('Stage').getCanvasSize() / 2;
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            grat = stage.builtin.stimuli.Grating(obj.gratingProfile, 1024);
            grat.position = [0,0];
            grat.orientation = obj.curAngle;
            grat.contrast = obj.contrast;
            grat.size = round(obj.um2pix([obj.gratingLength, obj.gratingWidth]));
            grat.spatialFreq = obj.um2pix(1)/(2*obj.cycleHalfWidth);
            grat.phase = 0;
            p.addStimulus(grat);
            %             pixelSpeed = obj.gratingSpeed./obj.rigConfig.micronsPerPixel;
            
            % only gratings in center
            if obj.apertureDiameter > 0
                apertureDiameterRel = obj.apertureDiameter / max(obj.gratingLength, obj.gratingWidth);
                mask = stage.core.Mask.createAnnulus(-1, apertureDiameterRel, 2048);
                grat.setMask(mask);
            end
            
            % only gratings outside center
            if obj.apertureDiameter < 0
                apertureDiameterRel = -1 * obj.apertureDiameter / max(obj.gratingLength, obj.gratingWidth);
                mask = stage.core.Mask.createAnnulus(apertureDiameterRel, 10, 2048);
                grat.setMask(mask);
            end
            
            % Gratings drift controller
            function pos = posController(state, duration, preTime, tailTime, centerPos)
                if state.time<=preTime/1E3 || state.time>duration-tailTime/1E3 %in pre or tail time
                    %off screen
                    pos = [NaN, NaN];
                else
                    %on screen
                    pos = centerPos;
                end
            end
            posControllerFunc = stage.builtin.controllers.PropertyController(grat, 'position', @(s)posController(s, p.duration, obj.preTime, obj.tailTime, centerPos));
            p.addController(posControllerFunc);
            
            function phase = phaseController(state, startMovementTime, temporalFreq)
                
                if state.time > startMovementTime
                    phase = -360 * (state.time - startMovementTime) * temporalFreq;
                else
                    phase = 0;
                end
            end
            startMovementTime = (obj.preTime/1E3 + obj.movementDelay/1E3);
            tf = obj.gratingSpeed/(2*obj.cycleHalfWidth);
            phaseControllerFunc = stage.builtin.controllers.PropertyController(grat, 'phase', @(state)phaseController(state, startMovementTime, tf));
            p.addController(phaseControllerFunc);
            
            %             obj.addFrameTracker(p);
        end
                
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfAngles;
        end
        
        function spatialFreq = get.spatialFreq(obj)
            % 1 deg visual angle = 30um (mouse retina)
            micronperdeg = 30;
            spatialFreq = micronperdeg/(2*obj.cycleHalfWidth);
        end
        
        function temporalFreq = get.temporalFreq(obj)
            temporalFreq = obj.gratingSpeed/(2*obj.cycleHalfWidth);
        end
        
        
    end
    
end