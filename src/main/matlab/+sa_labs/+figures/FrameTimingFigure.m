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
                'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'), ...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), ...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.softwareAxesHandle, 'flip');
            ylabel(obj.softwareAxesHandle, 'sec');
            title(obj.softwareAxesHandle, 'Software-based Frame Timing');
            
            obj.hardwareAxesHandle = subplot(2, 1, 2, ...
                'Parent', obj.figureHandle, ...
                'FontUnits', get(obj.figureHandle, 'DefaultUicontrolFontUnits'), ...
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
                rethrow(info);
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
            indices = getFlipIndices(quantities, ~isa(obj.stageDevice, 'edu.washington.riekelab.devices.LightCrafterDevice'));
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

% TODO: This function is equivalent to Max's getFrameTiming and should be replaced when that becomes commonized
function i = getFlipIndices(sweep, usePeaks)
    if usePeaks
        % Smooth out non-monotonicity
        sweep = lowPassFilter(sweep, 360, 1/1e4); 
    end
    
    % Normalize
    sweep = sweep - min(sweep);
    sweep = sweep ./ max(sweep);
    
    ups = getThresholdCross(sweep, 0.5, 1);
    downs = getThresholdCross(sweep, 0.5, -1);
    
    if ~usePeaks
        % Add first upswing because its missed by getThresholdCross
        ups = [1 ups];
        i = round(sort([ups'; downs']));
    else
        % Get peaks/troughs between first and last flips
        temp = sweep(ups(1):downs(end)); 
        even = getPeaks(temp, 1);
        odd = getPeaks(temp, -1);
        
        even = even + ups(1);
        odd = [1 odd + ups(1)];
        
        i = round(sort([odd'; even']));
    end
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

function i = getPeaks(sweep, direction)
    if direction > 0
        i = find(diff(diff(sweep) > 0) < 0) + 1;
    else
        i = find(diff(diff(sweep) > 0) > 0) + 1;
    end
end

function f = lowPassFilter(sweep, freq, interval)
    % Flip if given a column vector
    L = size(sweep, 2);
    if L == 1
        sweep = sweep'; 
        L = size(sweep, 2);
    end

    stepSize = 1 / (interval * L);
    cutoffPts = round(freq / stepSize);

    % Eliminate frequencies beyond cutoff (middle of matrix given fft representation)
    FFTData = fft(sweep, [], 2);
    FFTData(:, cutoffPts:size(FFTData,2)-cutoffPts) = 0;
    f = real(ifft(FFTData, [], 2));
end