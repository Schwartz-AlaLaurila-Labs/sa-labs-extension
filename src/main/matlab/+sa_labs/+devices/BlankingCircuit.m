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
                obj.serialPortObject = serialport(comPort, 9600);
            else
                obj.serialPortObject = [];
            end

            obj.addConfigurationSetting('comPort', comPort, 'isReadOnly', true);
        end
        
        function status = isBlanking(obj, LEDs)
            obj.serialPortObject.flush();
            status = false(numel(LEDs),1)
            for i = 1:numel(LEDs)
                obj.seralPortObject.write(LEDs(i),'uint8');
                while ~obj.NumBytesAvailable
                end
                status(i) = obj.serialPortObject.read(1,'uint8');
            end
        end

        function blank(obj, LED, level)
            obj.serialPortObject.flush();
            obj.seralPortObject.write([LEDs(i) + 3, 1],'uint8'); %something like this...
        end

        % function unblank(obj, LED)
        %     obj.serialPortObject.flush();
        %     obj.seralPortObject.write([LEDs(i) + 3, 0],'uint8'); %something like this...
        % end

        function status = getLevel(obj, LEDs)
            obj.serialPortObject.flush();
            status = zeros(numel(LEDs),1)
            for i = 1:numel(LEDs)
                obj.seralPortObject.write(LEDs(i)+6,'uint8');
                while ~obj.NumBytesAvailable
                end
                status(i) = obj.serialPortObject.read(1,'uint16');
            end
        end

        function setLevel(obj, LEDs, level)
            obj.serialPortObject.flush();
            for i = 1:numel(LEDs)
                obj.seralPortObject.write([LEDs(i) + 9, 1],'uint8'); %something like this...
            end
        end
        function reset(obj)
            obj.serialPortObject.flush();
            obj.serialPortObject.write(0,'uint8');
        end

        function delete(obj)
            delete(obj.seralPortObject);
        end
    end

    
end