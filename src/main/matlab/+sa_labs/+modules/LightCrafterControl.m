classdef LightCrafterControl < symphonyui.ui.Module
    % LED enables and pattern rate of the LightCrafter projector.
    % Symphony 3 hosts modules in a uifigure, so this uses uigridlayout /
    % uicheckbox / uidropdown (no GUI Layout Toolbox, no uicontrol).

    properties (Access = private)
        lightCrafter
        ledEnablesCheckboxes
        patternRateDropdown
    end

    methods

        function createUi(obj, figureHandle)
            set(figureHandle, ...
                'Name', 'LightCrafter Control', ...
                'Position', appbox.screenCenter(360, 90));

            grid = uigridlayout(figureHandle, [2 2]);
            grid.ColumnWidth = {90, '1x'};
            grid.RowHeight = {24, 24};
            grid.Padding = [11 11 11 11];
            grid.RowSpacing = 7;
            grid.ColumnSpacing = 7;

            l1 = uilabel(grid, 'Text', 'LED enables:');
            l1.Layout.Row = 1; l1.Layout.Column = 1;

            ledRow = uigridlayout(grid, [1 4]);
            ledRow.Layout.Row = 1; ledRow.Layout.Column = 2;
            ledRow.Padding = [0 0 0 0];
            ledRow.ColumnSpacing = 3;
            ledRow.ColumnWidth = {'1x', '1x', '1x', '1x'};
            names = {'auto', 'red', 'green', 'blue'};
            texts = {'Auto', 'Red', 'Green', 'Blue'};
            for i = 1:numel(names)
                cb = uicheckbox(ledRow, 'Text', texts{i}, ...
                    'ValueChangedFcn', @(~,~) obj.onSelectedLedEnable());
                cb.Layout.Row = 1; cb.Layout.Column = i;
                obj.ledEnablesCheckboxes.(names{i}) = cb;
            end

            l2 = uilabel(grid, 'Text', 'Pattern rate:');
            l2.Layout.Row = 2; l2.Layout.Column = 1;

            obj.patternRateDropdown = uidropdown(grid, ...
                'Items', {' '}, ...
                'ItemsData', {[]}, ...
                'ValueChangedFcn', @(~,~) obj.onSelectedPatternRate());
            obj.patternRateDropdown.Layout.Row = 2;
            obj.patternRateDropdown.Layout.Column = 2;
        end

    end

    methods (Access = protected)

        function willGo(obj)
            devices = obj.configurationService.getDevices('LightCrafter');
            if isempty(devices)
                error('No LightCrafter device found');
            end
            obj.lightCrafter = devices{1};

            obj.populateLedEnablesCheckboxes();
            obj.populatePatternRateList();
        end

    end

    methods (Access = private)

        function populateLedEnablesCheckboxes(obj)
            [auto, red, green, blue] = obj.lightCrafter.getLedEnables();
            obj.ledEnablesCheckboxes.auto.Value = logical(auto);
            obj.ledEnablesCheckboxes.red.Value = logical(red);
            obj.ledEnablesCheckboxes.green.Value = logical(green);
            obj.ledEnablesCheckboxes.blue.Value = logical(blue);
        end

        function onSelectedLedEnable(obj)
            auto = obj.ledEnablesCheckboxes.auto.Value;
            red = obj.ledEnablesCheckboxes.red.Value;
            green = obj.ledEnablesCheckboxes.green.Value;
            blue = obj.ledEnablesCheckboxes.blue.Value;
            obj.lightCrafter.setLedEnables(auto, red, green, blue);
        end

        function populatePatternRateList(obj)
            rates = obj.lightCrafter.availablePatternRates();
            if ~iscell(rates), rates = num2cell(rates); end
            names = cellfun(@(r)[num2str(r) ' Hz'], rates, 'UniformOutput', false);
            obj.patternRateDropdown.Items = names;
            obj.patternRateDropdown.ItemsData = rates;
            current = obj.lightCrafter.getPatternRate();
            idx = find(cellfun(@(r) isequal(r, current), rates), 1);
            if isempty(idx), idx = 1; end
            obj.patternRateDropdown.Value = rates{idx};
        end

        function onSelectedPatternRate(obj)
            rate = obj.patternRateDropdown.Value;
            obj.lightCrafter.setPatternRate(rate);
        end

    end

end
