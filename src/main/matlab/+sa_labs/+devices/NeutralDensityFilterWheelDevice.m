classdef NeutralDensityFilterWheelDevice < symphonyui.core.Device
    
    properties (Access = private)
        serialPortObject
    end
    
    
    methods
        
        function obj = NeutralDensityFilterWheelDevice(comPort)
            
            cobj = Symphony.Core.UnitConvertingExternalDevice('neutralDensityFilterWheel', 'Scientifica', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
            
            obj.serialPortObject = serial(comPort, 'BaudRate', 115200, 'DataBits', 8, 'StopBits', 1, 'Terminator', 'CR');
           
            % some defaults that shouldn't be used
            filterWheelNdfValues = [1,2];

            obj.addConfigurationSetting('comPort', comPort, 'isReadOnly', true);
            obj.addConfigurationSetting('filterWheelNdfValues', filterWheelNdfValues);
        end
        
        function position = getPosition(obj)
            fopen(obj.serialPortObject);
            fprintf(obj.serialPortObject, 'pos?\n');
            pause(0.2);
            
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
            value = valuesByPosition(obj.getPosition());
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