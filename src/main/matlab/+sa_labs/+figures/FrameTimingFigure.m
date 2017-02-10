classdef FrameTimingFigure < symphonyui.core.FigureHandler

    properties (SetAccess = private)
        device
    end

    properties (Access = private)
        axesHandle
        sweep
        targetLine
    end

    methods

        function obj = FrameTimingFigure(device)
            obj.device = device;

            obj.createUi();
        end

        function createUi(obj)
            obj.axesHandle = axes( ...
                'Parent', obj.figureHandle, ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle, 'flip');
            ylabel(obj.axesHandle, 'sec');

            obj.setTitle([obj.device.name ' Frame Timing']);
        end

        function setTitle(obj, t)
            set(obj.figureHandle, 'Name', t);
            title(obj.axesHandle, t);
        end

        function handleEpoch(obj, epoch) %#ok<INUSD>
            info = obj.device.getPlayInfo();
            frameRate = obj.device.getFrameRate();

            durations = info.flipDurations;
            if numel(durations) > 0
                x = 1:numel(durations);
                y = durations;
                ytarget = (1/frameRate) * ones(size(x));
            else
                x = [];
                y = [];
            end
            if isempty(obj.sweep)
                obj.sweep = line(x, y, 'Parent', obj.axesHandle, 'Color', 'r');
                obj.targetLine = line(x, ytarget, 'Parent', obj.axesHandle, 'Color', 'k');
            else
                set(obj.sweep, 'XData', x, 'YData', y);
                set(obj.targetLine, 'XData', x, 'YData', ytarget);
            end
            ylim(obj.axesHandle, [0, max([2/frameRate, 1.25*max(y)])]);
                
        end

    end

end
