classdef SchwartzLab_Rig_A < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = SchwartzLab_Rig_A()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
%             
            daq = HekaDaqController(HekaDeviceType.USB18);
            obj.daqController = daq;

            amp1 = MultiClampDevice('Amp1', 1, 834077).bindStream(daq.getStream('ANALOG_OUT.0')).bindStream(daq.getStream('ANALOG_IN.0'));
            obj.addDevice(amp1);
            
            amp2 = MultiClampDevice('Amp2', 2, 834077).bindStream(daq.getStream('ANALOG_OUT.1')).bindStream(daq.getStream('ANALOG_IN.1'));
            obj.addDevice(amp2);
            
            stage = io.github.stage_vss.devices.StageDevice('localhost');
            stage.addConfigurationSetting('micronsPerPixel', 1.6, 'isReadOnly', true);
            stage.addConfigurationSetting('projectorAngleOffset', 0, 'isReadOnly', true);

            obj.addDevice(stage);
            
%             lightCrafter = sa_labs.devices.LightCrafterDevice();
%             lightCrafter.addConfigurationSetting('micronsPerPixel', 1.6, 'isReadOnly', true);
%             obj.addDevice(lightCrafter);
        end
        
    end
    
end

