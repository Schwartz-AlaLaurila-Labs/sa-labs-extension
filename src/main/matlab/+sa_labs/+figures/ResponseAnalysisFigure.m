classdef ResponseAnalysisFigure < symphonyui.core.FigureHandler
    % Plots statistics calculated from the response of a specified device for each epoch run.
    
    properties (SetAccess = private)
        devices
        numChannels
        activeFunctionNames
        epochData
        allMeasurementNames = {'mean','var','max','min','sum','std'};
        plotMode
        responseAxis
        responseAxisSpikeRate
        signalAxes
        rightBox
        epochSplitParameter
        channelNames
        totalNumEpochs
        analysisRegion
        
        responseMode % 'Whole cell' or 'Cell attached'
        spikeThreshold
        spikeDetectorMode
        spikeRateBinLength
    end
    
    properties % not private access
        
    end
    
    properties (Access = private)
        axesHandlesAnalysis
        
        markers
        spikeDetector
    end
    
    methods
        
        function obj = ResponseAnalysisFigure(devices, varargin)
            obj = obj@symphonyui.core.FigureHandler();
           
            ip = inputParser();
            ip.addParameter('activeFunctionNames', {'mean'});
            ip.addParameter('epochSplitParameter', '', @(x)ischar(x));
            ip.addParameter('plotMode', 'cartesian', @(x)ischar(x));
            ip.addParameter('responseMode','Whole cell', @(x)ischar(x));
            ip.addParameter('spikeDetectorMode',@(x)ischar(x));
            ip.addParameter('spikeThreshold', 0, @(x)isnumeric(x));
            ip.addParameter('spikeRateBinLength', 0.05, @(x)isnumeric(x));
            ip.addParameter('totalNumEpochs',1,@(x)isnumeric(x));
            ip.addParameter('analysisRegion',[0,inf]);
            ip.parse(varargin{:});
            
            obj.devices = devices;
            obj.numChannels = length(obj.devices);
            obj.activeFunctionNames = ip.Results.activeFunctionNames;
            obj.epochSplitParameter = ip.Results.epochSplitParameter;
            obj.plotMode = ip.Results.plotMode;
            obj.responseMode = ip.Results.responseMode;
            obj.spikeThreshold = ip.Results.spikeThreshold;
            obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            obj.spikeRateBinLength = ip.Results.spikeRateBinLength;
            obj.totalNumEpochs = ip.Results.totalNumEpochs;
            obj.analysisRegion = ip.Results.analysisRegion;
            
            obj.createUi();
            
            obj.epochData = {};
            
            obj.spikeDetector = sa_labs.util.SpikeDetector(obj.spikeDetectorMode, obj.spikeThreshold);
%             obj.spikeDetector.sampleInterval = 1E-4;
        end
        
        function createUi(obj)
            import appbox.*;
            
            set(obj.figureHandle, 'Name', 'Response Analysis Figure');
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            fullBox = uix.HBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
            leftBox = uix.VBoxFlex('Parent', fullBox, 'Spacing', 10);
            
            % top left response (w/ spike rate too)
            obj.responseAxis = axes('Parent', leftBox);%, 'Units', 'normalized','Position',[.1 .1 .5 .5]);
            if strcmp(obj.responseMode, 'Cell attached')
                obj.responseAxisSpikeRate = axes('Parent', leftBox);
            end
            
            % bottom left analysis over param
            obj.axesHandlesAnalysis = [];
            rowBoxes = [];
            plotControlBoxes = [];
            measListBoxes = [];
            delPlotButtons = [];
            for measi = 1:numel(obj.activeFunctionNames)
                funcName = obj.activeFunctionNames{measi};
                
                rowBoxes(measi) = uix.HBox('Parent',leftBox);
                
                switch obj.plotMode
                    case {'cartesian', 'autocenter'}
                        obj.axesHandlesAnalysis(measi) = axes('Parent', rowBoxes(measi));
                    case 'polar'
                        %obj.axesHandlesAnalysis(measi) = polaraxes('Parent', rowBoxes(measi));
                        obj.axesHandlesAnalysis(measi) = axes('Parent', rowBoxes(measi));
                end
                
                plotControlBoxes(measi) = uix.VBox('Parent',rowBoxes(measi));
                
                thisFuncIndex = find(not(cellfun('isempty', strfind(obj.activeFunctionNames, funcName))), 1);
                
                measListBoxes(measi) = uicontrol( 'Style', 'listbox', 'Parent', plotControlBoxes(measi), ...
                    'String', obj.allMeasurementNames, 'Value',thisFuncIndex, 'Back', 'w',...
                    'Callback',{@obj.functionSelectorCallback, measi});
                
%                 delPlotButtons(measi) = uicontrol('Style','pushbutton', 'Parent', plotControlBoxes(measi),...
%                     'String', 'del', 'Callback',{@obj.deletePlotCallback, measi});
                
%                 set(plotControlBoxes(measi), 'Heights', [-1, 30])
                
                set(rowBoxes(measi), 'Widths', [-3 80]);
            end
            
            buttonArea = uix.HButtonBox('Parent',leftBox,'ButtonSize', [100, 30]);
%             newPlotButton = uicontrol('Style','pushbutton', 'Parent', buttonArea, 'String', 'new plot','Callback',@obj.addPlotCallback);
            redrawButton = uicontrol('Style','pushbutton', 'Parent', buttonArea, 'String', 'redraw','Callback',@obj.redrawPlotCallback);
            resetDataButton = uicontrol('Style','pushbutton', 'Parent', buttonArea, 'String', 'reset plot','Callback',@obj.resetDataCallback);
            
            if strcmp(obj.responseMode, 'Cell attached')
                boxHeights = [-.6, -.5];
            else
                boxHeights = -1;
            end
            set(leftBox, 'Heights', horzcat(boxHeights, -1 * ones(1,length(obj.activeFunctionNames)), 30))
            
            % right side signals over time for each param value
            obj.rightBox = uix.VBox('Parent', fullBox);
            obj.signalAxes = [];
            set(fullBox, 'Widths', [-1, -.5]);
        end
        
        function refreshUi(obj)
            % split out the parts needed to add an analysis graph from the rest, so they don't get deleted so much
        end
        
        function resetDataCallback(obj, ~, ~)
            obj.epochData = {};
            obj.createUi();
            obj.redrawPlots()
        end
        
        function redrawPlotCallback(obj, ~, ~)
            obj.createUi();
            obj.redrawPlots()
        end
        
        function functionSelectorCallback(obj, hObject, ~, measi)
            items = get(hObject,'String');
            index_selected = get(hObject,'Value');
            item_selected = items{index_selected};
            obj.activeFunctionNames{measi} = item_selected;
        end
        
        function deletePlotCallback(obj, ~, ~, measi)
            obj.activeFunctionNames(measi) = [];
            obj.createUi();
            obj.redrawPlots()
        end
        
        function addPlotCallback(obj, ~, ~)
            obj.activeFunctionNames{end+1} = obj.allMeasurementNames{1};
            obj.createUi();
            obj.redrawPlots()
        end
        
        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axesHandlesAnalysis(1), t);
        end
        
        
        function handleEpoch(obj, epoch)
            try
                obj.doHandleEpoch(epoch);
                
            catch e
                disp(getReport(e));
                
                rethrow(e);
            end
        end
        
        function doHandleEpoch(obj, epoch)
            channels = cell(obj.numChannels, 1);
            obj.channelNames = cell(obj.numChannels,1);
            
              
            for ci = 1:obj.numChannels
                obj.channelNames{ci} = obj.devices{ci}.name;
%                     fprintf('processing input from channel %d: %s\n',ci,obj.devices{ci}.name)
                % process this epoch and add to epochData array
                if ~epoch.hasResponse(obj.devices{ci})
                    disp(['Epoch does not contain a response for ' obj.devices{ci}.name]);
                    continue
                end

                e = struct();
                e.responseObject = epoch.getResponse(obj.devices{ci});
                [e.rawSignal, e.units] = e.responseObject.getData();
%                     e.responseObject
                e.sampleRate = e.responseObject.sampleRate.quantityInBaseUnits;
                e.t = (0:length(e.rawSignal)-1) / e.sampleRate;
                if ~isempty(obj.epochSplitParameter)
                    e.splitParameter = epoch.parameters(obj.epochSplitParameter);
                else
                    e.splitParameter = 0; % useful when you still want parameter extraction, but no independent vars
                end
%                     msToPts = @(t)max(round(t / 1e3 * e.sampleRate), 1);

                if strcmp(obj.responseMode, 'Whole cell')
                    e.signal = e.rawSignal;
                    e.spikeTimes = [];
                else
                    % Extract spikes from signal
                    result = obj.spikeDetector.detectSpikes(e.rawSignal);
                    spikeFrames = result.sp;
                    e.spikeTimes = e.t(spikeFrames);

                    % Generate spike rate signals
%                         spikeRate = zeros(size(e.rawSignal));
%                         spikeRate(spikeFrames) = 1.0;
                    spikeBins = [0:obj.spikeRateBinLength:max(e.t), inf];
                    spikeRate_binned = histcounts(e.spikeTimes, spikeBins);
%                         spikeRate_smoothed = resample(spikeRate_binned, spikeBins(1:end-1), e.sampleRate);
                    spikeRate_smoothed = interp1(spikeBins(1:end-1), spikeRate_binned, e.t, 'pchip');
%                         whos spikeRate_smoothed
%                         f = hann(e.sampleRate / 10);
%                         spikeRate_smoothed = filtfilt(f, 1, spikeRate); % 10 ms (100 samples) window filter
                    spikeRate_smoothed = spikeRate_smoothed / obj.spikeRateBinLength;
                    e.signal = spikeRate_smoothed';

                end

                % setup time regions for analysis
                % remove baseline signal
                %             if ~isempty(obj.baselineRegion)
                %                 x1 = msToPts(obj.baselineRegion(1));
                %                 x2 = msToPts(obj.baselineRegion(2));
                %                 baseline = e.signal(x1:x2);
                %                 e.signal = e.signal - mean(baseline);
                %             end

%                     if ~isempty(obj.measurementRegion)
%                         x1 = msToPts(obj.measurementRegion(1));
%                         x2 = msToPts(obj.measurementRegion(2));
%                         e.signal = e.signal(x1:x2);
%                     end

                % make analysis measurements
                e.measurements = containers.Map();
                signalInAnalysisRegion = e.signal(e.t > obj.analysisRegion(1) & e.t < obj.analysisRegion(2));
                for i = 1:numel(obj.allMeasurementNames)
                    fcn = str2func(obj.allMeasurementNames{i});
                    result = fcn(signalInAnalysisRegion);
                    e.measurements(obj.allMeasurementNames{i}) = result;
                end

                channels{ci} = e;
            end
            
            obj.epochData{end+1,1} = channels;
            
            obj.redrawPlots();
        end
        
        function redrawPlots(obj)
            if isempty(obj.epochData)
                return
            end
            
            colorOrder = get(groot, 'defaultAxesColorOrder');
            
            %plot the most recent response at the top
            hold(obj.responseAxis, 'off')
            if strcmp(obj.responseMode, 'Cell attached')
                hold(obj.responseAxisSpikeRate, 'off')
            end
            
            ylimRange = [];
            for ci = 1:obj.numChannels
                color = colorOrder(mod(ci - 1, size(colorOrder, 1)) + 1, :);
                epoch = obj.epochData{end}{ci};
                signal = epoch.responseObject.getData();
                plot(obj.responseAxis, epoch.t, signal, 'Color', color);
                signalHeight = max(signal) - min(signal);
                ylimRange(ci,:) = [min(signal) - 0.1 * signalHeight - eps, max(signal) + 0.1 * signalHeight + eps];
                
                hold(obj.responseAxis, 'on');
                set(obj.responseAxis,'LooseInset',get(obj.responseAxis,'TightInset'))
                title(obj.responseAxis, sprintf('Previous: %s: %g (%g of %g)', obj.epochSplitParameter, epoch.splitParameter, length(obj.epochData), obj.totalNumEpochs))
                ylabel(obj.responseAxis, epoch.units, 'Interpreter', 'none');                
                
                if strcmp(obj.responseMode, 'Cell attached')
                    % plot spikes detected
                    spikeTimes = epoch.spikeTimes;
                    [~, spikeFrames] = ismember(spikeTimes, epoch.t);
                    spikeHeights = signal(spikeFrames);
                    plot(obj.responseAxis, spikeTimes, spikeHeights, '.');
                    
                    h = plot(obj.responseAxisSpikeRate, epoch.t, epoch.signal, 'Color', color, 'LineWidth', 3);
                    hold(obj.responseAxisSpikeRate, 'on')
                    ylim(obj.responseAxisSpikeRate, [0, max(epoch.signal) * 1.1 + .1]);
                    ylabel(obj.responseAxisSpikeRate, '/sec');
                    
                    for si = 1:length(spikeTimes)
                        line(obj.responseAxisSpikeRate, [spikeTimes(si), spikeTimes(si)], ylim(obj.responseAxisSpikeRate), 'Color', [.8, .8, .8], 'LineWidth', 0.1);
                    end
                    
                    uistack(h, 'top');
                    set(obj.responseAxisSpikeRate,'LooseInset',get(obj.responseAxisSpikeRate,'TightInset'))
                end

            end
            %             legend(obj.responseAxis, obj.channelNames , 'Location', 'east')
            line(obj.responseAxis, [obj.analysisRegion(1), obj.analysisRegion(1)], ylim(obj.responseAxis),'Color','g')
            line(obj.responseAxis, [obj.analysisRegion(2), obj.analysisRegion(2)], ylim(obj.responseAxis),'Color','r')
            hold(obj.responseAxis, 'off')
            if strcmp(obj.responseMode, 'Cell attached')
                hold(obj.responseAxisSpikeRate, 'off')
            end
            ylim(obj.responseAxis, [min(ylimRange(:,1))-.1, max(ylimRange(:,2))+.1]);
            
            %             then loop through all the epochs we have and plot them
            
            
            % left graphs, where each signal feature is plotted across epoch parameters
            for measi = 1:numel(obj.activeFunctionNames)
                funcName = obj.activeFunctionNames{measi};
                for ci = 1:obj.numChannels

                    color = colorOrder(mod(ci - 1, size(colorOrder, 1)) + 1, :);

                    if ci == 1
                        hold(obj.axesHandlesAnalysis(measi), 'off');
                    else
                        hold(obj.axesHandlesAnalysis(measi), 'on');
                    end

                    % regenerate the independent axis variables
                    paramByEpoch = [];
                    for ei = 1:length(obj.epochData)
                        epoch = obj.epochData{ei}{ci};
                        paramByEpoch(ei) = epoch.splitParameter;
                    end
                    X = sort(unique(paramByEpoch));

                    allMeasurementsByX = {};
                    allMeasurementsByEpoch = [];
                    for ei = 1:length(obj.epochData)
                        epoch = obj.epochData{ei}{ci};
                        whichXIndex = find(X == epoch.splitParameter);
                        thisMeas = epoch.measurements(funcName);
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
                    for i = 1:length(X)
                        Y(i) = mean(allMeasurementsByX{i});
                        Y_std(i) = std(allMeasurementsByX{i});
                    end

                    %                 axh = obj.axesHandlesAnalysis
                    thisAxis = obj.axesHandlesAnalysis(measi);
                    if strcmp(obj.plotMode, 'cartesian')
                        %                     errorbar(obj.axesHandlesAnalysis(measi), X, Y, Y_std);
                        plot(thisAxis, X, Y, '-o','LineWidth',2, 'Color', color);
                        hold(thisAxis, 'on');
                        plot(thisAxis, X, Y + Y_std, '.--','LineWidth',.5, 'Color', color);
                        plot(thisAxis, X, Y - Y_std, '.--','LineWidth',.5, 'Color', color);
                        hold(thisAxis, 'off');
                    else
                        %                     axes(obj.axesHandlesAnalysis(measi));
                        
                        X_rad = deg2rad(X);
                        % compute DSI
                        vects = sum(Y .* exp(sqrt(-1) * X_rad)) / sum(Y);
                        dsi = abs(vects);
                        dsang = rad2deg(angle(vects));
                        
                        X_rad(end+1) = X_rad(1);
                        Y(end+1) = Y(1);
                        Y_std(end+1) = Y_std(1);
                        
                        %Changed 03/11/2020 to do pseudo-polarplots
                        % obviously we would want to call axis() and
                        % grid() at initialization time for efficiency
                        
                        %polarplot(thisAxis, X_rad, Y, '-o','LineWidth',2, 'Color', color);
                        plot(thisAxis, Y.*cos(X_rad), Y.*sin(X_rad), '-o','LineWidth',2, 'Color', color);
                        
                        hold(thisAxis, 'on');
                        
                        %polarplot(thisAxis, X_rad, Y + Y_std, '.--','LineWidth',.5, 'Color', color);
                        %polarplot(thisAxis, X_rad, Y - Y_std, '.--','LineWidth',.5, 'Color', color);
                        plot(thisAxis, (Y+Y_std).*cos(X_rad), (Y+Y_std).*sin(X_rad), '.--','LineWidth',.5, 'Color', color);
                        plot(thisAxis, (Y-Y_std).*cos(X_rad), (Y-Y_std).*sin(X_rad), '.--','LineWidth',.5, 'Color', color);
                        axis(thisAxis,'square');
                        grid(thisAxis,'on');
                        
                        title(thisAxis, sprintf('DSI: %g Angle: %g deg', dsi, dsang));
                        hold(thisAxis, 'off');
                    end
                    %                 boxplot(thisAxis, allMeasurementsByEpoch, paramByEpoch);
%                     title(thisAxis, funcName);
                    set(thisAxis,'LooseInset',get(thisAxis,'TightInset')) % remove the blasted whitespace

                    %                 for ei = 1:length(obj.epochData)
                    %                     epoc = obj.epochData{ei};
                    %
                    %                     measurement = epoc.measurements(measi);
                    %
                    %                     if numel(obj.markers) < measi
                    %                         colorOrder = get(groot, 'defaultAxesColorOrder');
                    %                         color = colorOrder(mod(measi - 1, size(colorOrder, 1)) + 1, :);
                    %                         obj.markers(measi) = line(1, measurement, 'Parent', obj.axesHandlesAnalysis(measi), ...
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

            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % right side, where mean signal is plotted over time for each parameter
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            ci = 1;
            paramByEpoch = [];
            for ei = 1:length(obj.epochData)
                epoch = obj.epochData{ei}{ci};
                paramByEpoch(ei) = epoch.splitParameter; %#ok<AGROW>
            end
            paramValues = sort(unique(paramByEpoch));

            % add a new plot to the end if we need one
            while length(obj.signalAxes) < length(paramValues)
                newAxis = axes('Parent', obj.rightBox);
                obj.signalAxes(length(paramValues)) = newAxis;
            end

            range = [inf, -inf];
            for paramValueIndex = 1:length(paramValues)
                paramValue = paramValues(paramValueIndex);
                thisAxis = obj.signalAxes(paramValueIndex);
                if thisAxis > 0
                    hold(thisAxis, 'off');
                end

                for ci = 1:obj.numChannels
                    signals = [];
                    for ei = 1:length(obj.epochData)
                        epoch = obj.epochData{ei}{ci};
                        if paramValue == epoch.splitParameter
                            signals(end+1, :) = epoch.signal;
                            t = epoch.t;
                        end
                    end
                    plotval = mean(signals, 1);
                    plotstd = std(signals, 0, 1) / size(signals,1);
                    numSignalsCombined = size(signals, 1);

                    range(1) = min(min(plotval), range(1));
                    range(2) = max(max(plotval), range(2));

                    color = colorOrder(mod(ci - 1, size(colorOrder, 1)) + 1, :);
                    plot(thisAxis, t, plotval,'LineWidth',1, 'Color', color);
                    hold(thisAxis,'on')
                    plot(thisAxis, t, plotval+plotstd, 'LineWidth', .5, 'Color', color);
                    plot(thisAxis, t, plotval-plotstd, 'LineWidth', .5, 'Color', color);
%                     sa_labs.util.shadedErrorBar(thisAxis, t', plotval', plotstd')
                    xlim(thisAxis, [t(1), t(end)])
                    if ~isempty(obj.epochSplitParameter)
                        titl = title(thisAxis, sprintf('%s: %g, %g repeats', obj.epochSplitParameter,paramValue,numSignalsCombined));
%                         text(thisAxis, 0.5, .5, 0, 'test')
                    end
                    if paramValueIndex < length(paramValues)
                        set(thisAxis, 'XTickLabel', '');
                    end
                    set(thisAxis,'LooseInset',get(thisAxis,'TightInset')) % remove the blasted whitespace

                end
                hold(thisAxis,'off')

            end

            % expand the ylims a bit
            range(1) = range(1) - diff(range) * .05;
            range(2) = range(2) + diff(range) * .05;

            if strcmp(obj.responseMode, 'Cell attached')
                range(1) = 0;
            end        
            if abs(diff(range)) > 0
                for i = 1:length(paramValues)
                    ylim(obj.signalAxes(i), range);
                end
            end
        end
    end
end


