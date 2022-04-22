classdef BlankingCircuit < symphonyui.core.Device
    
    properties (Access = private)
        serialPortObject
    end

    methods
        
        function obj = BlankingCircuit(comPort)
            
            cobj = Symphony.Core.UnitConvertingExternalDevice('blankingCircuit', 'Schwartz Lab', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
            
            if comPort > 0
                % obj.serialPortObject = serialport(comPort, 9600);
                obj.serialPortObject = serial(comPort, 'baudrate', 9600);
                fopen(obj.serialPortObject);
            else
                obj.serialPortObject = [];
            end

            obj.addConfigurationSetting('comPort', comPort, 'isReadOnly', true);
        end
        
        function status = isBlanking(obj, LEDs)
            status = false(numel(LEDs),1);
            for i = 1:numel(LEDs)
                if LEDs(i) < 0
                    status(i) = -1;
                else
                    status(i) = obj.write(LEDs(i),'uint8', 'uint8');
                end
            end
        end

        function blank(obj, LEDs, levels)
            for i = 1:numel(LEDs) 
                if LEDs(i) < 0
                    continue;
                else
                    obj.write([LEDs(i) + 3, levels(i)],'uint8'); %something like this...
                end
            end
        end

        % function unblank(obj, LED)
        %     obj.serialPortObject.flush();
        %     obj.serialPortObject.write([LEDs(i) + 3, 0],'uint8'); %something like this...
        % end

        function status = getLevel(obj, LEDs)
            status = zeros(numel(LEDs),1);
            for i = 1:numel(LEDs)
                if LEDs(i) < 0
                    status(i) = -1;
                else
                    status(i) = obj.write(LEDs(i)+6,'uint8', 'uint16');
                end     
            end
        end
            
        function setLevel(obj, LEDs, levels)
            for i = 1:numel(LEDs)
                if LEDs(i) < 0
                    continue
                else
                    obj.write([LEDs(i) + 9, levels(i)],'uint8'); %something like this...
                end
            end
        end
        function reset(obj)
            obj.write(0,'uint8');
        end

        function status = write(obj, data, wtype, rtype)
            fwrite(obj.serialPortObject, data, wtype);
            if nargin > 3 && nargout == 1
                while ~obj.serialPortObject.BytesAvailable
                end
                status = fread(obj.serialPortObject, 1, rtype);
            end
        end


        function delete(obj)
            fclose(obj.serialPortObject);            
            delete(obj.serialPortObject);
        end
    end

    
end