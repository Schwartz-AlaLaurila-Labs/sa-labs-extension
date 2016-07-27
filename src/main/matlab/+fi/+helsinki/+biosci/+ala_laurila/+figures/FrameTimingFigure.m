classdef FrameTimingFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        stageDevice
        frameMonitor
    end
    
    properties (Access = private)
        softwareAxesHandle
        softwareSweep
        hardwareAxesHandle
        hardwareSweep
    end
    
    methods
        
        function obj = FrameTimingFigure(stageDevice, frameMonitor)
            obj.stageDevice = stageDevice;
            obj.frameMonitor = frameMonitor;
            
            obj.createUi();
        end
        
        function createUi(obj)
            obj.softwareAxesHandle = subplot(2, 1, 1, ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.softwareAxesHandle, 'flip');
            ylabel(obj.softwareAxesHandle, 'sec');
            title(obj.softwareAxesHandle, 'Software-based Frame Timing');
            
            obj.hardwareAxesHandle = subplot(2, 1, 2, ...
                'Parent', obj.figureHandle, ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.hardwareAxesHandle, 'sec');
            ylabel(obj.hardwareAxesHandle, 'units');
            title(obj.hardwareAxesHandle, 'Hardware-based Frame Timing');
            
            set(obj.figureHandle, 'Name', [obj.stageDevice.name ' Frame Timing']);
        end
        
        function handleEpoch(obj, epoch)
            info = obj.stageDevice.getPlayInfo();
            if isa(info, 'MException')
                error(['Stage encountered an error during the presentation: ' info.message]);
            end
            if ~epoch.hasResponse(obj.frameMonitor)
                error(['Epoch does not contain a response for ' obj.frameMonitor.name]);
            end
            
            % software-based timing
            durations = info.flipDurations;
            if numel(durations) > 0
                x = 1:numel(durations);
                y = durations;
            else
                x = [];
                y = [];
            end
            if isempty(obj.softwareSweep)
                obj.softwareSweep = line(x, y, 'Parent', obj.softwareAxesHandle);
            else
                set(obj.softwareSweep, 'XData', x, 'YData', y);
            end
            
            % hardware-based timing
            response = epoch.getResponse(obj.frameMonitor);
            [quantities, units] = response.getData();
            if numel(quantities) > 0
                x = (1:numel(quantities)) / response.sampleRate.quantityInBaseUnits;
                y = quantities;
            else
                x = [];
                y = [];
            end
            if isempty(obj.hardwareSweep)
                obj.hardwareSweep = line(x, y, 'Parent', obj.hardwareAxesHandle);
            else
                set(obj.hardwareSweep, 'XData', x, 'YData', y);
            end
            ylabel(obj.hardwareAxesHandle, units, 'Interpreter', 'none');
            
            % analyze timing
            sampleRate = response.sampleRate.quantityInBaseUnits;
            indices = getFlipIndices(quantities);
            durations = diff(indices(:) ./ sampleRate);
            
            minDuration = min(durations);
            maxDuration = max(durations);
            refreshDuration = 1 / obj.stageDevice.getMonitorRefreshRate();
            
            if abs(refreshDuration - minDuration) / refreshDuration > 0.10 || abs(refreshDuration - maxDuration) / refreshDuration > 0.10;
                epoch.addKeyword('badFrameTiming');
                set(obj.hardwareSweep, 'Color', 'r');
            else
                set(obj.hardwareSweep, 'Color', 'b');
            end
        end
        
    end
    
end

% TODO: This function is equivalent to getFrameTiming and should be replaced when that becomes commonized.
function i = getFlipIndices(sweep)
    sweep = sweep - min(sweep);
    sweep = sweep ./ max(sweep);
    
    ups = getThresholdCross(sweep, 0.5, 1);
    downs = getThresholdCross(sweep, 0.5, -1);
    
    ups = [1 ups];
    i = round(sort([ups'; downs']));
end

function i = getThresholdCross(sweep, threshold, direction)
    original = sweep(1:end-1);
    shifted = sweep(2:end);
    if direction > 0
        i = find(original < threshold & shifted >= threshold) + 1;
    else
        i = find(original >= threshold & shifted < threshold) + 1;
    end
end
