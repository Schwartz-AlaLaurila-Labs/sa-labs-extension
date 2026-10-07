classdef BlankingCircuit < symphonyui.core.Device
    % LED blanking circuit on a serial port (9600 baud, LF-terminated lines).
    % Uses serialport (R2019b+); the old serial/instrfind interface was
    % removed in R2026b. Line protocol: '1' queries blanking state,
    % '2,<level>' blanks (1) or unblanks (0) all LEDs.

    properties (Access = private)
        serialPortObject
    end

    methods

        function obj = BlankingCircuit(comPort)

            cobj = Symphony.Core.UnitConvertingExternalDevice('blankingCircuit', 'Schwartz Lab', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;

            if sa_labs.devices.NeutralDensityFilterWheelDevice.isRealPort(comPort)
                % serialport opens the port on construction; a port left open by
                % a previous rig object is released when that object is deleted.
                obj.serialPortObject = serialport(char(string(comPort)), 9600, 'Timeout', 0.5);
                configureTerminator(obj.serialPortObject, 'LF');
            else
                obj.serialPortObject = [];
            end

            obj.addConfigurationSetting('comPort', comPort, 'isReadOnly', true);
        end

        function status = isBlanking(obj, LEDs)
            obj.writeline('1');
            status = ones(size(LEDs)) * str2double(obj.readline());
        end

        function blank(obj, LEDs, levels) %#ok<INUSL>
            if all(levels == 1) || all(levels == 0)
                obj.writeline(sprintf('2,%d', levels(1)));
            else
                error('All leds must be blanked at the same time in current implementation.')
            end
        end

        function writeline(obj, line)
            % Sends one LF-terminated line (the old fprintf(obj, '...\n') form).
            writeline(obj.serialPortObject, line);
        end

        function data = readline(obj)
            % Returns the next line, or '' if nothing arrives within 100 ms.
            tstart = tic;
            data = '';
            while toc(tstart) < 0.1 && obj.serialPortObject.NumBytesAvailable == 0
            end
            if obj.serialPortObject.NumBytesAvailable > 0
                data = char(readline(obj.serialPortObject));
            end
        end

        function close(obj)
            % Release the COM port (Rig.close calls this on quit / re-initialize).
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

end
