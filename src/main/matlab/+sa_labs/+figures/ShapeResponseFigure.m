classdef ShapeResponseFigure < symphonyui.core.FigureHandler

    properties
        deviceName
        epochIndex
        spikeThresholdVoltage
        spikeDetectorMode
        spikeDetector
        devices
        parameterStruct
        currentSessionId
        
        analysisData
        epochData
        shapePlotMode
        
        displayBox
        temporalOffsetBox
    end
    
    methods
        
        function obj = ShapeResponseFigure(devices, parameterStruct, varargin)
            obj = obj@symphonyui.core.FigureHandler();
            
            ip = inputParser;
            ip.KeepUnmatched = true;
            ip.addParameter('spikeThresholdVoltage', 4, @(x)isnumeric(x));
            ip.addParameter('spikeDetectorMode', 'Stdev', @(x)ischar(x));
            ip.addParameter('shapePlotMode', 'plotSpatial_mean', @(x)ischar(x));
            
            ip.parse(varargin{:});
            
            obj.devices = devices;
            obj.parameterStruct = parameterStruct;
            obj.epochIndex = 0;
            obj.spikeThresholdVoltage = ip.Results.spikeThresholdVoltage;
            obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            obj.Ntrials = 0;
            obj.shapePlotMode = ip.Results.shapePlotMode;
            
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
            
            uicontrol(leftBox, 'Style','text','String','Plot mode:')
            displayModeSelectionControl = uicontrol(leftBox, 'Style', 'popupmenu');
            displayModeSelectionControl.String = {'plotSpatial_mean','plotSpatial_peak','temporalResponses','responsesByPosition',...
                'subunit','spatialDiagnostics','wholeCell',...
                'printParameters','adaptationRegion',...
                'spatialOffset','temporalComponents'};
            displayModeSelectionControl.Callback = @obj.cbModeSelection;
            
            uicontrol(leftBox, 'Style','text','String','Temporal offset (msec):')
            obj.temporalOffsetBox = uicontrol(leftBox, 'Style','edit','String','');
            obj.temporalOffsetBox.Callback = @obj.cbTimeOffset;            
            
%             obj.displayBox = uix.Panel('Parent',fullBox);
            obj.displayBox = uipanel('Parent',fullBox);

            fullBox.Widths = [160, -1];
            leftBox.Heights = [20,20,20,20];
        end
        
        function cbModeSelection(obj, hObject, ~)
            items = get(hObject,'String');
            index_selected = get(hObject,'Value');
            item_selected = items{index_selected};
            obj.shapePlotMode = item_selected;
            obj.generatePlot();
        end
        
        function cbTimeOffset(obj, ~, ~)
            obj.analyzeData(false);
            obj.generatePlot();
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
            obj.parameterStruct.timeOffset = nan;

            sd = sa_labs.util.shape.ShapeData(obj.parameterStruct, 'online2');
            
            if strcmp(obj.parameterStruct.chan1Mode, 'Cell attached')
%                 if DEMO_MODE
%                     sd.simulateSpikes();
%                 else

                    result = obj.spikeDetector.detectSpikes(signal);
                    sd.setSpikes(result.sp);
%                 end
            else % whole cell
%                 if DEMO_MODE
%                     sd.simulateSpikes();
%                 else
                    sd.setResponse(signal');
                    sd.processWholeCell();
%                 end
            end
            
            
            % reset here if we've got a new session
            newSession = false;
            if isempty(obj.currentSessionId)
                obj.currentSessionId = obj.parameterStruct.sessionId;
                newSession = true;
            else
                if ~strcmp(obj.parameterStruct.sessionId, obj.currentSessionId)
                    obj.currentSessionId = obj.parameterStruct.sessionId;
                    obj.resetPlots();
                    newSession = true;
                end
            end
            
            % add the epoch to the array
            obj.epochIndex = obj.epochIndex + 1;
            obj.epochData{obj.epochIndex, 1} = sd;
            
            obj.analyzeData(newSession);

            if strcmp(obj.shapePlotMode, 'plotSpatial_mean') && obj.epochIndex == 1
                obj.shapePlotMode = 'temporalResponses';
            end

            obj.generatePlot();
        end
        
        function analyzeData(obj, newSession)
            
            for ei = 1:length(obj.epochData)
                obj.epochData{ei}.timeOffset = nan;
            end
            if ~newSession
                obj.epochData{1}.timeOffset = 1e-3 * str2double(obj.temporalOffsetBox.String);
            end
            fprintf('set timeoffset to %d\n',obj.epochData{1}.timeOffset)
            
            obj.analysisData = sa_labs.util.shape.processShapeData(obj.epochData);
            
            obj.temporalOffsetBox.String = num2str(1000 * obj.analysisData.timeOffset);
            
        end
        
        function generatePlot(obj)
            delete(obj.displayBox.Children);
            drawnow
            sa_labs.util.shape.plotShapeData(obj.displayBox, obj.analysisData, obj.shapePlotMode);
%             set(ax,'LooseInset',get(ax,'TightInset')) % remove the blasted whitespace
        end
        
        function clearFigure(obj)
            obj.resetPlots();
            clearFigure@FigureHandler(obj);
        end
        
        function resetPlots(obj)
            obj.analysisData = [];
            obj.epochData = {};
            obj.epochIndex = 0;
        end
        
    end
    
end