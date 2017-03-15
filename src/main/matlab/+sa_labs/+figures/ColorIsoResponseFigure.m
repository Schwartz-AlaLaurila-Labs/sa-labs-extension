classdef ColorIsoResponseFigure < symphonyui.core.FigureHandler

    properties
        deviceName
        epochIndex
        spikeThresholdVoltage
        spikeDetectorMode
        spikeDetector
        devices
        
        nextRampPointsTime
        nextRampPointsIntensity
        isoResponseMode
        idealOutputCurve
        epochData
        allSettings % cell array of structs: rampPointsTime, rampPointsIntensity, epochIndices
        parameterStruct
        t
        
        figureBox
        displayBoxes
        responsePlots
        inputPlots
        timePointsBox
        intensityPointsBox
    end
    
    methods
        
        function obj = ColorIsoResponseFigure(devices, parameterStruct, varargin)
            obj = obj@symphonyui.core.FigureHandler();
            
            ip = inputParser;
            ip.KeepUnmatched = true;
            ip.addParameter('spikeThresholdVoltage', 4, @(x)isnumeric(x));
            ip.addParameter('spikeDetectorMode', 'Stdev', @(x)ischar(x));
            ip.addParameter('isoResponseMode', 'continuousRelease', @(x)ischar(x));
            
            ip.parse(varargin{:});
            
            obj.devices = devices;
            obj.parameterStruct = parameterStruct;
            obj.epochIndex = 0;
            obj.spikeThresholdVoltage = ip.Results.spikeThresholdVoltage;
            obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            obj.isoResponseMode = ip.Results.isoResponseMode;
            
            obj.spikeDetector = sa_labs.util.SpikeDetector('Simple threshold');
            obj.spikeDetector.spikeThreshold = obj.spikeThresholdVoltage;
            obj.spikeDetector.sampleInterval = 1E-4;
                  
            %remove menubar
%             set(obj.figureHandle, 'MenuBar', 'none');
            %make room for labels
%             set(obj.axesHandle(), 'Position',[0.14 0.18 0.72 0.72])
%             title(obj.figureHandle, 'Waiting for results');
            
            obj.resetPlots();
            
            obj.createUi();
            
            obj.allSettings = {};
%             s = obj.storedSettings()
%             if ~isempty(s)
%                 obj.allSettings = s{1};
%                 obj.epochData = s{2};
%             end
        end
        
        
        function createUi(obj)
            
            import appbox.*;
            
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            obj.figureBox = uix.VBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
%             leftBox = uix.VBox('Parent', fullBox, 'Spacing', 10);
                        
%             uicontrol(leftBox, 'Style','text','String','Times:')
%             obj.timePointsBox = uicontrol(leftBox, 'Style','edit','String','','Callback',@obj.cbSetPoints);
%             
%             uicontrol(leftBox, 'Style','text','String','Intensities:')
%             obj.intensityPointsBox = uicontrol(leftBox, 'Style','edit','String','','Callback',@obj.cbSetPoints);
            
%             obj.displayBox = uix.Panel('Parent',fullBox);
            obj.displayBoxes = [];%uipanel('Parent',fullBox);
            obj.responsePlots = [];

%             fullBox.Widths = [160, -1];
%             leftBox.Heights = [20,20,20,20];
        end
        
%         function cbModeSelection(obj, hObject, ~)
%             items = get(hObject,'String');
%             index_selected = get(hObject,'Value');
%             item_selected = items{index_selected};
%             obj.shapePlotMode = item_selected;
%             obj.generatePlot();
%         end
%         
%         function cbSetPoints(obj, ~, ~)
%             obj.nextRampPointsIntensity = str2double(obj.intensityPointsBox.String);
%             obj.nextRampPointsTime = str2double(obj.timePointsBox.String);
%             
% %             obj.analyzeData();
% %             obj.generatePlot();
%         end
        
        function handleEpoch(obj, epoch)
                                             
            responseObject = epoch.getResponse(obj.devices{1}); %only one channel for now
            [signal, ~] = responseObject.getData();
%             sampleRate = responseObject.sampleRate.quantityInBaseUnits;
            
            % combine epoch params with protocol params we've gotten originally
            keys = epoch.parameters.keys();
            values = epoch.parameters.values();
            for ki = 1:length(keys)
                name = keys{ki};
                val = values{ki};
                obj.parameterStruct.(name)= val;
            end
            
            e = struct();
            e.rawSignal = signal;
            e.signal = e.rawSignal;
            e.t = (1:numel(e.signal)) / responseObject.sampleRate.quantityInBaseUnits;
            e.parameters = epoch.parameters;
            obj.t = e.t;
            
            % reset here if we've got a new session
%             newSession = false;
%             if isempty(obj.currentSessionId)
%                 obj.currentSessionId = obj.parameterStruct.sessionId;
%                 newSession = true;
%             else
%                 if ~strcmp(obj.parameterStruct.sessionId, obj.currentSessionId)
%                     obj.currentSessionId = obj.parameterStruct.sessionId;
%                     obj.resetPlots();
%                     newSession = true;
%                 end
%             end
            
            % add the epoch to the array
            obj.epochIndex = obj.epochIndex + 1;
            obj.epochData{obj.epochIndex, 1} = e;
            
            % add these ramp settings to the list
            settingAlreadyPresent = false;
            for si = 1:size(obj.allSettings,1)
                s = obj.allSettings{si,1};
                times = s.rampPointsTime;
                ints = s.rampPointsIntensity;
                if isequal(times, e.parameters('rampPointsTime')) && isequal(ints, e.parameters('rampPointsIntensity'))
                    obj.allSettings{si,1}.epochIndices = [obj.allSettings{si,1}.epochIndices, obj.epochIndex];
                    settingAlreadyPresent = true;
                    disp('found this setting already present')
                end
            end
            if ~settingAlreadyPresent
                s = struct();
                s.rampPointsTime = e.parameters('rampPointsTime');
                s.rampPointsIntensity = e.parameters('rampPointsIntensity');
                s.epochIndices = [obj.epochIndex];
%                 if ~isempty(obj.allSettings)                 
                obj.allSettings{end+1, 1} = s;
                disp('adding new setting')
            end
            
            allsettings = obj.allSettings

            
            % store data for the future
            obj.storedSettings({obj.allSettings, obj.epochData});
            
            obj.analyzeData();
            obj.updateDialogs();
            obj.generatePlot();
        end
        
        function analyzeData(obj)
            thisEpoch = obj.epochData{end};
            if strcmp(obj.isoResponseMode, 'continuousRelease')
                signal = thisEpoch.signal;
                obj.idealOutputCurve = ones(size(thisEpoch.t)) * mean(signal);
                
                obj.nextRampPointsTime = thisEpoch.parameters('rampPointsTime');
                obj.nextRampPointsIntensity = thisEpoch.parameters('rampPointsIntensity');
%                 obj.nextRampPointsIntensity(end) = obj.nextRampPointsIntensity(end) - 0.1;
            end
        end
        
        function generatePlot(obj)
%             for si = 1:length(obj.displayBoxes)
%                 a = obj.displayBoxes(si)
%                 delete(obj.displayBoxes(si).Children);
%             end
%             delete(obj.displayBoxes);
            
            % add new rows if needed
            while size(obj.allSettings, 1) > length(obj.displayBoxes)
                n = length(obj.displayBoxes) + 1
                obj.displayBoxes(n) = uix.HBoxFlex('Parent',obj.figureBox);
                
                ax = axes('Parent', obj.displayBoxes(n));
                obj.inputPlots(n) = ax;   
                
                ax = axes('Parent', obj.displayBoxes(n));
                obj.responsePlots(n) = ax;
             
                disp('adding new display box')
            end
            
            
            if strcmp(obj.isoResponseMode, 'continuousRelease')
                for si = 1:size(obj.allSettings, 1)
                    fprintf('displaying setting %g', si);

%                     plot(ax, obj.t, obj.idealOutputCurve, 'LineWidth', 2)
                    s = obj.allSettings{si};
                    ax = obj.inputPlots(si);
                    cla(ax);
                    plot(ax, s.rampPointsTime, s.rampPointsIntensity, 'o-');

                    signals = [];
                    ax = obj.responsePlots(si);
                    cla(ax);
                    hold(ax, 'on')
                    title(length(s.epochIndices));
                    for ei = s.epochIndices
                        epoch = obj.epochData{ei}
                        plot(ax, epoch.t, epoch.signal)
                        signals(end+1,:) = epoch.signal; %#ok<*AGROW>
                        tt = epoch.t;
                    end
                    plot(ax, tt, mean(signals, 1))
                    hold(ax, 'off')
                end
            end
        end
        
        function updateDialogs(obj)
%             disp('updating dialogs')
            obj.intensityPointsBox.String = num2str(obj.nextRampPointsIntensity);
            obj.timePointsBox.String = num2str(obj.nextRampPointsTime);
        end
        
        function clearFigure(obj)
            obj.resetPlots();
            clearFigure@FigureHandler(obj);
        end
        
        function resetPlots(obj)
%             delete(obj.displayBox.Children);
            obj.epochData = {};
            obj.epochIndex = 0;
        end
    end
    
    
    methods (Static)
        function settings = storedSettings(stuffToStore)
            % This method stores means across figure handlers.

            persistent stored;
            if nargin > 0
                stored = stuffToStore
            end
            settings = stored
        end
        
    end
    
end