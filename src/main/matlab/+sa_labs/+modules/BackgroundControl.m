classdef BackgroundControl < symphonyui.ui.Module
    % Set the background (hold) value of each output device and apply it.
    %
    % Ported off the JIDE property grid (uiextras.jide.PropertyGrid), which the
    % symphony3 fork removed, to a uifigure-native uigridlayout of label + numeric
    % editfield rows. Behavior is unchanged: one row per output device showing
    % "<name> (<units>)" and its background.quantity; editing a value sets the
    % device background and applies it, reverting on error.

    properties (Access = private)
        devices
        deviceListeners = {}
        grid          % uigridlayout holding the device rows
        valueFields   % containers.Map: device name -> uieditfield handle
    end

    methods

        function createUi(obj, figureHandle)
            import appbox.*;

            set(figureHandle, ...
                'Name', 'Background Control', ...
                'Position', screenCenter(320, 240));

            obj.grid = uigridlayout(figureHandle, [1 2]);
            obj.grid.ColumnWidth = {'2x', '1x'};
            obj.grid.RowHeight = {22};
            obj.grid.RowSpacing = 4;
            obj.grid.Padding = [8 8 8 8];
            obj.grid.Scrollable = 'on';

            obj.valueFields = containers.Map('KeyType', 'char', 'ValueType', 'any');
        end

    end

    methods (Access = protected)

        function willGo(obj)
            obj.devices = obj.configurationService.getOutputDevices();
            obj.populateDeviceGrid();
        end

        function bind(obj)
            bind@symphonyui.ui.Module(obj);

            obj.bindDevices();

            c = obj.configurationService;
            obj.addListener(c, 'InitializedRig', @obj.onServiceInitializedRig);
        end

    end

    methods (Access = private)

        function bindDevices(obj)
            for i = 1:numel(obj.devices)
                obj.deviceListeners{end + 1} = obj.addListener( ...
                    obj.devices{i}, 'background', 'PostSet', @obj.onDeviceSetBackground);
            end
        end

        function unbindDevices(obj)
            while ~isempty(obj.deviceListeners)
                obj.removeListener(obj.deviceListeners{1});
                obj.deviceListeners(1) = [];
            end
        end

        function populateDeviceGrid(obj)
            % Rebuild the rows from scratch (called on first show and rig re-init).
            if ~isempty(obj.grid) && isvalid(obj.grid)
                delete(obj.grid.Children);
            end
            obj.valueFields = containers.Map('KeyType', 'char', 'ValueType', 'any');

            n = numel(obj.devices);
            if n == 0
                obj.grid.RowHeight = {22};
                uilabel(obj.grid, 'Text', '(no output devices)');
                return;
            end

            obj.grid.RowHeight = repmat({22}, 1, n);
            for i = 1:n
                d = obj.devices{i};
                try
                    units = d.background.displayUnits;
                    quantity = d.background.quantity;
                catch x
                    uialert(obj.getFigureHandle(), x.message, 'Background Control');
                    continue;
                end

                lbl = uilabel(obj.grid, ...
                    'Text', sprintf('%s (%s)', d.name, units), ...
                    'HorizontalAlignment', 'right');
                lbl.Layout.Row = i;
                lbl.Layout.Column = 1;

                fld = uieditfield(obj.grid, 'numeric', ...
                    'Value', quantity, ...
                    'ValueChangedFcn', @(s, ~) obj.onSetBackground(d.name, s.Value));
                fld.Layout.Row = i;
                fld.Layout.Column = 2;

                obj.valueFields(d.name) = fld;
            end
        end

        function updateDeviceGrid(obj)
            % Refresh field values in place (device background changed elsewhere).
            for i = 1:numel(obj.devices)
                d = obj.devices{i};
                if isKey(obj.valueFields, d.name)
                    fld = obj.valueFields(d.name);
                    if isvalid(fld)
                        try
                            fld.Value = d.background.quantity;
                        catch
                        end
                    end
                end
            end
        end

        function onSetBackground(obj, deviceName, newValue)
            device = obj.configurationService.getDevice(deviceName);
            previous = device.background;
            device.background = symphonyui.core.Measurement(newValue, previous.displayUnits);
            try
                device.applyBackground();
            catch x
                device.background = previous;
                if isKey(obj.valueFields, deviceName) && isvalid(obj.valueFields(deviceName))
                    obj.valueFields(deviceName).Value = previous.quantity;
                end
                uialert(obj.getFigureHandle(), x.message, 'Background Control');
                return;
            end
        end

        function onServiceInitializedRig(obj, ~, ~)
            obj.unbindDevices();
            obj.devices = obj.configurationService.getOutputDevices();
            obj.populateDeviceGrid();
            obj.bindDevices();
        end

        function onDeviceSetBackground(obj, ~, ~)
            obj.updateDeviceGrid();
        end

    end

end