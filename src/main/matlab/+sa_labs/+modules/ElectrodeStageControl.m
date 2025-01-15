classdef ElectrodeStageControl < symphonyui.ui.Module
    properties
        
        layout
        tabGroup
        tabs
    end

    methods
        function createUi(self, figure_handle)
            set(figure_handle,...
                'Name','Electrode Stage Control',...
                'Position', appbox.screenCenter(500, 550));
            
            self.layout = uix.VBox('parent', figure_handle, 'Spacing', 5, 'Padding', 5);
            % Create main layout using GUI Layout Toolbox
            %uix.VBox
            %obj.MainLayout = uix.VBox('Parent', obj.Fig, 'Spacing', 5, 'Padding', 5);

            % Create tab group
            self.tabGroup = uix.TabPanel('Parent', self.layout, 'Padding', 5);
            self.tabGroup.TabWidth = 100;
            % Create tabs
            self.tabs = gobjects(1, 3);
            for i = 1:3
                self.tabs(i) = uix.VBox('Parent', self.tabGroup, 'Spacing', 5, 'Padding', 5);
                %createTabContent(self.tabs(i));
                if i==1
                    self.tabGroup.TabTitles{i} = 'SliceScope';
                elseif i==2
                    self.tabGroup.TabTitles{i} = 'Left Electrode';
                else
                    self.tabGroup.TabTitles{i} = 'Right Electrode';
                end
            end

            % Add bottom buttons
            buttonPanel = uix.HButtonBox('Parent', self.layout, 'ButtonSize', [100, 40], 'Spacing', 10);
            uicontrol('Parent', buttonPanel, 'Style', 'pushbutton', 'String', 'Follow', ...
                      'Callback', @(src, event)self.followCallback());
            uicontrol('Parent', buttonPanel, 'Style', 'pushbutton', 'String', 'All=0', ...
                      'Callback', @(src, event)self.allZeroCallback());
            uicontrol('Parent', buttonPanel, 'Style', 'pushbutton', 'String', 'Set', ...
                      'Callback', @(src, event)self.setCallback());

            self.layout.Heights = [-1, 50]; % Allocate space for tabs and buttons
        end

%         function createTabContent(obj, tab)
%             labels = {'X', 'Y', 'Z', 'C'};
%             for i = 1:length(labels)
%                 % Create horizontal layout for each coordinate
%                 row = uix.HBox('Parent', tab, 'Spacing', 5, 'Padding', 5);
% 
%                 % Create label
%                 uicontrol('Parent', row, 'Style', 'text', 'String', labels{i}, ...
%                           'HorizontalAlignment', 'right');
% 
%                 % Create bar-like input field
%                 barAxes = axes('Parent', row, 'XLim', [0, 1], 'YLim', [0, 1], 'XColor', 'none', 'YColor', 'none');
%                 hold(barAxes, 'on');
%                 barHandle = fill(barAxes, [0, 0.5, 0.5, 0], [0, 0, 1, 1], 'b', 'Tag', [labels{i} '_bar']);
%                 hold(barAxes, 'off');
% 
%                 % Create "X=0" button
%                 uicontrol('Parent', row, 'Style', 'pushbutton', 'String', [labels{i} '=0'], ...
%                           'Callback', @(src, event)obj.zeroCallback(labels{i}, tab));
% 
%                 row.Widths = [50, -1, 100]; % Adjust widths of label, bar, and button
%             end
%         end

%         function zeroCallback(self, label, tab)
%             barHandle = findobj(tab, 'Tag', [label '_bar']);
%             if ~isempty(barHandle)
%                 barHandle.Vertices(:, 1) = [0; 0; 0; 0]; % Set bar to zero position
%             end
%         end

%         function allZeroCallback(self)
%             for t = 1:length(self.tabs)
%                 currentTab = self.tabs(t);
%                 for label = {'X', 'Y', 'Z', 'C'}
%                     barHandle = findobj(currentTab, 'Tag', [label{1} '_bar']);
%                     if ~isempty(barHandle)
%                         barHandle.Vertices(:, 1) = [0; 0; 0; 0]; % Set all bars to zero position
%                     end
%                 end
%             end
%         end

        function followCallback(self)
            disp('Follow button pressed');
        end

        function setCallback(self)
            disp('Set button pressed');
        end
    end
end
