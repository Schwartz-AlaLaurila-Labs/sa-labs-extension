classdef ShapeResponseFigure < symphonyui.core.FigureHandler

    properties
        deviceName
        epochIndex
        spikeThresholdVoltage
        spikeDetectorMode
        spikeDetector
        Ntrials
        baselineRate
        devices
        parameterStruct
        currentSessionId
        
        analysisData
        epochData
        shapePlotMode
        
        displayBox
    end
    
    methods
        
        function obj = ShapeResponseFigure(devices, parameterStruct, varargin)
            obj = obj@symphonyui.core.FigureHandler();
            
            ip = inputParser;
            ip.KeepUnmatched = true;
            ip.addParameter('startTime', 0, @(x)isnumeric(x));
            ip.addParameter('endTime', 0, @(x)isnumeric(x));
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
            leftBox = uix.VBoxFlex('Parent', fullBox, 'Spacing', 10);
            
            displayModeSelectionControl = uicontrol(leftBox, 'Style', 'popupmenu');
            displayModeSelectionControl.String = {'plotSpatial_mean','temporalResponses','responsesByPosition',...
                'subunit','spatialDiagnostics','wholeCell',...
                'positionDifferenceAnalysis','printParameters','adaptationRegion',...
                'spatialOffset','temporalComponents'};
            displayModeSelectionControl.Callback = @obj.cbModeSelection;
            
%             obj.displayBox = uix.Panel('Parent',fullBox);
            obj.displayBox = uipanel('Parent',fullBox);

            set(fullBox, 'Widths', [100, -1]);
            
        end
        
        function cbModeSelection(obj, hObject, ~)
            items = get(hObject,'String');
            index_selected = get(hObject,'Value');
            item_selected = items{index_selected};
            obj.shapePlotMode = item_selected;
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
            if isempty(obj.currentSessionId)
                obj.currentSessionId = obj.parameterStruct.sessionId;
            else
                if ~strcmp(obj.parameterStruct.sessionId, obj.currentSessionId)
                    obj.currentSessionId = obj.parameterStruct.sessionId;
                    obj.resetPlots();
                end
            end
                    
            obj.epochIndex = obj.epochIndex + 1;
            obj.epochData{obj.epochIndex, 1} = sd;
                        
            obj.analysisData = sa_labs.util.shape.processShapeData(obj.epochData);

            if strcmp(obj.shapePlotMode, 'plotSpatial_mean') && obj.epochIndex == 1
                obj.shapePlotMode = 'temporalResponses';
            end

            obj.generatePlot();
            
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
        
%         function od = getOutputData(obj)
%             od = obj.outputData;
%         end
        
        
        function resetPlots(obj)
            obj.analysisData = [];
            obj.epochData = {};
            obj.epochIndex = 0;
        end
        
    end
    
end