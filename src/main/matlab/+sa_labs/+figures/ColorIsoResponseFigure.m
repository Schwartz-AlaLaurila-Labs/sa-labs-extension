classdef ColorIsoResponseFigure < symphonyui.core.FigureHandler

    properties
        deviceName
        epochIndex
        spikeThreshold
        spikeDetectorMode
        spikeDetector
        analysisRegion
        devices
        
        nextContrast1
        nextContrast2
        nextStimulus = [];
        colorNames
        
        contrastRange1
        contrastRange2
        
        epochData
        responseData
        pointData
        interpolant = [];
        
        isoPlotClickMode = 'select'
        isoPlotClickCountRemaining = 0;
        isoPlotClickHistory = [];        
        
        handles
    end

    
    methods
        
        function obj = ColorIsoResponseFigure(devices, varargin)
            obj = obj@symphonyui.core.FigureHandler();
            
            ip = inputParser;
            ip.KeepUnmatched = true;
            ip.addParameter('spikeThreshold', 20, @(x)isnumeric(x));
            ip.addParameter('spikeDetectorMode', 'Stdev', @(x)ischar(x));
            ip.addParameter('colorNames',{'',''});
            ip.addParameter('analysisRegion', [0,inf]);
            ip.addParameter('contrastRange1', [-1,1]);
            ip.addParameter('contrastRange2', [-1,1]);
            
            ip.parse(varargin{:});
            
            obj.devices = devices;
            obj.epochIndex = 0;
            obj.spikeThreshold = ip.Results.spikeThreshold;
            obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            obj.spikeDetector = sa_labs.util.SpikeDetector(obj.spikeDetectorMode, obj.spikeThreshold);
            obj.analysisRegion = ip.Results.analysisRegion;
            obj.contrastRange1 = ip.Results.contrastRange1;
            obj.contrastRange2 = ip.Results.contrastRange2;
            obj.colorNames = ip.Results.colorNames;
                       
            obj.resetPlots();
            obj.createUi();
            obj.updateUi();
            
            obj.nextStimulus = [];
            obj.waitIfNecessary();
            obj.assignNextStimulus();
        end
        
        
        function createUi(obj)
            
            import appbox.*;
            
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            obj.handles.figureBox = uix.HBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
            
            obj.handles.measurementDataBox = uix.VBox('Parent', obj.handles.figureBox, 'Spacing', 10);
            obj.handles.epochTable = uitable('Parent', obj.handles.measurementDataBox, ...
                                    'ColumnName', {'contrast 1', 'contrast 2', 'mean resp', 'std','rep'}, ...
                                    'CellSelectionCallback', @obj.epochTableSelect);
            obj.handles.nextStimulusTable = uitable('Parent', obj.handles.measurementDataBox, ...
                                    'ColumnName', {'contrast 1', 'contrast 2'});
            obj.handles.epochResponseAxes = axes('Parent', obj.handles.measurementDataBox);
            
            obj.handles.isoDataBox = uix.VBox('Parent', obj.handles.figureBox, 'Spacing', 10);
            obj.handles.isoAxes = axes('Parent', obj.handles.isoDataBox, ...
                        'ButtonDownFcn', @obj.clickIsoPlot);
            
            obj.handles.actionButtonBox = uix.VButtonBox('Parent', obj.handles.figureBox, ...
                        'Spacing', 5, 'ButtonSize', [180, 40]);
            obj.handles.selectNewStimulusPointButton = uicontrol('Style', 'pushbutton', ...
                        'String', 'New Point',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateNextStimulusPoint());
            obj.handles.selectNewStimulusLineButton = uicontrol('Style', 'pushbutton', ...
                        'String', 'New Line',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateNextStimulusLine());
            obj.handles.selectNewStimulusGridButton = uicontrol('Style', 'pushbutton', ...
                        'String', 'New Grid',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateNextStimulusGrid());
            obj.handles.selectBaseGridButton = uicontrol('Style', 'pushbutton', ...
                        'String', 'Baseline',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateBaseGridStimulus());
            obj.handles.clearNextStimulusButton = uicontrol('Style', 'pushbutton', ...
                        'String', 'Clear Next',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.clearNextStimulus());                    
            obj.handles.resumeProtocolButton = uicontrol('Style', 'pushbutton', ...
                        'String', 'Resume',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.resumeProtocol());
                    
            obj.handles.figureBox.Widths = [350, -1, 100];
        end
        
        
        function handleEpoch(obj, epoch)
            obj.epochIndex = obj.epochIndex + 1;
            
            responseObject = epoch.getResponse(obj.devices{1}); %only one channel for now
            [signal, ~] = responseObject.getData();
%             sampleRate = responseObject.sampleRate.quantityInBaseUnits;
            
            e = struct();
            e.signal = signal;
            e.t = (1:numel(e.signal)) / responseObject.sampleRate.quantityInBaseUnits;
            e.parameters = epoch.parameters;

            result = obj.spikeDetector.detectSpikes(signal);
            spikeFrames = result.sp;
            spikeTimes = e.t(spikeFrames);
            % get spike count in analysis region
%             e.response = sum(spikeTimes > obj.analysisRegion(1) & spikeTimes < obj.analysisRegion(2));
            e.response = round(10 * e.parameters('contrast1') + 7 * e.parameters('contrast2') + 10 * rand());
            obj.responseData(obj.epochIndex, :) = [e.parameters('contrast1'), e.parameters('contrast2'), e.response];

            e.spikeTimes = spikeTimes;
            e.spikeFrames = spikeFrames;
            
            % add the epoch to the array
            obj.epochData{obj.epochIndex, 1} = e;

            obj.analyzeData();
            obj.updateUi();
           
            obj.waitIfNecessary();
%             obj.generateNextStimulusAutomatic()
            
            obj.assignNextStimulus();
        end
        
        function analyzeData(obj)
%             thisEpoch = obj.epochData{end};

            % combine responses into points
            [points, ~, indices] = unique(obj.responseData(:,[1,2]), 'rows');
            for i = 1:size(points,1)
                obj.pointData(i,:) = [points(i,1), points(i,2), mean(obj.responseData(indices == i, 3)), std(obj.responseData(indices == i, 3)), sum(indices == i)];
            end
            
            % calculate map of current results
            if size(obj.pointData, 1) >= 3
                c1 = obj.pointData(:,1);
                c2 = obj.pointData(:,2);
                r = obj.pointData(:,3);
                obj.interpolant = scatteredInterpolant(c1, c2, r, 'linear', 'none');
            end

        end
        
        function generateBaseGridStimulus(obj)
            bootstrapContrasts = [[obj.contrastRange1(2),0];
                                  [0,                    obj.contrastRange2(2)];
                                  [obj.contrastRange1(2),obj.contrastRange2(2)];
                                  [obj.contrastRange1(1),obj.contrastRange2(1)];

                                  [0,                    obj.contrastRange2(1)];
                                  [obj.contrastRange1(1),0];

                                  [obj.contrastRange1(2),obj.contrastRange2(1)];
                                  [obj.contrastRange1(1),obj.contrastRange2(2)]];

            obj.nextStimulus = vertcat(obj.nextStimulus, bootstrapContrasts);
            obj.updateUi();
        end
        
        function generateNextStimulusPoint(obj)
            obj.isoPlotClickMode = 'newpoint';
        end
        
        function generateNextStimulusLine(obj)
            obj.isoPlotClickMode = 'newline';
            obj.isoPlotClickCountRemaining = 2;
        end
        
        function generateNextStimulusGrid(obj)
            obj.isoPlotClickMode = 'newgrid';
            obj.isoPlotClickCountRemaining = 2;
        end
        
        function clickIsoPlot(obj, ~, hit)
            int = hit.IntersectionPoint;
            c1 = int(1);
            c2 = int(2);
            
            switch obj.isoPlotClickMode
                case 'newpoint'
                    obj.nextStimulus = vertcat(obj.nextStimulus, [c1, c2]);
                    obj.isoPlotClickMode = 'select';
                    
                case 'newline'
                    obj.isoPlotClickHistory(end+1,:) = [c1,c2];
                    obj.isoPlotClickCountRemaining = obj.isoPlotClickCountRemaining - 1;
                    
                    if obj.isoPlotClickCountRemaining == 0
                        numLinePoints = inputdlg('Number of line points?');
                        if isempty(numLinePoints)
                            numLinePoints = 2;
                        else
                            numLinePoints = str2double(numLinePoints{1});
                        end
                        if numLinePoints < 2 || isnan(numLinePoints)
                            numLinePoints = 2;
                        end
                        startPoint = obj.isoPlotClickHistory(1,:);
                        endPoint = obj.isoPlotClickHistory(2,:);
                        step = (endPoint - startPoint) / (numLinePoints-1);
                        points = zeros(numLinePoints,2);
                        for p = 1:numLinePoints
                            points(p,:) = startPoint + step * (p-1);
                        end
                        
                        obj.nextStimulus = vertcat(obj.nextStimulus, points);
                        obj.isoPlotClickHistory = [];
                        obj.isoPlotClickMode = 'select';
                    end
                    
                case 'newgrid'
                    obj.isoPlotClickHistory(end+1,:) = [c1,c2];
                    obj.isoPlotClickCountRemaining = obj.isoPlotClickCountRemaining - 1;
                    
                    if obj.isoPlotClickCountRemaining == 0
                        numGridPoints = inputdlg('Number of grid edge points?');
                        if isempty(numGridPoints)
                            numGridPoints = 2;
                        else
                            numGridPoints = str2double(numGridPoints{1});
                        end
                        startPoint = obj.isoPlotClickHistory(1,:);
                        endPoint = obj.isoPlotClickHistory(2,:);
                        step = (endPoint - startPoint) / (numGridPoints-1);
                        
                        points = [];
                        for p1 = 1:numGridPoints
                            for p2 = 1:numGridPoints
                                p = (p1-1)*numGridPoints + p2;
                                points(p,:) = startPoint + step .* [p1-1, p2-1];
                            end
                        end
                        
                        obj.nextStimulus = vertcat(obj.nextStimulus, points);
                        obj.isoPlotClickHistory = [];
                        obj.isoPlotClickMode = 'select';
                    end
            end
            
            
            obj.updateUi();
        end
        
        function clearNextStimulus(obj)
            obj.nextStimulus = [];
            obj.updateUi();
        end
        
        function resumeProtocol(obj)
            if isempty(obj.nextStimulus)
                disp('empty stimulus list!')
            else
                uiresume(obj.figureHandle);
            end
        end
        
        function waitIfNecessary(obj)
            if isempty(obj.nextStimulus)
                disp('waiting for input')
                uiwait(obj.figureHandle);
            end
        end
            
            
        function assignNextStimulus(obj)
            % assign the contrasts to the next stimuli in the list
            obj.nextContrast1 = obj.nextStimulus(1, 1);
            obj.nextContrast2 = obj.nextStimulus(1, 2);
            obj.nextStimulus(1,:) = [];
        end
        
        
        function updateUi(obj)
            % update next stimulus table
            obj.handles.nextStimulusTable.Data = obj.nextStimulus;
            
            % update epoch table
            obj.handles.epochTable.Data = obj.pointData;
            
            % update iso data plot
            cla(obj.handles.isoAxes);
            hold(obj.handles.isoAxes, 'on');

            if ~isempty(obj.pointData)
                if ~isempty(obj.interpolant)
                    try
                        c1p = linspace(min(obj.pointData(:,1)), max(obj.pointData(:,1)), 20);
                        c2p = linspace(min(obj.pointData(:,2)), max(obj.pointData(:,2)), 20);
                        [C1p, C2p] = meshgrid(c1p, c2p);
                        int = obj.interpolant(C1p, C2p);
                        s = pcolor(obj.handles.isoAxes, C1p, C2p, int);
                        shading(obj.handles.isoAxes, 'flat');
                        set(s, 'PickableParts', 'none');
                        
%                         contour(obj.handles.isoAxes, C1p, C2p, int, 'k', 'ShowText','on', 'PickableParts', 'none')
                    end
                end

                % observations
                for oi = 1:size(obj.pointData,1)
                    scatter(obj.handles.isoAxes, obj.pointData(oi,1), obj.pointData(oi,2), 40, 'CData', obj.pointData(oi,3), ...
                        'LineWidth', 1, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'flat')
                end
            end
            
            % next stimulus points
            if ~isempty(obj.nextStimulus)
                scatter(obj.handles.isoAxes, obj.nextStimulus(:,1), obj.nextStimulus(:,2), 60, 'CData', [1,1,1], ...
                    'LineWidth', 1, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'flat')
            end
            
            % next plot click points
            if ~isempty(obj.isoPlotClickHistory)
                scatter(obj.handles.isoAxes, obj.isoPlotClickHistory(:,1), obj.isoPlotClickHistory(:,2), '+', ...
                    'LineWidth', 2, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'flat')
            end            
            
            xlabel(obj.handles.isoAxes, obj.colorNames{1});
            ylabel(obj.handles.isoAxes, obj.colorNames{2});
            xlim(obj.handles.isoAxes, obj.contrastRange1);
            ylim(obj.handles.isoAxes, obj.contrastRange2);
            set(obj.handles.isoAxes,'LooseInset',get(obj.handles.isoAxes,'TightInset'))
            hold(obj.handles.isoAxes, 'off');
        end
        
        function epochTableSelect(obj, ~, data)
            ei = data.Indices(1);
            e = obj.epochData{ei};
            plot(obj.handles.epochResponseAxes, e.t, e.signal);
            hold(obj.handles.epochResponseAxes, 'on')
            plot(obj.handles.epochResponseAxes, e.spikeTimes, e.signal(e.spikeFrames), '.');
            hold(obj.handles.epochResponseAxes, 'off')
        end
        
        function clearFigure(obj)
            obj.resetPlots();
            clearFigure@FigureHandler(obj);
        end
        
        function resetPlots(obj)
            obj.epochData = {};
            obj.epochIndex = 0;
            obj.responseData = [];
            obj.pointData = [];
            obj.interpolant = [];
            obj.nextStimulus = [];
        end
    end
    
%     
%     methods (Static)
%         function settings = storedSettings(stuffToStore)
%             % This method stores means across figure handlers.
% 
%             persistent stored;
%             if nargin > 0
%                 stored = stuffToStore
%             end
%             settings = stored
%         end
%         
%     end
    
end