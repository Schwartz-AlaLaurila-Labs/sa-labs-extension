classdef MockBlankingCircuit < symphonyui.core.Device
    
    methods
        
        function obj = MockBlankingCircuit()
            
            cobj = Symphony.Core.UnitConvertingExternalDevice('mockBlankingCircuit', 'Schwartz Lab', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
            
        end
        
        function status = isBlanking(obj, LEDs)
            status = false(size(LEDs));
        end

        function blank(obj, LED, level)
            return
        end

        function status = getLevel(obj, LEDs)
            status = 256 * ones(size(LEDs));
        end

        function setLevel(obj, LEDs, level)
            return
        end

        function reset(obj)
            return
        end
    end

    
end