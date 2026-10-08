classdef StimulusResponseFigure < symphonyui.core.FigureHandler
    % Shows the stimulus delivered through an amplifier channel directly above
    % the response recorded on that channel, on a shared time axis. One row per
    % device that carries both a stimulus and a response in the epoch. Used by
    % the protocols that drive the amplifier (Pulse, MultiPulse, MultiPulseTrain,
    % PulseTrain, Ramp, StepPulseScale, ...), see BaseProtocol.prepareRun.

    properties (SetAccess = private)
        devices
        sweepColor
        stimulusColor
    end

    properties (Access = private)
        rows        % struct array: device, stimAxes, respAxes, stimLine, respLine
        panel
    end

    methods

        function obj = StimulusResponseFigure(devices, varargin)
            obj = obj@symphonyui.core.FigureHandler();

            co = get(groot, 'defaultAxesColorOrder');
            ip = inputParser();
            ip.addParameter('sweepColor', co(1,:), @(x)ischar(x) || isvector(x));
            ip.addParameter('stimulusColor', [0.85 0.33 0.1], @(x)ischar(x) || isvector(x));
            ip.parse(varargin{:});

            if ~iscell(devices)
                devices = {devices};
            end
            obj.devices = devices;
            obj.sweepColor = ip.Results.sweepColor;
            obj.stimulusColor = ip.Results.stimulusColor;
            obj.rows = struct('device', {}, 'stimAxes', {}, 'respAxes', {}, 'stimLine', {}, 'respLine', {});
            obj.createUi();
        end

        function createUi(obj)
            obj.figureHandle.Name = 'Stimulus / Response';
            obj.figureHandle.Color = 'w';
            obj.panel = uipanel(obj.figureHandle, 'Units', 'normalized', 'Position', [0 0 1 1], ...
                'BorderType', 'none', 'BackgroundColor', 'w');
        end

        function h = getFigureHandle(obj)
            h = obj.figureHandle;
        end

        function clear(obj)
            for i = 1:numel(obj.rows)
                try cla(obj.rows(i).stimAxes); catch, end
                try cla(obj.rows(i).respAxes); catch, end
                obj.rows(i).stimLine = [];
                obj.rows(i).respLine = [];
            end
        end

        function handleEpoch(obj, epoch)
            active = {};
            for i = 1:numel(obj.devices)
                d = obj.devices{i};
                if epoch.hasStimulus(d) && epoch.hasResponse(d)
                    active{end+1} = d; %#ok<AGROW>
                end
            end
            if isempty(active)
                return;
            end
            obj.ensureRows(active);

            for i = 1:numel(active)
                d = active{i};
                r = obj.findRow(d);

                stim = epoch.getStimulus(d);
                [sq, su] = stim.getData();
                srate = stim.sampleRate.quantityInBaseUnits;
                sx = (1:numel(sq)) / srate;

                resp = epoch.getResponse(d);
                [rq, ru] = resp.getData();
                rrate = resp.sampleRate.quantityInBaseUnits;
                rx = (1:numel(rq)) / rrate;

                if isempty(obj.rows(r).stimLine) || ~isvalid(obj.rows(r).stimLine)
                    obj.rows(r).stimLine = line(sx, sq, 'Parent', obj.rows(r).stimAxes, 'Color', obj.stimulusColor);
                else
                    set(obj.rows(r).stimLine, 'XData', sx, 'YData', sq);
                end
                if isempty(obj.rows(r).respLine) || ~isvalid(obj.rows(r).respLine)
                    obj.rows(r).respLine = line(rx, rq, 'Parent', obj.rows(r).respAxes, 'Color', obj.sweepColor);
                else
                    set(obj.rows(r).respLine, 'XData', rx, 'YData', rq);
                end
                ylabel(obj.rows(r).stimAxes, su, 'Interpreter', 'none');
                ylabel(obj.rows(r).respAxes, ru, 'Interpreter', 'none');
                title(obj.rows(r).stimAxes, [d.name ' stimulus'], 'FontWeight', 'normal');
                tmax = max([sx(end), rx(end)]);
                if tmax > 0
                    set([obj.rows(r).stimAxes, obj.rows(r).respAxes], 'XLim', [0 tmax]);
                end
            end
            drawnow limitrate;
        end

    end

    methods (Access = private)

        function r = findRow(obj, device)
            r = 0;
            for i = 1:numel(obj.rows)
                if obj.rows(i).device == device
                    r = i;
                    return;
                end
            end
        end

        function ensureRows(obj, devices)
            % (Re)build the axes grid when the set of devices with a stimulus changes.
            same = numel(devices) == numel(obj.rows);
            if same
                for i = 1:numel(devices)
                    if obj.findRow(devices{i}) == 0
                        same = false;
                        break;
                    end
                end
            end
            if same
                return;
            end
            delete(obj.panel.Children);
            obj.rows = struct('device', {}, 'stimAxes', {}, 'respAxes', {}, 'stimLine', {}, 'respLine', {});
            n = numel(devices);
            for i = 1:n
                sa = subplot(3 * n, 1, 3 * (i - 1) + 1, 'Parent', obj.panel);
                ra = subplot(3 * n, 1, 3 * (i - 1) + (2:3), 'Parent', obj.panel);
                set(sa, 'XTickLabel', [], 'Box', 'off');
                set(ra, 'Box', 'off');
                xlabel(ra, 'Time (s)');
                linkaxes([sa, ra], 'x');
                obj.rows(end+1) = struct('device', devices{i}, 'stimAxes', sa, 'respAxes', ra, ...
                    'stimLine', [], 'respLine', []); %#ok<AGROW>
            end
        end

    end

end
