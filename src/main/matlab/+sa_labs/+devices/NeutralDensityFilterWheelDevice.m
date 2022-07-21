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
                [auto, red, green, blue] = lcrGetLedEnables();
                lcrSetLedEnables(0,0,0,0);
                
                fopen(obj.serialPortObject);

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
                        fprintf(obj.serialPortObject, 'pos=%s\n', num2str(pos));
                    end
                end 
                fclose(obj.serialPortObject);
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
            delete(obj.serialPortObject);
        end
    end
    
end