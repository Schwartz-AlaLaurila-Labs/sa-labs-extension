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
        
        analysisData
        epochData
        shapePlotMode
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
            
        end
        
        
        function handleEpoch(obj, epoch)
                       
            obj.epochIndex = obj.epochIndex + 1;
                       
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
            
            sd
                
            obj.epochData{obj.epochIndex, 1} = sd;
%             obj.epochData{:}
                        
            obj.analysisData = sa_labs.util.shape.processShapeData(obj.epochData);

            clf;
            if strcmp(obj.shapePlotMode, 'plotSpatial_mean') && obj.epochIndex == 1
                spm = 'temporalResponses';
            else
                spm = obj.shapePlotMode;
            end
            sa_labs.util.shape.plotShapeData(obj.analysisData, spm);
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