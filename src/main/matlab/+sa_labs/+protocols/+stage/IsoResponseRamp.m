classdef IsoResponseRamp < sa_labs.protocols.StageProtocol
    
    properties
        %times in ms
        preTime = 250	% Spot leading duration (ms)
        tailTime = 1000	% Spot trailing duration (ms)
        
        rampPointsTime = [0,2] % sec
        rampPointsIntensity = [0,1]
        exponentialMode = false; % Overwrites ramp points with an exponential curve, uses max value in the time vector
        exponentBase = 4; % higher number is sharper knee, later rise
        offPauseTime = 0.1; % sec, stays off for a moment each ramp to let current stabilize
        
        spotSize = 150; % um
        numRampsPerEpoch = 20;
        numberOfEpochs = 50;
    end
    
    properties (Hidden)
        version = 1
        epochIndex = 0
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'epochIndex';
    end
    
    
    properties (Transient, Hidden)
        isoResponseFigure
    end
    
    properties (Dependent)
        stimTime
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            obj.epochIndex = 0;
            
            % make device list for figure
            devices = {};
            for ci = 1:4
                ampName = obj.(['chan' num2str(ci)]);
                if ~strcmp(ampName, 'None')
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
            
            if obj.epochIndex == 1
                if obj.exponentialMode
                    endTime = max(obj.rampPointsTime);
                    expTime = 0:0.2:(endTime - obj.offPauseTime); %shorten by the dark pause time
                    obj.rampPointsIntensity = power(obj.exponentBase, expTime) - 1;
                    obj.rampPointsIntensity = obj.rampPointsIntensity / max(obj.rampPointsIntensity);
                    
                    % add the dark pause at the start
                    obj.rampPointsTime = horzcat(0, expTime + obj.offPauseTime);
                    obj.rampPointsIntensity = horzcat(0, obj.rampPointsIntensity);
                end
            
            else
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
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            function c = onDuringStim(state)
                if state.time>obj.preTime*1e-3 && state.time<=(obj.preTime+obj.stimTime)*1e-3
                    t = state.time - obj.preTime/1000;
                    t = mod(t, max(obj.rampPointsTime));
                    value = interp1(obj.rampPointsTime, obj.rampPointsIntensity, t, 'linear', 0);
                    c = obj.meanLevel + (value / (1-obj.meanLevel)); % keep it always ramping to 1.0 no matter the meanLevel
                else
                    c = obj.meanLevel;
                end
                if c > 1
                    c = 1;
                end
                if c < 0
                    c = 0;
                end
            end
            

        
            controller = stage.builtin.controllers.PropertyController(spot, 'color', @(s)onDuringStim(s));
            p.addController(controller);
            
        end
        
        function stimTime = get.stimTime(obj)
            stimTime = obj.numRampsPerEpoch * max(obj.rampPointsTime) * 1000;
        end
            
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
            
        end
        
    end