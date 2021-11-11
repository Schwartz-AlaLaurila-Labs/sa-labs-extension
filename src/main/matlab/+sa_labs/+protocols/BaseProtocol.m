classdef (Abstract) BaseProtocol < symphonyui.core.Protocol
% this class handles protocol control which is not visual stimulus specific

    properties
        chan1 = 'Amp1';
        chan1Mode = 'Cell attached'
        chan1Hold = 0
        
        chan2 = 'None';
        chan2Mode = 'Off'
        chan2Hold = 0
        
        chan3  = 'None';
        chan3Mode = 'Off'
        chan3Hold = 0
        
        chan4  = 'None';
        chan4Mode = 'Off'
        chan4Hold = 0
        
        spikeDetectorMode = 'advanced';
        spikeThreshold = -6 % pA or (pseudo-)std
        
        scanHeadTrigger = false; %scanhead trigger for function imaging, added by Greg 3/5/18
        stimTimeRecord = false;
    end
    
    properties (Transient, Hidden)
        responseFigure
        devices % For figures

    end
    
    properties (Abstract)
        preTime
        stimTime
        tailTime
        responsePlotMode
    end
    
    properties(Hidden)
        chan1Type
        chan2Type
        chan3Type
        chan4Type
        chan1ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell'});
        chan2ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell','Off'});
        chan3ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell','Off'});
        chan4ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell','Off'});
        ampList
        
        spikeDetectorModeType = symphonyui.core.PropertyType('char', 'row', {'advanced', 'Simple Threshold', 'Filtered Threshold', 'none'});
        
        wholeCellRecordingMode_Ch1
        wholeCellRecordingMode_Ch2
        wholeCellRecordingMode_Ch3
        wholeCellRecordingMode_Ch4
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@symphonyui.core.Protocol(obj);
            
            obj.ampList = horzcat({'None'}, obj.rig.getDeviceNames('Amp'));
            
            obj.chan1Type = symphonyui.core.PropertyType('char', 'row', obj.ampList(2:end)); % first channel should always be filled
            obj.chan2Type = symphonyui.core.PropertyType('char', 'row', obj.ampList);
            obj.chan3Type = symphonyui.core.PropertyType('char', 'row', obj.ampList);
            obj.chan4Type = symphonyui.core.PropertyType('char', 'row', obj.ampList);
            

        end

        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@symphonyui.core.Protocol(obj, name);        
            
            switch name
                case {'numberOfCycles','numberOfEpochs','ndfs'}
                    d.category = '1 Basic';
                case {'stimTime','preTime','tailTime'}
                    d.category = '2 Timing';
                case {'sampleRate', 'spikeThreshold','spikeDetectorMode'}
                    d.category = '9 Amplifiers';
                otherwise
                    d.category = '4 Protocol';
            end
            
            if strncmp(name, 'chan', 4)
                d.category = '9 Amplifiers';
                if str2double(name(5)) > (length(obj.ampList) - 1)
                    d.isHidden = true;
                end
            end
        end 
        
        
        function prepareRun(obj, setAmpHoldSignals)
            prepareRun@symphonyui.core.Protocol(obj);

            % TODO: check that two channels don't use the same amp (makes settings collision)

%             Set amp hold signals.
            if nargin < 2
                setAmpHoldSignals = true;
            end
            if setAmpHoldSignals
                for ci = 1:4
                    channelName = sprintf('chan%d', ci);
    %                 modeName = sprintf('chan%dMode', ci);
                    holdName = sprintf('chan%dHold', ci);
                    newBackground = obj.(holdName);

                    if strcmp(obj.(channelName),'None')
                        continue
                    end
                    ampName = obj.(channelName);
                    device = obj.rig.getDevice(ampName);
                    prevBackground = device.background;

                    device.background = symphonyui.core.Measurement(newBackground, device.background.displayUnits);
                    device.applyBackground();
                    
                    if prevBackground ~= newBackground
                        pause(5);
                    end
                end
            end

            % make device list for analysis figure
            obj.devices = {};
            for ci = 1:4
                ampName = obj.(['chan' num2str(ci)]);
                ampMode = obj.(['chan' num2str(ci) 'Mode']);
                if ~(strcmp(ampName, 'None') || strcmp(ampMode, 'Off'));
                    device = obj.rig.getDevice(ampName);
                    obj.devices{end+1} = device; %#ok<AGROW>
                end
            end
            
            if obj.responsePlotMode ~= false
                obj.responseFigure = obj.showFigure('sa_labs.figures.ResponseAnalysisFigure', obj.devices, ...
                    'activeFunctionNames', {'mean'}, ...
                    'totalNumEpochs',obj.totalNumEpochs,...
                    'epochSplitParameter',obj.responsePlotSplitParameter,...
                    'plotMode',obj.responsePlotMode,... 
                    'analysisRegion', 1e-3 * [obj.preTime, obj.preTime + obj.stimTime + 0.5],...
                    'responseMode',obj.chan1Mode,... % TODO: different modes for multiple amps
                    'spikeThreshold', obj.spikeThreshold, ...
                    'spikeDetectorMode', obj.spikeDetectorMode);
            end
            
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@symphonyui.core.Protocol(obj, epoch);
            
            epoch.addParameter('symphonyVersion', 2);
            if isprop(obj, 'version')
                epoch.addParameter('protocolVersion', obj.version);
            end
            
            for ci = 1:4
                ampName = obj.(['chan' num2str(ci)]);
                ampMode = obj.(['chan' num2str(ci) 'Mode']);
                
                if strcmp(ampName, 'None') || strcmp(ampMode, 'Off')
                   continue
                end
                ampDevice = obj.rig.getDevice(ampName);
                epoch.addResponse(ampDevice);
                if strcmp(ampMode, 'Whole cell')
                    if strcmp(obj.rig.getDevice(ampName).background.displayUnits, 'mV')
                        epoch.addParameter(sprintf('wholeCellRecordingMode_Ch%g', ci), 'Vclamp');
                    else
                        epoch.addParameter(sprintf('wholeCellRecordingMode_Ch%g', ci), 'Iclamp');
                    end
                end
                epoch.addResponse(obj.rig.getDevice('Bath Temperature'));
                epoch.addResponse(obj.rig.getDevice('Bath Temperature Control'));
                
            end
            
            %scanhead trigger for function imaging, added by Greg 3/5/18
            if obj.scanHeadTrigger
                disp('Making scanhead trigger stim');
                %p = symphonyui.builtin.stimuli.PulseTrainGenerator();
                p = symphonyui.builtin.stimuli.PulseGenerator();
                
                p.preTime = obj.preTime; %trigger at start of stimTime
                p.stimTime = 5;
                %p.pulseTime = 1; %ms
                %p.intervalTime = obj.preTime;
                p.tailTime = obj.stimTime + obj.tailTime - p.stimTime;
                %p.tailTime = obj.tailTime + obj.stimTime - 2;
                p.amplitude = 1;
                p.mean = 0;
                %p.numPulses = 1;
                p.sampleRate = obj.sampleRate;
                p.units = Symphony.Core.Measurement.UNITLESS;
                
                triggers = obj.rig.getDevices('Scanhead Trigger');
                if ~isempty(triggers)
                    epoch.addStimulus(triggers{1},  p.generate());
                else
                    disp('no scanhead trigger device found')
                end
            end
            
            % added by Sophia 3/4/21, digital stim time signal
            if obj.stimTimeRecord
                p = symphonyui.builtin.stimuli.PulseGenerator();
                
                p.preTime = obj.preTime; %trigger at start of pretime and end of stimtime
                p.stimTime = obj.stimTime;
                p.tailTime = obj.tailTime;
                p.amplitude = 1;
                p.mean = 0;
                p.sampleRate = obj.sampleRate;
                p.units = Symphony.Core.Measurement.UNITLESS;
                
                triggers = obj.rig.getDevices('Stim Time Recorder');
                if ~isempty(triggers)
                    epoch.addStimulus(triggers{1},  p.generate());
                else
                    disp('no stim time trigger device found')
                end
            end
            
            name = obj.rig.getDeviceNames('LED_blanking_signal');       
            if ~isempty(name)
                D = obj.rig.getDevice('LED_blanking_signal');
                epoch.addResponse(D);
            end
                                    
        end
        
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.totalNumEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.totalNumEpochs;
        end
        
        function addGaussianLoopbackSignals(obj, epoch)
            % make fake input data via loopback
            for ci = 1:4
                if strcmp(obj.(['chan' num2str(ci)]), 'None')
                   continue
                end
                device = obj.rig.getDevice(obj.(['chan' num2str(ci)]));
                g = sa_labs.stimuli.GaussianNoiseGeneratorV2();
                g.freqCutoff = 100;
                g.numFilters = 1;
                g.stDev = 2;
                g.mean = 100;
                g.seed = randi(100000);
                g.preTime = obj.preTime;
                g.tailTime = obj.tailTime;
                g.stimTime = obj.stimTime;
                g.units = device.background.displayUnits;
                g.sampleRate = obj.sampleRate;
                epoch.addStimulus(device, g.generate());
            end

        end

    end
    
end

