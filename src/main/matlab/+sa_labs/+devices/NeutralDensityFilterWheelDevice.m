classdef NeutralDensityFilterWheelDevice < symphonyui.core.Device
    
    properties (Access = private)
        serialPortObject
    end
    
    
    methods
        
        function obj = NeutralDensityFilterWheelDevice(comPort)
            
            cobj = Symphony.Core.UnitConvertingExternalDevice('neutralDensityFilterWheel', 'Scientifica', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
            
            if comPort > 0
                obj.serialPortObject = serial(comPort, 'BaudRate', 115200, 'DataBits', 8, 'StopBits', 1, 'Terminator', 'CR');
            else
                obj.serialPortObject = [];
            end

            obj.addConfigurationSetting('comPort', comPort, 'isReadOnly', true);
            obj.addConfigurationSetting('filterWheelNdfValues', [1,2]);
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
            fclose(obj.serialPortObject);
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
                newPosition = find(valuesByPosition == newValue, 1);
                fopen(obj.serialPortObject);
                fprintf(obj.serialPortObject, 'pos=%s\n', num2str(newPosition));
                pause(3);
                fclose(obj.serialPortObject);
            end
        end
        
        function delete(obj)
            delete(obj.serialPortObject);
        end
    end
    
end