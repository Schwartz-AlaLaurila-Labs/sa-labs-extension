classdef ResponseStatisticsFigure_mod < symphonyui.core.FigureHandler
    % Plots statistics calculated from the response of a specified device for each epoch run.
    
    properties (SetAccess = private)
        device
        measurementCallbacks
        measurementRegion
        baselineRegion
        epochSplitParameter
        epochData
    end
    
    properties (Access = private)
        axesHandles
        markers
    end
    
    methods
        
        function obj = ResponseStatisticsFigure_mod(device, measurementCallbacks, varargin)
            if ~iscell(measurementCallbacks)
                measurementCallbacks = {measurementCallbacks};
            end
            
            ip = inputParser();
            ip.addParameter('measurementRegion', [], @(x)isnumeric(x) || isvector(x));
            ip.addParameter('baselineRegion', [], @(x)isnumeric(x) || isvector(x));
            ip.addParameter('epochSplitParameter', '', @(x)ischar(x));
            ip.parse(varargin{:});
            
            obj.device = device;
            obj.measurementCallbacks = measurementCallbacks;
            obj.measurementRegion = ip.Results.measurementRegion;
            obj.baselineRegion = ip.Results.baselineRegion;
            obj.epochSplitParameter = ip.Results.epochSplitParameter;
            
            obj.createUi();
            
            obj.epochData = {};
        end
        
        function createUi(obj)
            import appbox.*;
            
            for i = 1:numel(obj.measurementCallbacks)
                obj.axesHandles(i) = subplot(numel(obj.measurementCallbacks), 1, i, ...
                    'Parent', obj.figureHandle, ...
                    'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                    'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                    'XTickMode', 'auto', ...
                    'XColor', 'none');
                ylabel(obj.axesHandles(i), func2str(obj.measurementCallbacks{i}));
            end
            set(obj.axesHandles(end), 'XColor', get(groot, 'defaultAxesXColor'));
            xlabel(obj.axesHandles(end), 'epoch');
            
            obj.setTitle([obj.device.name ' Response Statistics']);
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
            
            msToPts = @(t)max(round(t / 1e3 * e.sampleRate), 1);
            
            if ~isempty(obj.baselineRegion)
                x1 = msToPts(obj.baselineRegion(1));
                x2 = msToPts(obj.baselineRegion(2));
                baseline = e.signal(x1:x2);
                e.signal = e.signal - mean(baseline);
            end
            
            if ~isempty(obj.measurementRegion)
                x1 = msToPts(obj.measurementRegion(1));
                x2 = msToPts(obj.measurementRegion(2));
                e.signal = e.signal(x1:x2);
            end           
            
            e.measurements = [];
            for i = 1:numel(obj.measurementCallbacks)
                fcn = obj.measurementCallbacks{i};
                result = fcn(e.signal);
                e.measurements(i) = result;
            end
            
            obj.epochData{end+1} = e;
            
            % then loop through all the epochs we have and plot them
            for measi = 1:numel(obj.measurementCallbacks)
                for ei = 1:length(obj.epochData)
                    epoc = obj.epochData{ei};
                    
                    measurement = epoc.measurements(measi);
                    
                    if numel(obj.markers) < measi
                        colorOrder = get(groot, 'defaultAxesColorOrder');
                        color = colorOrder(mod(measi - 1, size(colorOrder, 1)) + 1, :);
                        obj.markers(measi) = line(1, measurement, 'Parent', obj.axesHandles(measi), ...
                            'LineStyle', 'none', ...
                            'Marker', 'o', ...
                            'MarkerEdgeColor', color, ...
                            'MarkerFaceColor', color);
                    else
                        x = get(obj.markers(measi), 'XData');
                        y = get(obj.markers(measi), 'YData');
                        set(obj.markers(measi), 'XData', [x x(end)+1], 'YData', [y measurement]);
                    end
                end
            end
            
            
            
        end
        
    end
        
end