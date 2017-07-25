classdef (Abstract) BaseProtocol < symphonyui.core.Protocol
    
    % This class handles protocol control which is not visual stimulus specific
    
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
    end
    
    properties (Transient, Hidden)
        responseFigure
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
        spikeDetectorModeType = symphonyui.core.PropertyType('char', 'row', {'advanced', 'Simple Threshold', 'Filtered Threshold', 'none'});
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@symphonyui.core.Protocol(obj);
            
            ampDeviceNames = obj.rig.getDeviceNames('Amp');
            
            % Initialize chanTypes with 'None' & Amp device name if exist
            % Like {'None, Amp1', 'None, Amp2'} .. etc

            channelTypes = cell(1, 4);
            channelTypes(:) = {'None'};
            for i = 1 : numel(ampDeviceNames)
                channelTypes{i} = strcat(channelTypes{i}, ',', ampDeviceNames{i});
            end
            
            obj.chan1Type = symphonyui.core.PropertyType('char', 'row', strsplit(channelTypes{1}, ','));
            obj.chan2Type = symphonyui.core.PropertyType('char', 'row', strsplit(channelTypes{2}, ','));
            obj.chan3Type = symphonyui.core.PropertyType('char', 'row', strsplit(channelTypes{3}, ','));
            obj.chan4Type = symphonyui.core.PropertyType('char', 'row', strsplit(channelTypes{4}, ','));
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
                dependent = getPropertyDescriptor@symphonyui.core.Protocol(obj, name(1:5));
                d.isHidden =  numel(dependent.type.domain) < 2;
            end
        end
        
        function prepareRun(obj, setAmpHoldSignals)
            prepareRun@symphonyui.core.Protocol(obj);
            
            if nargin < 2 || setAmpHoldSignals
                obj.applyBackground();
            end
            
            % make device list for analysis figure
            if obj.isPlotEnabled()
                for i = 1 : 4
                    channelProperty = strcat('chan', num2str(i));
                    if obj.isChannelActive(channelProperty)
                        device = obj.rig.getDevice(obj.(channelProperty));
                        class = strcat('sa_labs.figures.ResponseAnalysisFigure', num2str(i));
                        obj.createResponseFigure(class, {device}, obj.([channelProperty 'Mode']));
                    end
                end
            end
        end
        
        function createResponseFigure(obj, class, device, mode)
            
            obj.responseFigure = obj.showFigure(class, device, ...
                'activeFunctionNames', {'mean'}, ...
                'totalNumEpochs', obj.totalNumEpochs,...
                'epochSplitParameter', obj.responsePlotSplitParameter,...
                'plotMode', obj.responsePlotMode,...
                'analysisRegion', 1e-3 * [obj.preTime, obj.preTime + obj.stimTime + 0.5],...
                'responseMode', mode,...
                'spikeThreshold', obj.spikeThreshold, ...
                'spikeDetectorMode', obj.spikeDetectorMode);
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@symphonyui.core.Protocol(obj, epoch);
            
            epoch.addParameter('symphonyVersion', 2);
            if isprop(obj, 'version')
                epoch.addParameter('protocolVersion', obj.version);
            end
            
            for i = 1:4
                channelProperty = strcat('chan', num2str(i));
                if obj.isChannelActive(channelProperty)
                    ampDevice = obj.rig.getDevice(obj.(channelProperty));
                    epoch.addResponse(ampDevice);
                end
            end
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.totalNumEpochs;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.totalNumEpochs;
        end
        
        function tf= isChannelActive(obj, channelProperty)
            ampName = obj.(channelProperty);
            ampMode = obj.([channelProperty 'Mode']);
            tf = ~ (strcmp(ampName, 'None') || strcmp(ampMode, 'Off'));
        end
        
        function tf = isPlotEnabled(obj)
            if islogical(obj.responsePlotMode)
                tf = obj.responsePlotMode;
            else
                tf = ~ strcmpi(obj.responsePlotMode, 'false');
            end
        end
    end
    
    methods (Access = private)
        
        function applyBackground(obj)
            for ci = 1:4
                channelName = sprintf('chan%d', ci);
                holdName = sprintf('chan%dHold', ci);
                newBackground = obj.(holdName);
                
                if strcmp(obj.(channelName), 'None')
                    continue
                end
                ampName = obj.(channelName);
                device = obj.rig.getDevice(ampName);
                prevBackground = device.background;
                
                device.background = symphonyui.core.Measurement(newBackground, device.background.displayUnits);
                device.applyBackground();
                
                if prevBackground.quantity ~= newBackground
                    pause(5);
                end
            end
        end
    end
    
    methods
        
        % Only used in test rig
        
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

