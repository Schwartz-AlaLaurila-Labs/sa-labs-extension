classdef IVCurve < sa_labs.protocols.StageProtocol
        
    properties
        
        preTime = 500	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 1000	% Spot trailing duration (ms)
        
        %mean (bg) and amplitude of pulse
        intensity = 1; 
        
        spotSize = 160; %microns
        
        holdSignalMin = -80 %mV
        holdSignalMax = 40; %mV
        numberOfHoldSignalSteps = 8;
        
        numberOfCycles = 3;
        
        numberOfAmpsToUse = 1;
    end
    
    properties (Hidden)
        holdValues
        curHoldValue
        version = 2
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'holdSignal';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods

        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj, false);
            
            %set hold values
            obj.holdValues = linspace(obj.holdSignalMin, obj.holdSignalMax, obj.numberOfHoldSignalSteps);
            disp(['Hold values are: ' num2str(obj.holdValues)])
        end
        
        function prepareEpoch(obj, epoch)
            % Randomize sizes if this is a new set
            index = mod(obj.numEpochsPrepared, obj.numberOfHoldSignalSteps);
            if index == 0
                obj.holdValues = obj.holdValues(randperm(obj.numberOfHoldSignalSteps)); 
            end
                        
            %get current position
            obj.curHoldValue = obj.holdValues(index+1);
            epoch.addParameter('holdSignal', obj.curHoldValue);
            
            % Set amp hold signal.
            for ci = 1:obj.numberOfAmpsToUse
                channelName = sprintf('chan%d', ci);

                if strcmp(obj.(channelName),'None')
                    continue
                end
                ampName = obj.(channelName);
                device = obj.rig.getDevice(ampName);
                
                device.background = symphonyui.core.Measurement(obj.curHoldValue, device.background.displayUnits);
                device.applyBackground();
            end
            pause(2)
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
                                    
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            spot.color = obj.intensity;
            spot.opacity = 1;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            obj.setOnDuringStimController(p, spot);
            obj.setColorController(p, spot);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfHoldSignalSteps;
        end
        
    end
    
end