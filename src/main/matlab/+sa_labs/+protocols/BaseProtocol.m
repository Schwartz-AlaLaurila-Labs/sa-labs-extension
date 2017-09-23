classdef (Abstract) BaseProtocol < symphonyui.core.Protocol
    
    % This class handles protocol control which is not visual stimulus
    % specific. The assumptions are following,
    %   - It can handle upto 4 different amplifier channels
    %   - It strongly relies on logical naming of the amplifier channels
    %   @see chan1, etc
    
    properties
        chan1 = 'Amp1';                 % Wired to MultiClamp(1)/AxoClamp(1) channel 1, Logical naming 'Amp1'
        chan1Mode = 'Cell attached'     % Recording mode for 'Amp1'
        chan1Hold = 0                   % Holding potential for 'Amp1'
        chan2 = 'None';                 % Wired to MultiClamp(1)/AxoClamp(1) channel 2, Logical naming 'Amp2'
        chan2Mode = 'Off'               % Recording mode for 'Amp2'
        chan2Hold = 0                   % Holding potential for 'Amp2'
        chan3  = 'None';                % Wired to MultiClamp(2)/AxoClamp(2) channel 1, Logical naming 'Amp3'
        chan3Mode = 'Off'               % Recording mode for 'Amp3'
        chan3Hold = 0                   % Holding potential for 'Amp3'
        chan4  = 'None';                % Wired to MultiClamp(2)/AxoClamp(2) channel 2, Logical naming 'Amp4'
        chan4Mode = 'Off'               % Recording mode for 'Amp4'
        chan4Hold = 0                   % Holding potential for 'Amp4'
        spikeDetectorMode = 'advanced'; % Online spike detection mode
        spikeThreshold = -6             % Spike detection threshold (pA) or (pseudo-)std
        stageX                          % X co-ordinates of stage
        stageY                          % Y co-ordinates of stage
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
            
            obj.showFigure(class, device, ...
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
        
        function completeRun(obj)
            completeRun@symphonyui.core.Protocol(obj);
        end
        
        function n = addRunningEpochNumber(obj)
            p = obj.persistor;
            try
                n = p.currentEpochGroup.source.getProperty('epochsRecorded') + 1;
                p.currentEpochGroup.source.setProperty('epochsRecorded', n);
            catch exception %#ok
                n = 1;
                p.currentEpochGroup.source.addProperty('epochsRecorded', n);
            end
            
        end
        
        function n = addRunningEpochNumberByExperiment(obj)
            p = obj.persistor;
            try
                n = p.experiment.getProperty('totalEpochsRecorded') + 1;
                p.experiment.setProperty('totalEpochsRecorded', n);
            catch exception %#ok
                n = 1;
                p.experiment.addProperty('totalEpochsRecorded', n);
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
        
        function tf = hasValidPersistor(obj)
            p = obj.persistor;
            tf =  ~ isempty(p) && ~ isempty(p.currentEpochBlock);
        end
    end
    
    methods (Access = protected)
        
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
        
        % Only used in Test rig
        
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

