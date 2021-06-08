classdef CommonControl < symphonyui.ui.Module

    properties
        % projector
        offsetX = 0         % um
        offsetY = 0         % um
        backgroundSize      % um
        meanLevel = 0.0     % (0 - 1)
        
        NDF1 = 4             % Filter wheel position
        NDF2 = 4             % Filter wheel position
        frameRate = 60      % Hz
        patternRate = 60    % Hz
        blueLED = 20        % 0-255
        greenLED = 0        % 0-255
        
        spikeDetectorMode = 'Filtered Threshold'
        spikeThreshold = 22 % pA or std
        
        % Amplifiers
        chan1 = 'Amp1'
        chan1Mode = 'Cell attached'
        chan1Hold = 0
        
        chan2 = 'None'
        chan2Mode = 'Off'
        chan2Hold = 0
        
        chan3  = 'None'
        chan3Mode = 'Off'
        chan3Hold = 0
        
        chan4  = 'None'
        chan4Mode = 'Off'
        chan4Hold = 0
        applyToAllProtocol = false
        
        stageX = 0          % X co-ordinates of stage
        stageY = 0          % Y co-ordinates of stage
        settings
        log
        rstarPerSecond = 0
        rstarPerSecondText
    end
    
    properties(Hidden)
        
        projectorPropertyNames = {'rstarPerSecond', 'spikeThreshold','spikeDetectorMode', 'NDF1', 'NDF2', 'blueLED','greenLED','offsetX','offsetY', 'backgroundSize', 'meanLevel', 'stageX', 'stageY'};
        chan1Type
        chan2Type
        chan3Type
        chan4Type
        chan1ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell'});
        chan2ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell','Off'});
        chan3ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell','Off'});
        chan4ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell','Off'});
        
        spikeDetectorModeType = symphonyui.core.PropertyType('char', 'row', {'Simple Threshold', 'Filtered Threshold', 'none'});
        protocolPropertyGrid
        ampList
        rstarTable
        rstarMeta
        maxLedCurrent
    end
    
    methods (Access = protected)
        
        function willGo(obj)
            obj.updateDeviceList();
            obj.populateProtocolProperties();
            obj.loadRstarTable();
            try
                obj.loadSettings();
            catch x
                obj.log.debug(['Failed to load settings: ' x.message], x);
            end
        end
        
        function bind(obj)
            bind@symphonyui.ui.Module(obj);
            
            c = obj.configurationService;            
            obj.addListener(c, 'InitializedRig', @obj.onServiceInitializedRig);
            obj.addListener(obj.acquisitionService, 'SelectedProtocol', @obj.onServiceSelectedProtocol);
        end
        
        function willStop(obj)
            try
                obj.saveSettings();
            catch x
                obj.log.debug(['Failed to save settings: ' x.message], x);
            end
        end
    end
    
    methods
        
        function obj = CommonControl()
            obj.settings = sa_labs.modules.settings.CommonControlSettings();
            obj.log = log4m.LogManager.getLogger(class(obj));
        end
        
        function createUi(obj, figureHandle)
            import appbox.*;
            set(figureHandle, ...
                'Name', 'Common Control', ...
                'Position', appbox.screenCenter(270, 520));
            
            layout = uix.VBox( ...
                'Parent', figureHandle, ...
                'Padding', 11);
            
            rstarLayout = uix.Grid(...
                'Parent', layout, ...
                'Padding', 2);
            
            Label( ...
                'Parent', rstarLayout, ...
                'String', 'R*/rod/sec:');
            
            obj.rstarPerSecondText = uicontrol( ...
                'Parent', rstarLayout, ...
                'style', 'edit', ...
                'Callback',  @obj.onSetRstarPerSecond);
            
            set(rstarLayout, ...
                'Widths', [65], ...
                'Heights', [25]);
            
            obj.protocolPropertyGrid = uiextras.jide.PropertyGrid(layout);
            
            uicontrol( ...
                'Parent', layout, ...
                'Style', 'pushbutton', ...
                'String', 'Apply', ...
                'Callback', @obj.cbSetParameters);
            
            set(layout, 'Heights', [50, -1, 30]);
            obj.settings = sa_labs.modules.settings.CommonControlSettings();
        end
        
        function onServiceInitializedRig(obj, ~, ~)
            obj.updateDeviceList();
            obj.populateProtocolProperties();
        end
        
        function onServiceSelectedProtocol(obj, ~, ~)
            if obj.applyToAllProtocol
                obj.updateProtocolProperties();
            end
        end
        
        function updateDeviceList(obj)
            
            devices = obj.configurationService.getDevices('Amp');
            try
                lcr = obj.configurationService.getDevices('lightcrafter');
                obj.backgroundSize = lcr{1}.getBackgroundSizeInMicrons();
                obj.maxLedCurrent = lcr{1}.getConfigurationSetting('recommendedMaxLedCurrent');
            catch x 
                obj.log.debug(['Failed to get background size: ' x.message], x);
            end
            
            obj.ampList = {};
            for i = 1:length(devices)
                obj.ampList{i} = devices{i}.name;
            end
            
            % Initialize chanTypes with 'None' & Amp device name if exist
            % Like {'None, Amp1', 'None, Amp2'} .. etc
            
            channelTypes = cell(1, 4);
            channelTypes(:) = {'None'};
            for i = 1 : numel(obj.ampList)
                channelTypes{i} = strcat(channelTypes{i}, ',', obj.ampList{i});
            end
            
            obj.chan1Type = symphonyui.core.PropertyType('char', 'row', strsplit(channelTypes{1}, ','));
            obj.chan2Type = symphonyui.core.PropertyType('char', 'row', strsplit(channelTypes{2}, ','));
            obj.chan3Type = symphonyui.core.PropertyType('char', 'row', strsplit(channelTypes{3}, ','));
            obj.chan4Type = symphonyui.core.PropertyType('char', 'row', strsplit(channelTypes{4}, ','));
        end
        
        
        function cbSetParameters(obj, ~, ~)
            % set values in the protocol (callback on change settings in this module)
            obj.updateProtocolProperties();
        end
        
        function updateProtocolProperties(obj)
            
            propertyMap = containers.Map();
            rawProperties = get(obj.protocolPropertyGrid, 'Properties');
            
            for p = 1 : length(rawProperties)
                prop = rawProperties(p);
                
                if strcmp(prop.Name, 'applyToAllProtocol')
                    obj.applyToAllProtocol = prop.Value;
                else
                    propertyMap(prop.Name) = prop.Value;
                end
            end
            obj.acquisitionService.setProtocolPropertyMap(propertyMap);
        end
        
        function populateProtocolProperties(obj)
            
            numberOfActiveChannels = numel(obj.ampList);
            
            % usage:  ampParamGen('chan', 'Hold') returns chan1Hold,
            % chan2Hold if there exist two amplifier configuration
            
            ampParamGen = @(preFix, postFix) arrayfun(@(i) strcat(preFix, num2str(i), postFix), 1 : numberOfActiveChannels, 'UniformOutput', false);
            ampPropertynames = [ampParamGen('chan', ''), ampParamGen('chan', 'Hold'), ampParamGen('chan', 'Mode')];
            
            index = 0;
            n = numel(ampPropertynames) + numel(obj.projectorPropertyNames);
            descriptors = symphonyui.core.PropertyDescriptor.empty(0, n + 1);
            
            % set amplifer specific properties
            for i = 1 : numel(ampPropertynames)
                descriptors(i) = symphonyui.core.PropertyDescriptor.fromProperty(obj, ampPropertynames{i});
                descriptors(i).category = sprintf('Channel %s',ampPropertynames{i}(5));
                index = i;
            end
            
            % set projector specific properties
            for i = 1 : numel(obj.projectorPropertyNames)
                descriptors(index + i) = symphonyui.core.PropertyDescriptor.fromProperty(obj, obj.projectorPropertyNames{i});
                descriptors(index + i).category = 'Projector';
            end
            
            descriptors(n + 1) = symphonyui.core.PropertyDescriptor.fromProperty(obj, 'applyToAllProtocol');
            descriptors(n + 1).category = 'Protocol';
            
            fields = symphonyui.ui.util.desc2field(descriptors);
            set(obj.protocolPropertyGrid, 'Properties', fields);
        end
        
        function loadSettings(obj)
            if ~isempty(obj.settings.viewPosition)
                p1 = obj.view.position;
                p2 = obj.settings.viewPosition;
                obj.view.position = [p2(1) p2(2) p1(3) p1(4)];
            end
        end
        
        function saveSettings(obj)
            obj.settings.viewPosition = obj.view.position;
            obj.settings.save();
        end
        
        function loadRstarTable(obj)
            
            dataLocation = fileparts(which('aalto_rig_calibration_data_readme'));
            t = readtable(fullfile(dataLocation, 'rstar-table.csv'));
            obj.rstarTable =  t(t.Ledurrents <= obj.maxLedCurrent, :);
            rstarVars = obj.rstarTable.Properties.VariableNames;
            index = 1;
            
            for i =  1 : numel(obj.rstarTable.Properties.VariableNames)
                if(strfind(rstarVars{i}, 'ndf'))
                    splitValues = strsplit(rstarVars{i}, '_');
                    wheelOne = splitValues{2};
                    wheelTwo = splitValues{3};
                    metaData(index).columnName = rstarVars{i};
                    metaData(index).wheelOne = str2double(wheelOne(1));
                    metaData(index).wheelTwo = str2double(wheelTwo(1));
                    metaData(index).maxRstar = max(obj.rstarTable.(rstarVars{i}));
                    index = index + 1;
                end
            end
            obj.rstarMeta = metaData;
        end
        
        function onSetRstarPerSecond(obj, ~, ~)
            rstarInput = str2double(get(obj.rstarPerSecondText, 'String'));
            
            metaIndices = find([obj.rstarMeta(:).maxRstar] > rstarInput);
            ndfColumn = obj.rstarMeta(metaIndices(1)).columnName;
            tableIndices = find(obj.rstarTable.(ndfColumn) >= rstarInput);
            
            ledCurrent = obj.rstarTable.Ledurrents(tableIndices(1));
            ndf1= obj.rstarMeta(metaIndices(1)).wheelOne;
            ndf2 = obj.rstarMeta(metaIndices(1)).wheelTwo;
            rstars = obj.rstarTable.(ndfColumn);
            obj.rstarPerSecond = rstars(tableIndices(1));
            
            ndf1Prop = obj.protocolPropertyGrid.Properties.FindByName('NDF1');
            ndf2Prop = obj.protocolPropertyGrid.Properties.FindByName('NDF2');
            blueLedProp = obj.protocolPropertyGrid.Properties.FindByName('blueLED');
            rstarPerSecondProp = obj.protocolPropertyGrid.Properties.FindByName('rstarPerSecond');
            
            
            set(ndf1Prop, 'Value', ndf1);
            set(ndf2Prop, 'Value', ndf2);
            set(blueLedProp, 'Value', ledCurrent);
            set(rstarPerSecondProp, 'Value', obj.rstarPerSecond);
            obj.protocolPropertyGrid.UpdateProperties([ndf1Prop, ndf2Prop, blueLedProp, rstarPerSecondProp])
            
        end

    end
    
end

