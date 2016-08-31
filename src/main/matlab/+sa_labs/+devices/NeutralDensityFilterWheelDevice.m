classdef NeutralDensityFilterWheelDevice < symphonyui.core.Device
    
    properties (Access = private)
        serialPortObject
    end
    
    properties (Dependent, Access = private)
        position
    end
    
    methods
        
        function obj = NeutralDensityFilterWheelDevice(comPort)
            
            cobj = Symphony.Core.UnitConvertingExternalDevice('neutralDensityFilterWheel', 'Scientifica', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
            
            obj.serialPortObject = serial(comPort, 'BaudRate', 115200, 'DataBits', 8, 'StopBits', 1, 'Terminator', 'CR');
           
            % some defaults that shouldn't be used
            filterWheelValidPositions = [1,2];

            obj.addConfigurationSetting('comPort', comPort, 'isReadOnly', true);
            obj.addConfigurationSetting('filterWheelValidPositions', filterWheelValidPositions);
        end
        
        function position = get.position(obj)
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
        
        function set.position(obj, newPosition)
            if ~any(obj.getConfigurationSetting('filterWheelValidPositions') == value)
                error(['Error: filter value ' num2str(value) ' not found']);
            end
            
            if newPosition ~= obj.position
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