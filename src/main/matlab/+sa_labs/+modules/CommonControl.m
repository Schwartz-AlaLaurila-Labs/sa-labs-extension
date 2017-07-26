classdef CommonControl < symphonyui.ui.Module
    
    properties
        % projector
        offsetX = 0 % um
        offsetY = 0 % um
        
        NDF = 5 % Filter wheel position
        frameRate = 60;% Hz
        patternRate = 60;% Hz
        blueLED = 20 % 0-255
        greenLED = 0 % 0-255
        
        spikeDetectorMode = 'Filtered Threshold';
        spikeThreshold = 22 % pA or std
        
        % amplifiers
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
    end
    
    properties(Hidden)
        color = 'cyan'       
        colorType = symphonyui.core.PropertyType('char', 'row', {'cyan','blue','green'});
        
        projectorPropertyNames = {'spikeThreshold','spikeDetectorMode','color','NDF', 'blueLED','greenLED','offsetX','offsetY'};
        
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
    end
    
    methods (Access = protected)
        
        function willGo(obj)
            obj.updateDeviceList();
            obj.populateProtocolProperties();
        end
        
        function bind(obj)
            bind@symphonyui.ui.Module(obj);

            c = obj.configurationService;
            obj.addListener(c, 'InitializedRig', @obj.onServiceInitializedRig);
        end
    end

    methods
        
        function onServiceInitializedRig(obj, ~, ~)
            obj.updateDeviceList();
            obj.populateProtocolProperties();
        end

        function updateDeviceList(obj)
            
            devices = obj.configurationService.getDevices('Amp');
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
        
        function createUi(obj, figureHandle)
            set(figureHandle, ...
                'Name', 'Common Control', ...
                'Position', appbox.screenCenter(240, 340));
            
            layout = uix.VBox( ...
                'Parent', figureHandle, ...
                'Padding', 11);
            
            obj.protocolPropertyGrid = uiextras.jide.PropertyGrid(layout);

            uicontrol( ...
                'Parent', layout, ...
                'Style', 'pushbutton', ...
                'String', 'Apply to Protocol', ...
                'Callback', @obj.cbSetParameters);
            
            set(layout, 'Heights', [-1, 30]);
        end
        
        function cbSetParameters(obj, ~, ~)
            % set values in the protocol (callback on change settings in this module)
            propertyMap = containers.Map();
            rawProperties = get(obj.protocolPropertyGrid, 'Properties');
            for p = 1:length(rawProperties)
                prop = rawProperties(p);
                propertyMap(prop.Name) = prop.Value;
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
            descriptors = symphonyui.core.PropertyDescriptor.empty(0, n);
            
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
            
            fields = symphonyui.ui.util.desc2field(descriptors);
            set(obj.protocolPropertyGrid, 'Properties', fields);
        end
    end
    
end

