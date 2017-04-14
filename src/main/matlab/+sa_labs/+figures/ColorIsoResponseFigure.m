classdef ColorIsoResponseFigure < symphonyui.core.FigureHandler

    properties
        deviceName
        epochIndex
        spikeThreshold
        spikeDetectorMode
        spikeDetector
        analysisRegion
        devices
        responseMode
        
        nextContrast1
        nextContrast2
        baseIntensity1
        baseIntensity2
        stimulusInfo
        nextStimulus = [];
        nextStimulusInfo
        nextStimulusInfoOutput
        colorNames
%         stimulusModes = {'default','ramp'};
        
        plotRange1
        plotRange2
        ignoreNextEpoch = false;
        runPausedSoMayNeedNullEpoch = true;
        protocolShouldStop = false;
           
        epochData
        
        pointData
        interpolant = [];
        
        isoPlotClickMode = 'select'
        isoPlotClickCountRemaining = 0;
        isoPlotClickHistory = [];
        selectedPoint = [];
        
        handles
    end
    
    properties (Dependent)
        contrastRange1
        contrastRange2
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
            ip.addParameter('baseIntensity1', .1);
            ip.addParameter('baseIntensity2', .1);
            ip.addParameter('responseMode','Whole cell', @(x)ischar(x));
            
            ip.parse(varargin{:});
            
            obj.devices = devices;
            obj.epochIndex = 0;
            obj.spikeThreshold = ip.Results.spikeThreshold;
            obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            obj.spikeDetector = sa_labs.util.SpikeDetector(obj.spikeDetectorMode, obj.spikeThreshold);
            obj.analysisRegion = ip.Results.analysisRegion;
            obj.baseIntensity1 = ip.Results.baseIntensity1;
            obj.baseIntensity2 = ip.Results.baseIntensity2;
            obj.colorNames = ip.Results.colorNames;
            obj.responseMode = ip.Results.responseMode;
            
            obj.plotRange1 = obj.contrastRange1;
            obj.plotRange2 = obj.contrastRange2;
                       
            obj.resetPlots();
            obj.createUi();
            obj.updateUi();
            
            obj.nextStimulus = [];
            obj.waitIfNecessary();
            if ~isvalid(obj)
                return
            end
            obj.assignNextStimulus();
        end
        
        
        function createUi(obj)
            
            import appbox.*;
            
            set(obj.figureHandle, 'Name', 'Color Response Figure');
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            obj.handles.figureBox = uix.HBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
            
            obj.handles.measurementDataBox = uix.VBoxFlex('Parent', obj.handles.figureBox, 'Spacing', 10);
            obj.handles.nextStimulusTable = uitable('Parent', obj.handles.measurementDataBox, ...
                                    'ColumnName', {'contrast 1', 'contrast 2'});            
            obj.handles.dataTable = uitable('Parent', obj.handles.measurementDataBox, ...
                                    'ColumnName', {'contr 1', 'contr 2', 'mean', 'VMR', 'rep'}, ...
                                    'ColumnWidth', {60, 60, 40, 40, 40}, ...
                                    'CellSelectionCallback', @obj.dataTableSelect);
            obj.handles.singlePointTable = uitable('Parent', obj.handles.measurementDataBox, ...
                                    'ColumnName', {'index', 'response'}, ...
                                    'ColumnWidth', {60, 60}, ...
                                    'CellSelectionCallback', @obj.singlePointTableSelect);

            obj.handles.epochSelectionAxes = axes('Parent', obj.handles.measurementDataBox);
            obj.handles.epochReponseAxes = axes('Parent', obj.handles.measurementDataBox);
            obj.handles.measurementDataBox.Heights = [-1, -2, -.5, -1, -1];
            
            obj.handles.isoDataBox = uix.VBox('Parent', obj.handles.figureBox, 'Spacing', 10);
            obj.handles.isoAxes = axes('Parent', obj.handles.isoDataBox, ...
                        'ButtonDownFcn', @obj.clickIsoPlot);
            
            obj.handles.actionButtonBox = uix.VButtonBox('Parent', obj.handles.figureBox, ...
                        'Spacing', 12, 'ButtonSize', [180, 30]);
            uicontrol('Style', 'pushbutton', ...
                        'String', 'New Point',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateNextStimulusPoint());
            uicontrol('Style', 'pushbutton', ...
                        'String', 'New Line',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateNextStimulusLine());
            uicontrol('Style', 'pushbutton', ...
                        'String', 'New Grid',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateNextStimulusGrid());
            uicontrol('Style', 'pushbutton', ...
                        'String', 'New Ramps',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateRamps());
            uicontrol('Style', 'pushbutton', ...
                        'String', 'Baseline Grid',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateBaseGridStimulus());
            uicontrol('Style', 'pushbutton', ...
                        'String', 'Overall Grid',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.generateOverallGridStimulus());    
            uicontrol('Style', 'text', ... % spacer
                        'Parent', obj.handles.actionButtonBox);
            uicontrol('Style', 'pushbutton', ...
                        'String', 'Add Selected',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.addSelectedPoint());
            uicontrol('Style', 'pushbutton', ...
                        'String', 'Add in Rect',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.addPointsInRectangle());                    
            uicontrol('Style', 'pushbutton', ...
                        'String', 'Add 4 nearest',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.addNearestPoints(4));
            uicontrol('Style', 'pushbutton', ...
                        'String', 'Add 4 noisiest',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.addNoisiestPoints(4));
            uicontrol('Style', 'text', ... % spacer
                        'Parent', obj.handles.actionButtonBox);                    
            uicontrol('Style', 'pushbutton', ...
                        'String', 'Clear queue',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.clearNextStimulus(), ...
                        'ForegroundColor','red');
            uicontrol('Style', 'pushbutton', ...
                        'String', 'Randomize queue',...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.randomizeStimulus());

            obj.handles.leadWithNullStimulusCheckbox = uicontrol('Style', 'checkbox', ...
                        'Value', true, ...
                        'String', 'Lead w/ null',...
                        'Parent', obj.handles.actionButtonBox);
            obj.handles.repeatStimCheckbox = uicontrol('Style', 'checkbox', ...
                        'Value', true, ...
                        'String', 'Repeat added stim',...
                        'Parent', obj.handles.actionButtonBox);
                    
            uicontrol('Style', 'pushbutton', ...
                        'String', 'Resume', 'FontWeight', 'bold', 'FontSize', 16, ...
                        'Parent', obj.handles.actionButtonBox,...
                        'Callback', @(a,b) obj.resumeProtocol());                    
                    
            obj.handles.figureBox.Widths = [300, -1, 100];
        end
        
        
        function handleEpoch(obj, epoch)
            if obj.ignoreNextEpoch
                disp('ignoring epoch');
                epoch.shouldBePersisted = false;
                obj.assignNextStimulus();
                obj.ignoreNextEpoch = false;
                return
            end
            obj.epochIndex = obj.epochIndex + 1;
            
            responseObject = epoch.getResponse(obj.devices{1}); %only one channel for now
            [signal, ~] = responseObject.getData();
%             sampleRate = responseObject.sampleRate.quantityInBaseUnits;
            
            e = struct();
            e.signal = signal;
            e.t = (1:numel(e.signal)) / responseObject.sampleRate.quantityInBaseUnits;
            e.parameters = epoch.parameters;
            e.ignore = false;

            if strcmp(obj.responseMode, 'Cell attached')
                result = obj.spikeDetector.detectSpikes(signal);
                spikeFrames = result.sp;
                spikeTimes = e.t(spikeFrames);
                % get spike count in analysis region
                e.response = sum(spikeTimes > obj.analysisRegion(1) & spikeTimes < obj.analysisRegion(2));
    %             e.response = round(10 * e.parameters('contrast1') + 7 * e.parameters('contrast2') + 10 * rand());
                e.spikeTimes = spikeTimes;
                e.spikeFrames = spikeFrames;    
            else
                signal = signal - median(signal(1:1000));
                signalInAnalysisRegion = signal(e.t > obj.analysisRegion(1) & e.t < obj.analysisRegion(2));
                e.response = mean(signalInAnalysisRegion);
            end

            
            % add the epoch to the array
            obj.epochData{obj.epochIndex, 1} = e;
            
            % plot the epoch in the response axis
            cla(obj.handles.epochReponseAxes);
            hold(obj.handles.epochReponseAxes, 'on');
            plot(obj.handles.epochReponseAxes, e.t, e.signal);
            if strcmp(obj.responseMode, 'Cell attached')
                plot(obj.handles.epochReponseAxes, e.spikeTimes, e.signal(e.spikeFrames), '.');
            end
            % draw analysis region limits
            line(obj.handles.epochReponseAxes, [obj.analysisRegion(1), obj.analysisRegion(1)], ylim(obj.handles.epochReponseAxes),'Color','g')
            line(obj.handles.epochReponseAxes, [obj.analysisRegion(2), obj.analysisRegion(2)], ylim(obj.handles.epochReponseAxes),'Color','r')
            hold(obj.handles.epochReponseAxes, 'off')
            set(obj.handles.epochReponseAxes,'LooseInset',get(obj.handles.isoAxes,'TightInset'))
            
            obj.analyzeData();
            obj.updateUi();
           
            obj.waitIfNecessary();
%             obj.generateNextStimulusAutomatic()

            if ~isvalid(obj)
                return
            end

            obj.selectedPoint = [];
            obj.assignNextStimulus();
        end
        
        function analyzeData(obj)
            % collect all the epochs into a response table
            responseData = [];
            for ei = 1:length(obj.epochData)
                e = obj.epochData{ei};
                if e.ignore
                    continue
                end
                responseData(end+1,:) = [e.parameters('contrast1'), e.parameters('contrast2'), e.response];
            end

            % combine responses into points
            [points, ~, indices] = unique(responseData(:,[1,2]), 'rows');
            for i = 1:size(points,1)
                m = mean(responseData(indices == i, 3));
                v = var(responseData(indices == i, 3));
                obj.pointData(i,:) = [points(i,1), points(i,2), m, v/abs(m), sum(indices == i)];
            end
            
            % calculate map of current results
            if size(obj.pointData, 1) >= 3
                c1 = obj.pointData(:,1);
                c2 = obj.pointData(:,2);
                r = obj.pointData(:,3);
                obj.interpolant = scatteredInterpolant(c1, c2, r, 'linear', 'none');
            end
            
            % calculate extents of display plot (though we can't actually go outside the range once calculated)
            obj.plotRange1 = [min([min(obj.pointData(:,1)), obj.contrastRange1(1)]), max([max(obj.pointData(:,1)), obj.contrastRange1(2)])];
            obj.plotRange2 = [min([min(obj.pointData(:,2)), obj.contrastRange2(1)]), max([max(obj.pointData(:,2)), obj.contrastRange2(2)])];
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
                              
            bootstrapContrasts = unique(bootstrapContrasts, 'rows');

            obj.addToStimulusWithRepeats(bootstrapContrasts);
        end
        
        function generateOverallGridStimulus(obj)
            newPoints = [];
            numGridPoints = inputdlg('Number of grid edge points?');
            if isempty(numGridPoints)
                return
            else
                numGridPoints = str2double(numGridPoints{1});
            end
            if numGridPoints < 2 || isnan(numGridPoints)
                return
            end                        
            startPoint = obj.contrastRange1(1);
            endPoint = obj.contrastRange2(2);
            step = (endPoint - startPoint) / (numGridPoints-1);

            for p1 = 1:numGridPoints
                for p2 = 1:numGridPoints
                    p = (p1-1)*numGridPoints + p2;
                    newPoints(p,:) = startPoint + step .* [p1-1, p2-1];
                end
            end
            obj.addToStimulusWithRepeats(newPoints);
        end
        
        function generateNextStimulusPoint(obj)
            obj.isoPlotClickMode = 'newpoint';
            obj.isoPlotClickCountRemaining = 1;
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
            newPoints = [];
            newInfo = {};
            
            switch obj.isoPlotClickMode
                case 'newpoint'
                    newPoints = [c1, c2];
                    obj.isoPlotClickMode = 'select';
                    
                case 'newline'
                    obj.isoPlotClickHistory(end+1,:) = [c1,c2];
                    obj.isoPlotClickCountRemaining = obj.isoPlotClickCountRemaining - 1;
                    
                    if obj.isoPlotClickCountRemaining == 0
                        numLinePoints = inputdlg('Number of line points?');
                        if isempty(numLinePoints)
                            return
                        else
                            numLinePoints = str2double(numLinePoints{1});
                        end
                        if numLinePoints < 2 || isnan(numLinePoints)
                            return
                        end
                        startPoint = obj.isoPlotClickHistory(1,:);
                        endPoint = obj.isoPlotClickHistory(2,:);
                        step = (endPoint - startPoint) / (numLinePoints-1);
                        
                        % make lines snap to vertical or horizontal
                        for di = 1:2
                            if abs(step(di)) < .1
                                step(di) = 0;
                            end
                        end
                        
                        for p = 1:numLinePoints
                            newPoints(p,:) = startPoint + step * (p-1);
                        end
                        
                        obj.isoPlotClickHistory = [];
                        obj.isoPlotClickMode = 'select';
                    end
                    
                case 'newgrid'
                    obj.isoPlotClickHistory(end+1,:) = [c1,c2];
                    obj.isoPlotClickCountRemaining = obj.isoPlotClickCountRemaining - 1;
                    
                    if obj.isoPlotClickCountRemaining == 0
                        numGridPoints = inputdlg('Number of grid edge points?');
                        if isempty(numGridPoints)
                            return
                        else
                            numGridPoints = str2double(numGridPoints{1});
                        end
                        if numGridPoints < 2 || isnan(numGridPoints)
                            return
                        end                        
                        startPoint = obj.isoPlotClickHistory(1,:);
                        endPoint = obj.isoPlotClickHistory(2,:);
                        step = (endPoint - startPoint) / (numGridPoints-1);
                        
                        for p1 = 1:numGridPoints
                            for p2 = 1:numGridPoints
                                p = (p1-1)*numGridPoints + p2;
                                newPoints(p,:) = startPoint + step .* [p1-1, p2-1];
                            end
                        end
                        
                        obj.isoPlotClickHistory = [];
                        obj.isoPlotClickMode = 'select';
                    end
                    
                    
                case 'ramps'
                    inp = inputdlg({'Number of ramp line points?', 'Fixed contrast 1?','Fixed contrast 2?'},...
                        'Ramp config',1,{'8',num2str(c1),num2str(c2)});
                    if isempty(inp)
                        return
                    else
                        numRampSteps = str2double(inp{1});
                        fixedContrast1 = str2double(inp{2});
                        fixedContrast2 = str2double(inp{3});
                    end
                    if numRampSteps < 2 || isnan(numRampSteps)
                        return
                    end
                    newInfo = {};
                    rampId = randi(100000000); % why not have an ID to make it easier later
                    rampSteps1 = linspace(obj.contrastRange2(1), obj.contrastRange2(2), numRampSteps)';
                    newPoints1 = horzcat(fixedContrast1 * ones(numRampSteps,1), rampSteps1);
                    for i = 1:numRampSteps
                        info = containers.Map({'stimulusMode'},{'ramp'},'UniformValues',false);
                        info('fixedContrast') = fixedContrast1;
                        info('fixedPattern') = 1;
                        info('rampId') = rampId;
                        newInfo{end+1, 1} = info;
                    end
                    rampSteps2 = linspace(obj.contrastRange1(1), obj.contrastRange1(2), numRampSteps)';
                    newPoints2 = horzcat(rampSteps2, fixedContrast2 * ones(numRampSteps,1));
                    for i = 1:numRampSteps
                        info = containers.Map({'stimulusMode'},{'ramp'},'UniformValues',false);
                        info('fixedContrast') = fixedContrast2;
                        info('fixedPattern') = 2;
                        info('rampId') = rampId;
                        newInfo{end+1, 1} = info;
                    end
                    newPoints = vertcat(newPoints1, newPoints2);

            end           
            
            if ~isempty(newInfo)
                obj.addToStimulusWithRepeats(newPoints, newInfo)
            else
                obj.addToStimulusWithRepeats(newPoints)
            end
            
            if obj.isoPlotClickCountRemaining > 0
                obj.updateUi();
            end
        end
        
        function generateRamps(obj)    
            
            obj.isoPlotClickMode = 'ramps';
            obj.isoPlotClickCountRemaining = 1;            

        end
        
        function addSelectedPoint(obj)
            obj.addToStimulusWithRepeats(obj.selectedPoint);
        end
        
        function addPointsInRectangle(obj)
            rect = getrect(obj.handles.isoAxes);
            points = [];
            for p = 1:size(obj.pointData, 1)
                point = obj.pointData(p,1:2);
                if point(1) > rect(1) && point(1) < rect(1) + rect(3) && point(2) > rect(2) && point(2) < rect(2) + rect(4)
                    points(end+1,:) = point;
                end
            end
            obj.addToStimulusWithRepeats(points);
        end
        
        function addNearestPoints(obj, n)
            if size(obj.pointData, 1) < n
                return
            end
            p = obj.selectedPoint(1,:);
            points = obj.pointData(:,1:2);
            distances = sqrt(sum(bsxfun(@minus, points, p) .^2, 2));
            [~, si] = sort(distances);
            points = points(si, :);
            points = points(1:min([size(points,1), n]), :);
            obj.addToStimulusWithRepeats(points);
        end
        
        function addNoisiestPoints(obj, n)
            if size(obj.pointData, 1) < n
                return
            end
            points = obj.pointData(:,1:2);
            noise = obj.pointData(:,4);
            [~, si] = sort(noise);
            points = points(si, :);
            points = points(1:min([size(points,1), n]), :);
            obj.addToStimulusWithRepeats(points);
        end        
        
        % unified function for adding points to the next stim list
        function addToStimulusWithRepeats(obj, newPoints, newInfo)
            if ~isempty(newPoints)
                % move invalid points within bounds
                for i = 1:size(newPoints,1)
                    if newPoints(i,1) < obj.contrastRange1(1)
                        newPoints(i,1) = obj.contrastRange1(1);
                    end
                    if newPoints(i,1) > obj.contrastRange1(2)
                        newPoints(i,1) = obj.contrastRange1(2);
                    end
                    if newPoints(i,2) < obj.contrastRange2(1)
                        newPoints(i,2) = obj.contrastRange2(1);
                    end
                    if newPoints(i,2) > obj.contrastRange2(2)
                        newPoints(i,2) = obj.contrastRange2(2);
                    end
                end
                
                % setup repeats
                if obj.handles.repeatStimCheckbox.Value
                    count = 2;
                else
                    count = 1;
                end
                
                if nargin < 3
                    newInfo = {};
                    for i = 1:size(newPoints,1)
                        newInfo{i,1} = containers.Map({'stimulusMode'},{'default'},'UniformValues',false);
                    end
                end
                for i = 1:count
                    order = randperm(size(newPoints, 1));
                    obj.nextStimulus = vertcat(obj.nextStimulus, newPoints(order,:));
                    obj.nextStimulusInfo = vertcat(obj.nextStimulusInfo, newInfo(order,:));
                end
                obj.updateUi();
            end
        end
        
        function randomizeStimulus(obj)
            order = randperm(size(obj.nextStimulus, 1));
            obj.nextStimulus = obj.nextStimulus(order,:);
            obj.nextStimulusInfo = obj.nextStimulusInfo(order,:);
            obj.updateUi();
        end
        
        function clearNextStimulus(obj)
            obj.nextStimulus = [];
            obj.nextStimulusInfo = {};
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
                obj.runPausedSoMayNeedNullEpoch = true;
                uiwait(obj.figureHandle);
            end
        end
            
        function assignNextStimulus(obj)
            % add a null epoch if requested
            if obj.handles.leadWithNullStimulusCheckbox.Value && obj.runPausedSoMayNeedNullEpoch
                disp('adding lead epoch')
                obj.ignoreNextEpoch = true;
                obj.runPausedSoMayNeedNullEpoch = false;
                obj.nextStimulus = vertcat(obj.nextStimulus(1,:), obj.nextStimulus);
                obj.nextStimulusInfo = vertcat(obj.nextStimulusInfo(1,:), obj.nextStimulusInfo);
            end
            
            % assign the contrasts to the next stimuli in the list
            obj.nextContrast1 = obj.nextStimulus(1, 1);
            obj.nextContrast2 = obj.nextStimulus(1, 2);
            obj.nextStimulusInfoOutput = obj.nextStimulusInfo{1};
            
            obj.nextStimulusInfo(1) = [];
            obj.nextStimulus(1,:) = [];
        end
        
        function updateUi(obj)
            % update next stimulus table
            obj.handles.nextStimulusTable.Data = obj.nextStimulus;
            
            % update point data table
            obj.handles.dataTable.Data = obj.pointData;
            
            % update selected point epochs table
            if ~isempty(obj.selectedPoint)
                point = obj.selectedPoint(1,:);
                pointTable = [];
                for ei = 1:length(obj.epochData)
                    e = obj.epochData{ei};
                    if e.ignore
                        continue
                    end
                    if point(1) == e.parameters('contrast1') && point(2) == e.parameters('contrast2')
                        pointTable(end+1,:) = [ei, e.response];
                    end
                end
                obj.handles.singlePointTable.Data = pointTable;
            end
            
            
            % update iso data plot
            cla(obj.handles.isoAxes);
            hold(obj.handles.isoAxes, 'on');

            if ~isempty(obj.pointData)
                if ~isempty(obj.interpolant)
                    try
                        c1p = linspace(min(obj.pointData(:,1)), max(obj.pointData(:,1)), 40);
                        c2p = linspace(min(obj.pointData(:,2)), max(obj.pointData(:,2)), 40);
                        [C1p, C2p] = meshgrid(c1p, c2p);
                        int = obj.interpolant(C1p, C2p);
%                         f = fspecial('average');
%                         int = imfilter(int, f);
                        s = pcolor(obj.handles.isoAxes, C1p, C2p, int);
                        shading(obj.handles.isoAxes, 'interp');
                        set(s, 'PickableParts', 'none');
                        
                        contour(obj.handles.isoAxes, C1p, C2p, int, 'k', 'ShowText','on', 'PickableParts', 'none')
                    end
                end

                % observations
                for oi = 1:size(obj.pointData,1)
                    if ~isempty(obj.selectedPoint) && all([obj.pointData(oi,1), obj.pointData(oi,2)] == obj.selectedPoint(1,:))
                        siz = 90;
                        edg = 'w';
                    else
                        siz = 40;
                        edg = 'k';
                    end
                    scatter(obj.handles.isoAxes, obj.pointData(oi,1), obj.pointData(oi,2), siz, 'CData', obj.pointData(oi,3), ...
                        'LineWidth', 1, 'MarkerEdgeColor', edg, 'MarkerFaceColor', 'flat', 'ButtonDownFcn', {@obj.isoPlotPointClick, oi})
                end
            end
            
            % next stimulus points
            if ~isempty(obj.nextStimulus)
                scatter(obj.handles.isoAxes, obj.nextStimulus(:,1), obj.nextStimulus(:,2), 60, 'CData', [1,1,1], ...
                    'LineWidth', 2, 'MarkerEdgeColor', 'k', 'Marker', 'x')
            end
            
            % plot click points
            if ~isempty(obj.isoPlotClickHistory)
                scatter(obj.handles.isoAxes, obj.isoPlotClickHistory(:,1), obj.isoPlotClickHistory(:,2), '+', ...
                    'LineWidth', 2, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'flat')
            end
            
            
            % draw some nice on/off divider lines, and contrast boundary lines
            line(obj.handles.isoAxes, [0,0], obj.plotRange2, 'LineStyle', ':', 'Color', 'k', 'PickableParts', 'none');
            line(obj.handles.isoAxes, obj.plotRange1, [0,0], 'LineStyle', ':', 'Color', 'k', 'PickableParts', 'none');
            rectangle(obj.handles.isoAxes, 'Position', [-1, -1, diff(obj.contrastRange1), diff(obj.contrastRange2)], 'EdgeColor', 'k', 'LineWidth', 1, 'PickableParts', 'none');
            
            xlabel(obj.handles.isoAxes, obj.colorNames{1});
            ylabel(obj.handles.isoAxes, obj.colorNames{2});
            xlim(obj.handles.isoAxes, obj.plotRange1 + [-.1, .1]);
            ylim(obj.handles.isoAxes, obj.plotRange2 + [-.1, .1]);
            set(obj.handles.isoAxes,'LooseInset',get(obj.handles.isoAxes,'TightInset'))
            hold(obj.handles.isoAxes, 'off');
            
            % Update selected epoch in epoch signal display and table
            if ~isempty(obj.selectedPoint)
                cla(obj.handles.epochSelectionAxes);
                point = obj.selectedPoint(1,:);
                for ei = 1:length(obj.epochData)
                    e = obj.epochData{ei};
                    if all([e.parameters('contrast1'), e.parameters('contrast2')] == point)
                        hold(obj.handles.epochSelectionAxes, 'on')
                        plot(obj.handles.epochSelectionAxes, e.t, e.signal);
                        plot(obj.handles.epochSelectionAxes, e.spikeTimes, e.signal(e.spikeFrames), '.');
                        hold(obj.handles.epochSelectionAxes, 'off')
                    end
                end
                set(obj.handles.epochSelectionAxes,'LooseInset',get(obj.handles.isoAxes,'TightInset'))
            end
            

        end
        
        function dataTableSelect(obj, ~, data)
            if size(data.Indices, 1) == 0 % happens on a deselect from a ui redraw
                return
            end
            responsePointIndex = data.Indices(1);
            point = obj.pointData(responsePointIndex, 1:2);
            obj.selectedPoint = point;
            obj.updateUi();
        end
        
        function singlePointTableSelect(obj, tab, data)
            if size(data.Indices, 1) == 0 % happens on a deselect from a ui redraw
                return
            end
            tableRow = data.Indices(1);
            ei = tab.Data(tableRow, 1);
            obj.epochData{ei}.ignore = true;
            fprintf('ignoring epoch %g in this analysis\n', ei);
            obj.analyzeData();
            obj.updateUi();
        end
        
        function isoPlotPointClick(obj, ~, ~, index)
            obj.selectedPoint = obj.pointData(index, 1:2);
            obj.updateUi();
        end
        
        function clearFigure(obj)
            obj.resetPlots();
            clearFigure@FigureHandler(obj);
        end
        
        function resetPlots(obj)
            obj.epochData = {};
            obj.epochIndex = 0;
            obj.pointData = [];
            obj.interpolant = [];
            obj.nextStimulus = [];
            obj.nextStimulusInfo = {};
            obj.selectedPoint = [];
            obj.protocolShouldStop = false;
        end
        
        function crange = get.contrastRange1(obj)
            crange = [-1, (1 / obj.baseIntensity1) - 1];
        end
        function crange = get.contrastRange2(obj)
            crange = [-1, (1 / obj.baseIntensity2) - 1];
        end        
        
%         function show(obj)
%             show@symphonyui.core.FigureHandler(obj);
%             obj.waitIfNecessary()
%         end
        
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