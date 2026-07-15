classdef CommonControl < symphonyui.ui.Module
    % Quick panel to set common protocol parameters (amp channels/modes/holds
    % and projector settings) and apply them to the current protocol at once.
    %
    % Ported off the JIDE property grid to a uifigure uigridlayout (label +
    % editfield/dropdown rows, grouped by category). "Apply to Protocol" pushes
    % the values via the acquisition service (ModuleAcquisitionAdapter ->
    % SymphonyApp.applyProtocolPropertyMap). Behavior matches the original.

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

        grid            % uigridlayout holding the property rows
        controls        % containers.Map: propName -> control handle
        displayedNames  % cell of property names currently shown (row order)
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
            obj.ampList = horzcat({'None'}, obj.ampList);

            obj.chan1Type = symphonyui.core.PropertyType('char', 'row', obj.ampList(2:end)); % first channel always filled
            obj.chan2Type = symphonyui.core.PropertyType('char', 'row', obj.ampList);
            obj.chan3Type = symphonyui.core.PropertyType('char', 'row', obj.ampList);
            obj.chan4Type = symphonyui.core.PropertyType('char', 'row', obj.ampList);
        end

        function createUi(obj, figureHandle)
            set(figureHandle, ...
                'Name', 'Common Control', ...
                'Position', appbox.screenCenter(300, 440));

            outer = uigridlayout(figureHandle, [2 1]);
            outer.RowHeight = {'1x', 32};
            outer.Padding = [8 8 8 8];
            outer.RowSpacing = 6;

            obj.grid = uigridlayout(outer, [1 2]);
            obj.grid.Layout.Row = 1;
            obj.grid.Layout.Column = 1;
            obj.grid.ColumnWidth = {'1x', '1x'};
            obj.grid.RowSpacing = 2;
            obj.grid.Padding = [4 4 4 4];
            obj.grid.Scrollable = 'on';

            applyBtn = uibutton(outer, 'push', ...
                'Text', 'Apply to Protocol', ...
                'ButtonPushedFcn', @(~,~) obj.cbSetParameters());
            applyBtn.Layout.Row = 2;
            applyBtn.Layout.Column = 1;

            obj.populateProtocolProperties();
        end

        function cbSetParameters(obj, ~, ~)
            % Read the displayed values from the module and push them to the
            % current protocol via the acquisition service.
            if isempty(obj.acquisitionService)
                uialert(obj.getFigureHandle(), ...
                    'No acquisition service available (open a protocol first).', 'Common Control');
                return;
            end
            propertyMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for i = 1:numel(obj.displayedNames)
                nm = obj.displayedNames{i};
                propertyMap(nm) = obj.(nm);
            end
            obj.acquisitionService.setProtocolPropertyMap(propertyMap);
        end

        function populateProtocolProperties(obj)
            if isempty(obj.grid) || ~isvalid(obj.grid)
                return;
            end
            delete(obj.grid.Children);
            obj.controls = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.displayedNames = {};

            numAmps = numel(obj.ampList) - 1;

            % Keep projector properties + channel properties for available amps.
            names = properties(obj);
            keep = false(numel(names), 1);
            cats = cell(numel(names), 1);
            for i = 1:numel(names)
                nm = names{i};
                if any(strcmp(nm, obj.projectorPropertyNames))
                    keep(i) = true;
                    cats{i} = 'Projector';
                elseif ~isempty(strfind(nm, 'chan')) %#ok<STREMP>
                    chNum = str2double(nm(5));
                    if ~isnan(chNum) && numAmps >= chNum
                        keep(i) = true;
                        cats{i} = sprintf('Channel %d', chNum);
                    end
                end
            end
            names = names(keep);
            cats = cats(keep);

            ucats = unique(cats, 'stable');
            rh = {};
            r = 0;
            for ci = 1:numel(ucats)
                cat = ucats{ci};

                r = r + 1;
                rh{end+1} = 20; %#ok<AGROW>
                hdr = uilabel(obj.grid, 'Text', cat, 'FontWeight', 'bold');
                hdr.Layout.Row = r;
                hdr.Layout.Column = [1 2];

                idx = find(strcmp(cats, cat));
                for j = 1:numel(idx)
                    nm = names{idx(j)};
                    obj.displayedNames{end+1} = nm; %#ok<AGROW>

                    r = r + 1;
                    rh{end+1} = 22; %#ok<AGROW>
                    lbl = uilabel(obj.grid, 'Text', obj.humanize(nm), ...
                        'HorizontalAlignment', 'right');
                    lbl.Layout.Row = r;
                    lbl.Layout.Column = 1;

                    ctrl = obj.makeControl(nm);
                    ctrl.Layout.Row = r;
                    ctrl.Layout.Column = 2;
                    obj.controls(nm) = ctrl;
                end
            end
            if isempty(rh)
                rh = {22};
            end
            obj.grid.RowHeight = rh;
        end

        function ctrl = makeControl(obj, name)
            value = obj.(name);

            % Domain from a companion <name>Type PropertyType (dropdown), if any.
            domain = {};
            typeName = [name 'Type'];
            if isprop(obj, typeName)
                t = obj.(typeName);
                if isa(t, 'symphonyui.core.PropertyType') && iscell(t.domain) && ~isempty(t.domain)
                    domain = t.domain;
                end
            end

            if ~isempty(domain)
                curVal = value;
                if ~ischar(curVal)
                    curVal = char(string(curVal));
                end
                items = domain;
                if ~any(strcmp(curVal, items))
                    items = [items, {curVal}];
                end
                ctrl = uidropdown(obj.grid, 'Items', items, 'Value', curVal, ...
                    'ValueChangedFcn', @(s,~) obj.onControlChanged(name, s.Value));
            elseif islogical(value)
                ctrl = uidropdown(obj.grid, 'Items', {'true','false'}, 'Value', mat2str(value), ...
                    'ValueChangedFcn', @(s,~) obj.onControlChanged(name, strcmp(s.Value, 'true')));
            elseif isnumeric(value)
                ctrl = uieditfield(obj.grid, 'numeric', 'Value', value, ...
                    'ValueChangedFcn', @(s,~) obj.onControlChanged(name, s.Value));
            else
                ctrl = uieditfield(obj.grid, 'text', 'Value', char(string(value)), ...
                    'ValueChangedFcn', @(s,~) obj.onControlChanged(name, s.Value));
            end
        end

        function onControlChanged(obj, name, value)
            try
                obj.(name) = value;
            catch x
                uialert(obj.getFigureHandle(), x.message, 'Common Control');
            end
        end

    end

    methods (Static, Access = private)

        function s = humanize(name)
            % camelCase -> spaced, capitalized first letter (e.g. blueLED -> Blue LED)
            s = regexprep(name, '([a-z0-9])([A-Z])', '$1 $2');
            if ~isempty(s)
                s(1) = upper(s(1));
            end
        end

    end

end