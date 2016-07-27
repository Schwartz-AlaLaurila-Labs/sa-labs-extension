classdef TestRig_SchwartzLab < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = TestRig_SchwartzLab()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = HekaSimulationDaqController();
            obj.daqController = daq;
            
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ANALOG_OUT.0')).bindStream(daq.getStream('ANALOG_IN.0'));
            obj.addDevice(amp1);
            
            amp2 = MultiClampDevice('Amp2', 2).bindStream(daq.getStream('ANALOG_OUT.1')).bindStream(daq.getStream('ANALOG_IN.1'));
            obj.addDevice(amp2);
            
            trigger1 = UnitConvertingDevice('Trigger1', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('DIGITAL_OUT.1'));
            daq.getStream('DIGITAL_OUT.1').setBitPosition(trigger1, 0);
            obj.addDevice(trigger1);
            
            stage = io.github.stage_vss.devices.StageDevice('localhost');
            stage.addConfigurationSetting('micronsPerPixel', 1.6, 'isReadOnly', true);
            stage.addConfigurationSetting('frameTrackerPosition', [20, 20], 'isReadOnly', true);
            stage.addConfigurationSetting('projectorAngleOffset', 0, 'isReadOnly', true);

            obj.addDevice(stage);
            
%             lightCrafter = fi.helsinki.biosci.ala_laurila.devices.LightCrafterDevice();
%             lightCrafter.addConfigurationSetting('micronsPerPixel', 1.6, 'isReadOnly', true);
%             obj.addDevice(lightCrafter);
        end
        
    end
    
end

