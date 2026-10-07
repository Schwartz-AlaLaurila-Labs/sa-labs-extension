classdef NeutralDensityFilterWheelDevice < symphonyui.core.Device
    % Scientifica neutral density filter wheel on a serial port.
    % Uses serialport (R2019b+); the old serial interface was removed in
    % R2026b. Protocol: 'pos?' + CR returns the position followed by a '>'
    % prompt; 'pos=N' + CR moves to position N.

    properties (Access = private)
        serialPortObject
    end

    methods

        function obj = NeutralDensityFilterWheelDevice(comPort)

            cobj = Symphony.Core.UnitConvertingExternalDevice('neutralDensityFilterWheel', 'Scientifica', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;

            if sa_labs.devices.NeutralDensityFilterWheelDevice.isRealPort(comPort)
                obj.serialPortObject = serialport(char(string(comPort)), 115200, ...
                    'DataBits', 8, 'StopBits', 1, 'Timeout', 1);
                configureTerminator(obj.serialPortObject, 'CR');
            else
                obj.serialPortObject = [];
            end

            obj.addConfigurationSetting('comPort', comPort, 'isReadOnly', true);
            obj.addConfigurationSetting('filterWheelNdfValues', [1,2]);
        end

        function position = getPosition(obj)
            % The first query after the port is opened can come back empty;
            % retry once before reporting NaN.
            position = obj.queryPosition();
            if isnan(position)
                position = obj.queryPosition();
            end
        end

        function position = queryPosition(obj)
            sp = obj.serialPortObject;
            flush(sp);
            writeline(sp, 'pos?');

            % The wheel echoes the command, then answers with the position and
            % a '>' prompt, e.g. "pos?\r3\r> ". Accumulate bytes until the
            % prompt arrives (up to 1.5 s) and take the last token before it,
            % as the fscanf loop did with the old serial interface.
            raw = '';
            t0 = tic;
            while toc(t0) < 1.5
                n = sp.NumBytesAvailable;
                if n > 0
                    raw = [raw, char(read(sp, n, 'uint8'))]; %#ok<AGROW>
                    if contains(raw, '>')
                        break;
                    end
                end
                pause(0.02);
            end

            data = '';
            tokens = regexp(raw, '\S+', 'match');
            for i = 1:numel(tokens)
                if strcmp(tokens{i}, '>')
                    break;
                end
                data = tokens{i};
            end

            position = str2double(data);
        end

        function value = getValue(obj)
            valuesByPosition = obj.getConfigurationSetting('filterWheelNdfValues');
            position = obj.getPosition();
            if isnan(position)
                value = -1;
            else
                value = valuesByPosition(position);
            end
        end

        function setNdfValue(obj, newValue)
            valuesByPosition = obj.getConfigurationSetting('filterWheelNdfValues');
            if ~any(valuesByPosition == newValue)
                error(['Error: filter value ' num2str(newValue) ' not found']);
            end

            oldValue = obj.getValue();
            if newValue ~= oldValue
                [auto, red, green, blue] = lcrGetLedEnables();
                lcrSetLedEnables(0,0,0,0);

                newPosition = find(valuesByPosition == newValue, 1);
                oldPosition = find(valuesByPosition == oldValue, 1);

                %only move in order of increasing NDF due to hardware issue on rig B
                if oldPosition ~= newPosition
                    if oldPosition > newPosition
                        positions = [oldPosition + 1 : length(valuesByPosition), 1:newPosition];
                    else
                        positions = oldPosition + 1 : newPosition;
                    end
                    for pos = positions
                        writeline(obj.serialPortObject, sprintf('pos=%d', pos));
                    end
                end
            end

            landed = -1;
            while landed == -1
                landed = obj.getValue();
            end

            if newValue ~= landed
                error('Failed to change filter wheel to desired position. LEDs have been turned off to prevent bleaching.\n\nAttempted to move from position %d (NDF %d) to position %d (NDF %d), but landed at position %d (NDF %d).\n', oldPosition, oldValue, newPosition, newValue, landed, find(valuesByPosition == landed, 1));
            end

            if newValue ~= oldValue
                lcrSetLedEnables(auto,red,green,blue);
            end
        end

        function close(obj)
            % Release the COM port. Rig.close calls this when the app quits or
            % re-initializes the rig, so the next rig in the same MATLAB
            % session can open the wheel again.
            if ~isempty(obj.serialPortObject)
                try
                    delete(obj.serialPortObject);
                catch
                end
                obj.serialPortObject = [];
            end
        end

        function delete(obj)
            obj.close();
        end
    end

    methods (Static)

        function tf = isRealPort(comPort)
            % Rigs pass 'COM7' (char) or -1 (no wheel; the old code relied on
            % char > 0 being true element-wise).
            if ischar(comPort) || isstring(comPort)
                tf = strlength(string(comPort)) > 0;
            else
                tf = isnumeric(comPort) && ~isempty(comPort) && all(comPort > 0);
            end
        end

    end

end
