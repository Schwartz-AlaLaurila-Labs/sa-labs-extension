classdef RigPropertyDevice < symphonyui.core.Device
    
    methods
        
        function obj = RigPropertyDevice(rigName, testMode)
            
            cobj = Symphony.Core.UnitConvertingExternalDevice('rigProperty', 'S-A Labs', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;

            obj.addConfigurationSetting('rigName', rigName, 'isReadOnly', true);
            obj.addConfigurationSetting('testMode',testMode, 'isReadOnly', true);
        end
        
    end
    
end