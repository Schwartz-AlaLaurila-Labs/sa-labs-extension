classdef IVCurve < sa_labs.protocols.StageProtocol
        
    properties
        
        preTime = 250	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 250	% Spot trailing duration (ms)
        
        %mean (bg) and amplitude of pulse
        intensity = 0.5; %make it contrast instead?
        
        spotSize = 200; %microns
        
        holdSignalMin = -100 %mV
        holdSignalMax = 40; %mV
        numberOfHoldSignalSteps = 10;
        
        numberOfCycles = 2;
        
        numberOfAmpsToUse = 1;
    end
    
    properties (Hidden)
        holdValues
        curHoldValue
        version = 2
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = '';
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
            if index == 1
                obj.holdValues = obj.holdValues(randperm(obj.numberOfHoldSignalSteps)); 
            end
                        
            %get current position
            obj.curHoldValue = obj.holdValues(index);
            epoch.addParameter('holdSignal', obj.curHoldValue);
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
            % Set amp hold signal.
            for ci = 1:obj.numberOfAmpsToUse
                channelName = sprintf('chan%d', ci);
%                 modeName = sprintf('chan%dMode', ci);
                holdName = sprintf('chan%dHold', ci);
                signal = obj.(holdName);
                
                if strcmp(obj.(channelName),'None')
                    continue
                end
                ampName = obj.(channelName);
                device = obj.rig.getDevice(ampName);
                
                device.background = symphonyui.core.Measurement(signal, device.background.displayUnits);
                device.applyBackground();
            end
        end
        
        function preparePresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
                                    
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            spot.color = obj.intensity;
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