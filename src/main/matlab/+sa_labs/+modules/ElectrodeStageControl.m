classdef ElectrodeStageControl < symphonyui.ui.Module
    properties
        Fig
        MainLayout
        TabGroup
        Tabs
    end

    methods
        function obj = ElectrodeStageControl();
            % Create a figure for the GUI
            obj.Fig = figure('Name', 'Coordinate GUI', 'NumberTitle', 'off', ...
                             'Position', [300, 200, 600, 400]);

            % Create main layout using GUI Layout Toolbox
            uix.VBox
            obj.MainLayout = uix.VBox('Parent', obj.Fig, 'Spacing', 5, 'Padding', 5);

            % Create tab group
            obj.TabGroup = uix.TabPanel('Parent', obj.MainLayout, 'Padding', 5);

            % Create tabs
            obj.Tabs = gobjects(1, 3);
            for i = 1:3
                obj.Tabs(i) = uix.VBox('Parent', obj.TabGroup, 'Spacing', 5, 'Padding', 5);
                obj.createTabContent(obj.Tabs(i));
                obj.TabGroup.TabTitles{i} = ['Tab ' num2str(i)];
            end

            % Add bottom buttons
            buttonPanel = uix.HButtonBox('Parent', obj.MainLayout, 'ButtonSize', [100, 40], 'Spacing', 10);
            uicontrol('Parent', buttonPanel, 'Style', 'pushbutton', 'String', 'Follow', ...
                      'Callback', @(src, event)obj.followCallback());
            uicontrol('Parent', buttonPanel, 'Style', 'pushbutton', 'String', 'All=0', ...
                      'Callback', @(src, event)obj.allZeroCallback());
            uicontrol('Parent', buttonPanel, 'Style', 'pushbutton', 'String', 'Set', ...
                      'Callback', @(src, event)obj.setCallback());

            obj.MainLayout.Heights = [-1, 50]; % Allocate space for tabs and buttons
        end

        function createTabContent(obj, tab)
            labels = {'X', 'Y', 'Z', 'C'};
            for i = 1:length(labels)
                % Create horizontal layout for each coordinate
                row = uix.HBox('Parent', tab, 'Spacing', 5, 'Padding', 5);

                % Create label
                uicontrol('Parent', row, 'Style', 'text', 'String', labels{i}, ...
                          'HorizontalAlignment', 'right');

                % Create bar-like input field
                barAxes = axes('Parent', row, 'XLim', [0, 1], 'YLim', [0, 1], 'XColor', 'none', 'YColor', 'none');
                hold(barAxes, 'on');
                barHandle = fill(barAxes, [0, 0.5, 0.5, 0], [0, 0, 1, 1], 'b', 'Tag', [labels{i} '_bar']);
                hold(barAxes, 'off');

                % Create "X=0" button
                uicontrol('Parent', row, 'Style', 'pushbutton', 'String', [labels{i} '=0'], ...
                          'Callback', @(src, event)obj.zeroCallback(labels{i}, tab));

                row.Widths = [50, -1, 100]; % Adjust widths of label, bar, and button
            end
        end

        function zeroCallback(obj, label, tab)
            barHandle = findobj(tab, 'Tag', [label '_bar']);
            if ~isempty(barHandle)
                barHandle.Vertices(:, 1) = [0; 0; 0; 0]; % Set bar to zero position
            end
        end

        function allZeroCallback(obj)
            for t = 1:length(obj.Tabs)
                currentTab = obj.Tabs(t);
                for label = {'X', 'Y', 'Z', 'C'}
                    barHandle = findobj(currentTab, 'Tag', [label{1} '_bar']);
                    if ~isempty(barHandle)
                        barHandle.Vertices(:, 1) = [0; 0; 0; 0]; % Set all bars to zero position
                    end
                end
            end
        end

        function followCallback(obj)
            disp('Follow button pressed');
        end

        function setCallback(obj)
            disp('Set button pressed');
        end
    end
end
