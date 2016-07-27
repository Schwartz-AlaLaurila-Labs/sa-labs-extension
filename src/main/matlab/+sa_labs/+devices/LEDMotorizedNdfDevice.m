classdef LEDMotorizedNdfDevice < symphonyui.builtin.devices.UnitConvertingDevice
    
    properties (Access = private)
        serialPort
        ndfs
        ndfName
    end
    
    properties (Dependent, Access = private)
        position
    end
    
    methods
        
        function obj = LEDMotorizedNdfDevice(name, measurementConversionTarget, comPort)
            obj@symphonyui.builtin.devices.UnitConvertingDevice(name, measurementConversionTarget);
            obj.serialPort = serial(comPort, 'BaudRate', 115200, 'DataBits', 8, 'StopBits', 1, 'Terminator', 'CR');
        end
        
        function addNdfConfiguration(obj, name, propertyType)
            obj.ndfName = name;
            obj.ndfs = propertyType.domain;
            value = obj.ndfs{obj.position};
            obj.addConfigurationSetting(name, value, 'type', propertyType);
        end
        
        function setConfigurationSetting(obj, name, value)
            if strcmp(name, obj.ndfName)
                obj.position = find(strcmp(obj.ndfs, value));
                value = obj.ndfs{obj.position};
            end
            setConfigurationSetting@symphonyui.builtin.devices.UnitConvertingDevice(obj, name, value);
        end
        
        function position = get.position(obj)
            fopen(obj.serialPort);
            fprintf(obj.serialPort, 'pos?\n');
            pause(0.2);
            
            while (get(obj.serialPort, 'BytesAvailable') ~=0)
                txt = fscanf(obj.serialPort, '%s');
                if txt == '>'
                    break;
                end
                data = txt;
            end
            position = str2double(data);
            fclose(obj.serialPort);
        end
        
        function set.position(obj, position)
            if position ~= obj.position
                fopen(obj.serialPort);
                fprintf(obj.serialPort, ['pos=' num2str(position) '\n']);
                pause(3);
                fclose(obj.serialPort);
            end
        end
        
        function delete(obj)
            delete(obj.serialPort);
        end
    end
    
end