classdef AaltoPatchRig < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = AaltoPatchRig()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = HekaDaqController(HekaDeviceType.ITC1600);
            obj.daqController = daq;
            
            amp1 = MultiClampDevice('Amp1', 1, 836019).bindStream(daq.getStream('ANALOG_OUT.0')).bindStream(daq.getStream('ANALOG_IN.0'));
            obj.addDevice(amp1);
            
            amp2 = MultiClampDevice('Amp2', 2, 836019).bindStream(daq.getStream('ANALOG_OUT.1')).bindStream(daq.getStream('ANALOG_IN.1'));
            obj.addDevice(amp2);
            
            amp3 = MultiClampDevice('Amp3', 2, 836392).bindStream(daq.getStream('ANALOG_OUT.2')).bindStream(daq.getStream('ANALOG_IN.2'));
            obj.addDevice(amp3);
            
            amp4 = MultiClampDevice('Amp4', 2, 836392).bindStream(daq.getStream('ANALOG_OUT.3')).bindStream(daq.getStream('ANALOG_IN.3'));
            obj.addDevice(amp4);
            
            trigger1 = UnitConvertingDevice('Trigger1', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('DIGITAL_OUT.1'));
            daq.getStream('DIGITAL_OUT.1').setBitPosition(trigger1, 0);
            obj.addDevice(trigger1);
            
            %lightCrafter = fi.helsinki.biosci.ala_laurila.devices.LightCrafterDevice('micronsPerPixel', 1.6);
            %lightCrafter.setConfigurationSetting('frameTrackerPosition', [40, 40]])
            %lightCrafter.setConfigurationSetting('frameTrackerSize', [80, 80])
            %obj.addDevice(lightCrafter);
        end
        
    end
    
end

