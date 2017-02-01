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
        
        projectorPropertyNames = {'spikeThreshold','spikeDetectorMode','color','NDF','frameRate','patternRate','blueLED','greenLED','offsetX','offsetY'};
        ampList
        
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
    end
    
%     methods (Access = protected)
%         function willGo(obj)
%             obj.updateDeviceList();
%         end   
%     end    
    
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
            obj.ampList = horzcat({'None'}, obj.ampList);
            
            obj.chan1Type = symphonyui.core.PropertyType('char', 'row', obj.ampList(2:end)); % first channel should always be filled
            obj.chan2Type = symphonyui.core.PropertyType('char', 'row', obj.ampList);
            obj.chan3Type = symphonyui.core.PropertyType('char', 'row', obj.ampList);
            obj.chan4Type = symphonyui.core.PropertyType('char', 'row', obj.ampList);
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
            
%             obj.ampList = {'None','Amp1','Amp2','Amp3','Amp4'};
            obj.populateProtocolProperties();
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
            numAmps = length(obj.ampList) - 1;
            % get values from the protocol to instantiate display
            names = properties(obj);
            excludeParam = zeros(size(names));
            for i = 1:length(names)
                
                % Select out projector properties
                if any(strcmp(names{i}, obj.projectorPropertyNames))
                    continue
                end
                
                %select out the channel parameters
                if isempty(strfind(names{i}, 'chan')) % get rid of 
                    excludeParam(i) = 1;
                else
                    % toss the ones with too high a channel number
                    if numAmps < str2double(names{i}(5))
                        excludeParam(i) = 1;
                    end
                end
            end
            names(logical(excludeParam)) = [];
            % preceding 10 lines in 1 python line:
            % names = [n for n in properties(obj) if not strfind(n, 'chan')]
            
            % set the display category
            descriptors = symphonyui.core.PropertyDescriptor.empty(0, numel(names));
            for i = 1:numel(names)
                descriptors(i) = symphonyui.core.PropertyDescriptor.fromProperty(obj, names{i});
                if strfind(names{i}, 'chan')
                    descriptors(i).category = sprintf('Channel %s',names{i}(5));
                else
                    descriptors(i).category = 'Projector';
                end
            end

            fields = symphonyui.ui.util.desc2field(descriptors);
            set(obj.protocolPropertyGrid, 'Properties', fields);
        end

    end
    
end

