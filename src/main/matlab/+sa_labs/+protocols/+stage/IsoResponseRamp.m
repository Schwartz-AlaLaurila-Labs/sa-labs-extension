classdef IsoResponseRamp < sa_labs.protocols.StageProtocol

    properties
        %times in ms
        preTime = 250	% Spot leading duration (ms)
        stimTime = 2000	% Spot duration (ms)
        tailTime = 500	% Spot trailing duration (ms)
        
        rampPointsTime = [0,1.0,2.0]
        rampPointsIntensity = [0,.2,1]
        
        spotSize = 150; % um
        numberOfEpochs = 50;
    end
    
    properties (Hidden)
        version = 1
        displayName = 'IsoResponse Ramp'
        epochNum = 0
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'epochNum';
    end
    
    methods
        
        function prepareRun(obj)
            obj.epochNum = 0;
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
        end
        
        function prepareEpoch(obj, epoch)
            obj.epochNum = obj.epochNum + 1;
            epoch.addParameter('epochNum', obj.epochNum);
            epoch.addParameter('rampPointsTime', obj.rampPointsTime);
            epoch.addParameter('rampPointsIntensity', obj.rampPointsIntensity);
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
      
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

            %set bg
            p.setBackgroundColor(obj.meanLevel);
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            %spot.color = obj.intensity;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            function c = onDuringStim(state, preTime, stimTime, meanLevel,rampPointsTime,rampPointsIntensity)
                if state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3
                    
                    value = interp1(rampPointsTime, rampPointsIntensity, state.time, 'linear', 0);
                    c = meanLevel + value;
                else
                    c = meanLevel;
                end
                if c > 1
                    c = 1;
                end
                if c < 0
                    c = 0;
                end
            end
            
            controller = stage.builtin.controllers.PropertyController(spot, 'color', @(s)onDuringStim(s, obj.preTime, obj.stimTime, obj.meanLevel,obj.rampPointsTime, obj.rampPointsIntensity));
            p.addController(controller);

        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfEpochs;
        end

    end
    
end