classdef SchwartzLab_Rig_A < symphonyui.core.descriptions.RigDescription
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig A';
        testMode = false;
        filterWheelValidPositions = [2, 4, 5, 6, 7, 8];
        filterWheelAttentuationValues = [0.0105, 8.0057e-05, 6.5631e-06, 5.5485e-07, 5.5485e-08, 5.5485e-09];
        micronsPerPixel = 1.6;
        frameTrackerPosition = [40,40];
        frameTrackerSize = [80,80];
        filterWheelComPort = 'COM8';
    end
    
    
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
            
            propertyDevice = sa_labs.devices.RigPropertyDevice(obj.rigName, obj.testMode);
            obj.addDevice(propertyDevice);
            
            lightCrafter = sa_labs.devices.LightCrafterDevice('micronsPerPixel', 1.6);
            lightCrafter.setConfigurationSetting('frameTrackerPosition', [40,40])
            lightCrafter.setConfigurationSetting('frameTrackerSize', [80,80])
            obj.addDevice(lightCrafter);

        end
        
    end
    
end

