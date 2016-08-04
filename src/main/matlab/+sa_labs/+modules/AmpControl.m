classdef AmpControl < symphonyui.ui.Module
    
    properties
        
        chan1 = 'Amp1';
        chan1Mode = 'Cell attached'
        chan1Hold = 0
        
        chan2 = 'None';   
        chan2Mode = 'Cell attached'
        chan2Hold = 0
        
        chan3  = 'None';  
        chan3Mode = 'Cell attached'
        chan3Hold = 0
        
        chan4  = 'None';  
        chan4Mode = 'Cell attached'
        chan4Hold = 0
    end
    
    properties(Hidden)
        ampList
        
        chan1Type
        chan2Type
        chan3Type
        chan4Type
        chan1ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell'});
        chan2ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell'});
        chan3ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell'});
        chan4ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell'});
    
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
                'Name', 'Amp Control', ...
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
            propertyMap = containers.Map();
            rawProperties = get(obj.protocolPropertyGrid, 'Properties');
            for p = 1:length(rawProperties)
                prop = rawProperties(p);
                propertyMap(prop.Name) = prop.Value;
            end

            obj.acquisitionService.setProtocolPropertyMap(propertyMap);
        end
        
        function populateProtocolProperties(obj)
            names = properties(obj);
            exc = zeros(size(names));
            for i = 1:length(names)
                if strfind(names{i}, 'chan')
                    exc(i) = 0;
                else
                    exc(i) = 1;
                end
            end
            names(logical(exc)) = [];
            
            % those 10 lines in python:
            % names = [n for n in properties(obj) if not strfind(n, 'chan')]
            
            descriptors = symphonyui.core.PropertyDescriptor.empty(0, numel(names));
            for i = 1:numel(names)
                descriptors(i) = symphonyui.core.PropertyDescriptor.fromProperty(obj, names{i});
                descriptors(i).category = sprintf('Channel %s',names{i}(5));
            end

            fields = symphonyui.ui.util.desc2field(descriptors);
            set(obj.protocolPropertyGrid, 'Properties', fields);
        end

    end
    
end

