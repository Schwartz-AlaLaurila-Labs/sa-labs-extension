classdef LightCrafterControl < symphonyui.ui.Module
    % LED enables and pattern rate of the LightCrafter projector.
    % Symphony 3 hosts modules in a uifigure, so this uses uigridlayout /
    % uicheckbox (no GUI Layout Toolbox, no uicontrol).
    %
    % The pattern rate on the LightCrafter 4500 is number of patterns times
    % the projector refresh rate and is set by the protocol's bitDepth /
    % numberOfPatterns parameters (LightCrafterDevice.setPatternAttributes),
    % so it is shown read-only here. (The original module's pattern-rate
    % dropdown called availablePatternRates / setPatternRate, which the lab's
    % LightCrafterDevice never implemented, so that part never worked.)

    properties (Access = private)
        lightCrafter
        ledEnablesCheckboxes
        patternRateLabel
    end

    methods

        function createUi(obj, figureHandle)
            set(figureHandle, ...
                'Name', 'LightCrafter Control', ...
                'Position', appbox.screenCenter(380, 90));

            grid = uigridlayout(figureHandle, [2 3]);
            grid.ColumnWidth = {90, '1x', 70};
            grid.RowHeight = {24, 24};
            grid.Padding = [11 11 11 11];
            grid.RowSpacing = 7;
            grid.ColumnSpacing = 7;

            l1 = uilabel(grid, 'Text', 'LED enables:');
            l1.Layout.Row = 1; l1.Layout.Column = 1;

            ledRow = uigridlayout(grid, [1 4]);
            ledRow.Layout.Row = 1; ledRow.Layout.Column = [2 3];
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

            obj.patternRateLabel = uilabel(grid, 'Text', '');
            obj.patternRateLabel.Layout.Row = 2;
            obj.patternRateLabel.Layout.Column = 2;

            b = uibutton(grid, 'push', 'Text', 'Refresh', ...
                'ButtonPushedFcn', @(~,~) obj.refresh());
            b.Layout.Row = 2; b.Layout.Column = 3;
        end

    end

    methods (Access = protected)

        function willGo(obj)
            devices = obj.configurationService.getDevices('LightCrafter');
            if isempty(devices)
                error('No LightCrafter device found');
            end
            obj.lightCrafter = devices{1};
            obj.refresh();
        end

    end

    methods (Access = private)

        function refresh(obj)
            obj.populateLedEnablesCheckboxes();
            obj.populatePatternRate();
        end

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

        function populatePatternRate(obj)
            try
                rate = obj.lightCrafter.getPatternRate();
                [bitDepth, ~, numPatterns] = obj.lightCrafter.getPatternAttributes();
                obj.patternRateLabel.Text = sprintf('%g Hz  (%d pattern(s), %d-bit)', rate, numPatterns, bitDepth);
            catch e
                obj.patternRateLabel.Text = ['unavailable: ' e.message];
            end
        end

    end

end
