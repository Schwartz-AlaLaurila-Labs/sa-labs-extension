classdef ResponseAnalysisFigure < symphonyui.core.FigureHandler
    % Plots statistics calculated from the response of a specified device for each epoch run.
    
    properties (SetAccess = private)
        device
        activeFunctionNames
        measurementRegion
        baselineRegion
        epochData
        allMeasurementNames = {'mean','var','max','min','sum','std'};
        plotMode
    end
    
    properties % not private access
        epochSplitParameter
    end    
    
    properties (Access = private)
        axesHandles
        markers
    end
    
    methods
        
        function obj = ResponseAnalysisFigure(device, varargin)
            
%             disp('figure start')
            obj = obj@symphonyui.core.FigureHandler();
            
%             if ~iscell(activeFunctionNames)
%                 activeFunctionNames = {activeFunctionNames};
%             end
            
            ip = inputParser();
            ip.addParameter('activeFunctionNames', {'mean'});            
            ip.addParameter('measurementRegion', [], @(x)isnumeric(x) || isvector(x));
            ip.addParameter('baselineRegion', [], @(x)isnumeric(x) || isvector(x));
            ip.addParameter('epochSplitParameter', '', @(x)ischar(x));
            ip.addParameter('plotMode', 'cartesian', @(x)ischar(x));
            ip.parse(varargin{:});
            
            obj.device = device;
            obj.activeFunctionNames = ip.Results.activeFunctionNames;
            obj.measurementRegion = ip.Results.measurementRegion;
            obj.baselineRegion = ip.Results.baselineRegion;
            obj.epochSplitParameter = ip.Results.epochSplitParameter;
            obj.plotMode = ip.Results.plotMode;
            
            obj.createUi();
            
            obj.epochData = {};
        end
        
        function createUi(obj)
            import appbox.*;
%             clf(obj.figureHandle);
            
            fullBox = uix.VBoxFlex('Parent',obj.figureHandle,'Spacing',10);
%             hbox = uix.HBox( 'Parent', obj.figureHandle);
%             plotBox = uix.VBox('Parent', hbox );
%             controlBox = uix.VBox('Parent', hbox);
%             

%             funcNames = cellfun(@func2str, obj.activeFunctionNames, 'UniformOutput', 0);

            obj.axesHandles = [];
            rowBoxes = [];
            plotControlBoxes = [];
            measListBoxes = [];
            delPlotButtons = [];
            for measi = 1:numel(obj.activeFunctionNames)
                funcName = obj.activeFunctionNames{measi};
                
                rowBoxes(measi) = uix.HBox('Parent',fullBox);
                
                if strcmp(obj.plotMode, 'cartesian')
                    obj.axesHandles(measi) = axes('Parent', rowBoxes(measi));
                else
                    obj.axesHandles(measi) = polaraxes('Parent', rowBoxes(measi));
                end
                
%                 set(obj.axesHandles(i),'Position',[.4 .4 .5 .5])
                plotControlBoxes(measi) = uix.VBox('Parent',rowBoxes(measi));
                
                thisFuncIndex = find(not(cellfun('isempty', strfind(obj.activeFunctionNames, funcName))), 1);
                
                measListBoxes(measi) = uicontrol( 'Style', 'listbox', 'Parent', plotControlBoxes(measi), ...
                    'String', obj.allMeasurementNames, 'Value',thisFuncIndex, 'Back', 'w',...
                    'Callback',{@obj.functionSelectorCallback, measi}); 
                
                delPlotButtons(measi) = uicontrol('Style','pushbutton', 'Parent', plotControlBoxes(measi),...
                    'String', 'del', 'Callback',{@obj.deletePlotCallback, measi});
                
                set(plotControlBoxes(measi), 'Heights', [-1, 30])
                
                set(rowBoxes(measi), 'Widths', [-3 80]);
                
                %                     'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                %                     'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                %                     'XTickMode', 'auto', ...
                %                     'XColor', 'none');
                %                 ylabel(obj.axesHandles(i), func2str(obj.activeFunctionNames{i}));
            end
            %             set(obj.axesHandles(end), 'XColor', get(groot, 'defaultAxesXColor'));
            %             xlabel(obj.axesHandles(end), 'epoch');
            
            %             obj.setTitle([obj.device.name ' Response Statistics']);
            
            buttonArea = uix.HButtonBox('Parent',fullBox,'ButtonSize', [100, 30]);
            newPlotButton = uicontrol('Style','pushbutton', 'Parent', buttonArea, 'String', 'new plot','Callback',@obj.addPlotCallback);
            redrawButton = uicontrol('Style','pushbutton', 'Parent', buttonArea, 'String', 'redraw','Callback',@obj.redrawPlotCallback);

            
            set(fullBox, 'Heights', [-1*ones(1, numel(obj.activeFunctionNames)), 30])
        end
        
        function redrawPlotCallback(obj, ~, ~)
            obj.redrawPlots()
        end
        
        function functionSelectorCallback(obj, hObject, ~, measi)
            items = get(hObject,'String');
            index_selected = get(hObject,'Value');
            item_selected = items{index_selected};
%             fprintf('plot %d switch to %s\n', measi, item_selected);
            obj.activeFunctionNames{measi} = item_selected;
%             obj.redrawPlots();
        end
        
        function deletePlotCallback(obj, ~, ~, measi)
%             fprintf('delete plot %d\n',measi);
            obj.activeFunctionNames(measi) = [];
            obj.createUi();
        end
        
        function addPlotCallback(obj, ~, ~)
%             fprintf('delete plot %d\n',measi);
            obj.activeFunctionNames{end+1} = obj.allMeasurementNames{1};
            obj.createUi();
%             obj.redrawPlots();
        end        
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axesHandles(1), t);
        end
        
        function handleEpoch(obj, epoch)
            % process this epoch and add to epochData array
            if ~epoch.hasResponse(obj.device)
                error(['Epoch does not contain a response for ' obj.device.name]);
            end
            
            e = struct();
            
            e.responseObject = epoch.getResponse(obj.device);
            e.signal = e.responseObject.getData();
            e.sampleRate = e.responseObject.sampleRate.quantityInBaseUnits;
            e.splitParameter = epoch.parameters(obj.epochSplitParameter);
                        
            msToPts = @(t)max(round(t / 1e3 * e.sampleRate), 1);
            
            % setup time regions for analysis
            %             if ~isempty(obj.baselineRegion)
            %                 x1 = msToPts(obj.baselineRegion(1));
            %                 x2 = msToPts(obj.baselineRegion(2));
            %                 baseline = e.signal(x1:x2);
            %                 e.signal = e.signal - mean(baseline);
            %             end
            
            if ~isempty(obj.measurementRegion)
                x1 = msToPts(obj.measurementRegion(1));
                x2 = msToPts(obj.measurementRegion(2));
                e.signal = e.signal(x1:x2);
            end
            
            % make analysis measurements
            e.measurements = containers.Map();
            for i = 1:numel(obj.allMeasurementNames)
                fcn = str2func(obj.allMeasurementNames{i});
                result = fcn(e.signal);
                e.measurements(obj.allMeasurementNames{i}) = result;
            end
            
            obj.epochData{end+1} = e;
            obj.redrawPlots();
        end
        
        function redrawPlots(obj)
              
            % then loop through all the epochs we have and plot them
            
            for measi = 1:numel(obj.activeFunctionNames)
                funcName = obj.activeFunctionNames{measi};
                % regenerate the independent axis variables
                paramByEpoch = [];
                for ei = 1:length(obj.epochData)
                    epoc = obj.epochData{ei};
                    paramByEpoch(ei) = epoc.splitParameter;
                end
                X = sort(unique(paramByEpoch));
                
                allMeasurementsByX = {};
                allMeasurementsByEpoch = [];
                for ei = 1:length(obj.epochData)
                    epoc = obj.epochData{ei};
                    whichXIndex = find(X == epoc.splitParameter);
                    thisMeas = epoc.measurements(funcName);
                    allMeasurementsByEpoch(ei) = thisMeas;
                    if length(allMeasurementsByX) < whichXIndex
                        allMeasurementsByX{whichXIndex} = thisMeas;
                    else
                        prevMeasurements = allMeasurementsByX{whichXIndex};
                        allMeasurementsByX{whichXIndex} = [prevMeasurements, thisMeas];
                    end
                end
                
                Y = [];
                Y_std = [];
                for i = 1:length(X);
                    Y(i) = mean(allMeasurementsByX{i});
                    Y_std(i) = std(allMeasurementsByX{i});
                end
                
%                 axh = obj.axesHandles
                if strcmp(obj.plotMode, 'cartesian')
                    errorbar(obj.axesHandles(measi), X, Y, Y_std);
                else
%                     axes(obj.axesHandles(measi));
                    cla(obj.axesHandles(measi))
                    X_rad = deg2rad(X);
                    X_rad(end+1) = X_rad(1);
                    Y(end+1) = Y(1);
                    Y_std(end+1) = Y_std(1);
                    polarplot(obj.axesHandles(measi), X_rad, Y, '-o');
                    hold(obj.axesHandles(measi), 'on');
                    polarplot(obj.axesHandles(measi), X_rad, Y + Y_std, '--r');
                    polarplot(obj.axesHandles(measi), X_rad, Y - Y_std, '--r');
                    hold(obj.axesHandles(measi), 'off');
                end
%                 boxplot(obj.axesHandles(measi), allMeasurementsByEpoch, paramByEpoch);
                title(obj.axesHandles(measi), funcName);
                
                %                 for ei = 1:length(obj.epochData)
                %                     epoc = obj.epochData{ei};
                %
                %                     measurement = epoc.measurements(measi);
                %
                %                     if numel(obj.markers) < measi
                %                         colorOrder = get(groot, 'defaultAxesColorOrder');
                %                         color = colorOrder(mod(measi - 1, size(colorOrder, 1)) + 1, :);
                %                         obj.markers(measi) = line(1, measurement, 'Parent', obj.axesHandles(measi), ...
                %                             'LineStyle', 'none', ...
                %                             'Marker', 'o', ...
                %                             'MarkerEdgeColor', color, ...
                %                             'MarkerFaceColor', color);
                %                     else
                %                         x = get(obj.markers(measi), 'XData');
                %                         y = get(obj.markers(measi), 'YData');
                %                         set(obj.markers(measi), 'XData', [x x(end)+1], 'YData', [y measurement]);
                %                     end
            end
        end
        
    end
end


