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
            sp = obj.serialPortObject;
            flush(sp);
            writeline(sp, 'pos?');
            pause(0.2);

            % The wheel answers with the position and then a '>' prompt. Read
            % whatever has arrived and take the last token before the prompt,
            % exactly as the fscanf loop did with the old serial interface.
            data = '';
            n = sp.NumBytesAvailable;
            if n > 0
                raw = char(read(sp, n, 'uint8'));
                tokens = regexp(raw, '\S+', 'match');
                for i = 1:numel(tokens)
                    if strcmp(tokens{i}, '>')
                        break;
                    end
                    data = tokens{i};
                end
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

        function delete(obj)
            if ~isempty(obj.serialPortObject)
                try
                    delete(obj.serialPortObject);
                catch
                end
            end
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
