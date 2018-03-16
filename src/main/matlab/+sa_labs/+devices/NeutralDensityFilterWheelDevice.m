classdef NeutralDensityFilterWheelDevice < symphonyui.core.Device

    properties (Access = private)
        serialPortObject
        currentndf
    end

    properties (Constant)
        EMPTY_NDF = 'Empty'
    end

    methods

        function obj = NeutralDensityFilterWheelDevice(comPort)

            if nargin < 1
                comPort = 0;
            end

            cobj = Symphony.Core.UnitConvertingExternalDevice('neutralDensityFilterWheel', 'Thorlabs', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;

            if comPort > 0
                obj.serialPortObject = serial(comPort,...
                    'BaudRate', 115200,...
                    'DataBits', 8, ...
                    'StopBits', 1,...
                    'Terminator', 'CR');

                obj.addConfigurationSetting('type', 'motorized', 'isReadOnly', true);
                obj.addConfigurationSetting('comPort', comPort, 'isReadOnly', true);
                fopen(obj.serialPortObject);
            else
                obj.serialPortObject = [];
                obj.addConfigurationSetting('type', 'manual', 'isReadOnly', true);
            end
        end

        function position = getPosition(obj)
            fclose(obj.serialPortObject);
            fopen(obj.serialPortObject);
            fprintf(obj.serialPortObject, 'pos?\n');
            pause(0.2);

            data = '';
            while (get(obj.serialPortObject, 'BytesAvailable') ~=0)
                txt = fscanf(obj.serialPortObject, '%s');
                if txt == '>'
                    break;
                end
                data = txt;
            end

            position = str2double(data);
        end

        function value = getValue(obj)

            if obj.isManual()
                value = obj.currentndf;
                return
            end

            values= obj.getConfigurationSetting('filterWheelNdfValues');
            position = obj.getPosition();

            if isnan(position)
                value = -1;
            else
                value = values(position);
            end
        end

        function setNdfValue(obj, newValue)
            valuesByPosition = obj.getConfigurationSetting('filterWheelNdfValues');

            if ~ ismember(valuesByPosition, newValue)
                error(['Error: filter value ' num2str(newValue) ' not found']);
            end

            if obj.isManual()
                obj.currentndf = newValue;
                return
            end

            oldValue = obj.getValue();
            if newValue ~= oldValue
                newPosition = find(valuesByPosition == newValue, 1);
                fprintf(obj.serialPortObject, 'pos=%s\n', num2str(newPosition));
                pause(3);
            end
            obj.currentndf = newValue;
        end

        function tf = isEmpty(obj)
            tf = isempty(strfind(obj.getValue(), obj.EMPTY_NDF));
        end

        function tf = isManual(obj)
            tf = isempty(obj.serialPortObject);
        end

        function setEmpty(obj)
            obj.setNdfValue(obj.EMPTY_NDF);
        end

        function close(obj)
            if ~ obj.isManual()
                fclose(obj.serialPortObject);
            end
        end

        function delete(obj)
            delete(obj.serialPortObject);
        end
    end

end
