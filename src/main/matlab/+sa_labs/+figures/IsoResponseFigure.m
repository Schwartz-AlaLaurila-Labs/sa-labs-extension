classdef IsoResponseFigure < symphonyui.core.FigureHandler

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
        parameterStruct
        t
        
        displayBox
        timePointsBox
        intensityPointsBox
    end
    
    methods
        
        function obj = IsoResponseFigure(devices, parameterStruct, varargin)
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
        end
        
        
        function createUi(obj)
            
            import appbox.*;
            
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            fullBox = uix.HBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
            leftBox = uix.VBox('Parent', fullBox, 'Spacing', 10);
                        
            uicontrol(leftBox, 'Style','text','String','Times:')
            obj.timePointsBox = uicontrol(leftBox, 'Style','edit','String','','Callback',@obj.cbSetPoints);
            
            uicontrol(leftBox, 'Style','text','String','Intensities:')
            obj.intensityPointsBox = uicontrol(leftBox, 'Style','edit','String','','Callback',@obj.cbSetPoints);
            
%             obj.displayBox = uix.Panel('Parent',fullBox);
            obj.displayBox = uipanel('Parent',fullBox);

            fullBox.Widths = [160, -1];
            leftBox.Heights = [20,20,20,20];
        end
        
%         function cbModeSelection(obj, hObject, ~)
%             items = get(hObject,'String');
%             index_selected = get(hObject,'Value');
%             item_selected = items{index_selected};
%             obj.shapePlotMode = item_selected;
%             obj.generatePlot();
%         end
%         
        function cbSetPoints(obj, ~, ~)
            obj.nextRampPointsIntensity = str2double(obj.intensityPointsBox.String);
            obj.nextRampPointsTime = str2double(obj.timePointsBox.String);
            
%             obj.analyzeData();
%             obj.generatePlot();
        end
        
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
            end
        end
        
        function generatePlot(obj)
            delete(obj.displayBox.Children);
            drawnow
            if strcmp(obj.isoResponseMode, 'continuousRelease')
                
                ax = axes(obj.displayBox);
                hold(ax, 'on')
                plot(ax, obj.t, obj.idealOutputCurve, 'LineWidth', 2)
                for ei = 1:length(obj.epochData)
                    epoch = obj.epochData{ei};
                    plot(ax, epoch.t, epoch.signal)
                end
                hold(ax, 'off')
            end
        end
        
        function updateDialogs(obj)
            disp('updating dialogs')
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
    
end