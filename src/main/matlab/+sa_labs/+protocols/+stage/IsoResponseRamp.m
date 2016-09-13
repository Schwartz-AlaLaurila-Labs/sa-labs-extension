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
        epochIndex = 0
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'epochIndex';
    end
    
    
    properties (Transient, Hidden)
        isoResponseFigure
    end
    
    
    methods
        
        function prepareRun(obj)
            obj.epochIndex = 0;
            
            % make device list for figure
            devices = {};
            for ci = 1:4
                ampName = obj.(['chan' num2str(ci)]);
                if ~strcmp(ampName, 'None');
                    device = obj.rig.getDevice(ampName);
                    devices{end+1} = device; %#ok<AGROW>
                end
            end            
            warning('off','MATLAB:structOnObject')
            propertyStruct = struct(obj);            
            obj.isoResponseFigure = obj.showFigure('sa_labs.figures.IsoResponseFigure', devices, ...
                propertyStruct,...
                'isoResponseMode','continuousRelease',...
                'responseMode',obj.chan1Mode,... % TODO: different modes for multiple amps
                'spikeThresholdVoltage', obj.spikeThresholdVoltage);
            
            prepareRun@sa_labs.protocols.StageProtocol(obj);
        end
        
        function prepareEpoch(obj, epoch)
            obj.epochIndex = obj.epochIndex + 1;
            
            if obj.epochIndex > 1
                obj.rampPointsTime = obj.isoResponseFigure.nextRampPointsTime;
                obj.rampPointsIntensity = obj.isoResponseFigure.nextRampPointsIntensity;
            end
                
            epoch.addParameter('epochIndex', obj.epochIndex);
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