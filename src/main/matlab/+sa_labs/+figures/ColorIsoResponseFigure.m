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
        
        contrastRange1
        contrastRange2
        
        epochData
        responseData
        interpolant = [];
        
        handles
    end

    
    methods
        
        function obj = ColorIsoResponseFigure(devices, varargin)
            obj = obj@symphonyui.core.FigureHandler();
            
            ip = inputParser;
            ip.KeepUnmatched = true;
            ip.addParameter('spikeThreshold', 20, @(x)isnumeric(x));
            ip.addParameter('spikeDetectorMode', 'Stdev', @(x)ischar(x));
            ip.addParameter('analysisRegion', [0,inf]);
            ip.addParameter('contrastRange1', [0,1]);
            ip.addParameter('contrastRange2', [0,1]);
%             ip.addParameter('isoResponseMode', 'continuousRelease', @(x)ischar(x));
            
            ip.parse(varargin{:});
            
            obj.devices = devices;
            obj.epochIndex = 0;
            obj.spikeThreshold = ip.Results.spikeThreshold;
            obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            obj.spikeDetector = sa_labs.util.SpikeDetector(obj.spikeDetectorMode, obj.spikeThreshold);
            obj.analysisRegion = ip.Results.analysisRegion;
            obj.contrastRange1 = ip.Results.contrastRange1;
            obj.contrastRange2 = ip.Results.contrastRange2;
            
            b = obj.contrastRange1
            
            %remove menubar
%             set(obj.figureHandle, 'MenuBar', 'none');
            %make room for labels
%             set(obj.axesHandle(), 'Position',[0.14 0.18 0.72 0.72])
%             title(obj.figureHandle, 'Waiting for results');
            
            obj.resetPlots();
            
            obj.createUi();
            
            obj.generateNextStimulus();
            
        end
        
        
        function createUi(obj)
            
            import appbox.*;
            
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            obj.handles.figureBox = uix.HBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
            
            obj.handles.epochDataBox = uix.VBox('Parent', obj.handles.figureBox, 'Spacing', 10);
            obj.handles.epochTable = uitable('Parent', obj.handles.epochDataBox, ...
                                    'ColumnName', {'contrast 1', 'contrast 2', 'response'}, ...
                                    'CellSelectionCallback', @obj.epochTableSelect);
            obj.handles.epochResponseAxes = axes('Parent', obj.handles.epochDataBox);
            
            obj.handles.isoDataBox = uix.VBox('Parent', obj.handles.figureBox, 'Spacing', 10);
            obj.handles.isoAxes = axes('Parent', obj.handles.isoDataBox);
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
            obj.generateNextStimulus();
            obj.updateGui();
        end
        
        function analyzeData(obj)
%             thisEpoch = obj.epochData{end};
            
            % calculate map of current results
            if obj.epochIndex > 2
                c1 = obj.responseData(:,1);
                c2 = obj.responseData(:,2);
                r = obj.responseData(:,3);
                obj.interpolant = scatteredInterpolant(c1, c2, r, 'linear', 'none');
            end            
            
            % Do iso-response magic
            
            
        end
        
        function generateNextStimulus(obj)
            
            % Select next contrasts
            bootstrapContrasts = [[obj.contrastRange1(2),0];
                                  [0,                    obj.contrastRange2(2)];
                                  [obj.contrastRange1(2),obj.contrastRange2(2)];
                                  [obj.contrastRange1(1),obj.contrastRange2(1)];

                                  [0,                    obj.contrastRange2(1)];
                                  [obj.contrastRange1(1),0];

                                  [obj.contrastRange1(2),obj.contrastRange2(1)];
                                  [obj.contrastRange1(1),obj.contrastRange2(2)]];

            nextEpochIndex = obj.epochIndex + 1;
            if nextEpochIndex <= size(bootstrapContrasts,1)
                obj.nextContrast1 = bootstrapContrasts(nextEpochIndex, 1);
                obj.nextContrast2 = bootstrapContrasts(nextEpochIndex, 2);
            else
                obj.nextContrast1 = 2 * rand();%thisEpoch.parameters('contrast1');
                obj.nextContrast2 = 2 * rand();%thisEpoch.parameters('contrast2');
            end
        end
        
        
        function updateGui(obj)
            % update epoch table
            obj.handles.epochTable.Data = obj.responseData;
            
            % update iso data plot

            hold(obj.handles.isoAxes, 'on');

            if ~isempty(obj.interpolant)
                c1p = linspace(min(obj.responseData(:,1)), max(obj.responseData(:,1)), 20);
                c2p = linspace(min(obj.responseData(:,2)), max(obj.responseData(:,2)), 20);
                [C1p, C2p] = meshgrid(c1p, c2p);
                int = obj.interpolant(C1p, C2p);
                pcolor(obj.handles.isoAxes, C1p, C2p, int);
                shading(obj.handles.isoAxes,'flat')
            end
            
            scatter(obj.handles.isoAxes, obj.responseData(:,1), obj.responseData(:,2), 40, 'CData', obj.responseData(:,3), ...
                'LineWidth', 1, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'flat')
            hold(obj.handles.isoAxes, 'off');
%             colorbar(obj.handles.isoAxes);
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
            obj.interpolant = [];
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