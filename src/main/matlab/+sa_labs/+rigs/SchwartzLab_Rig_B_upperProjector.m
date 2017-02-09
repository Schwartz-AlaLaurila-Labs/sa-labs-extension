classdef SchwartzLab_Rig_B_upperProjector < symphonyui.core.descriptions.RigDescription
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B';
        testMode = false;
        filterWheelNdfValues = [0, 2, 3, 4, 5, 6];
        filterWheelAttentuationValues = [1.0, 0.0076, 6.23E-4, 6.93E-5, 8.32E-6, 1.0E-6];
             
        micronsPerPixel = 2.3;
        frameTrackerPosition = [40,250];
        frameTrackerSize = [60,60];
        filterWheelComPort = 'COM12';
        projectorAngleOffset = 270;

        fitBlue = [7.89617359432192e-12 -4.46160989505515e-09 1.32776088533859e-06 1.96157899559780e-05];
        fitGreen =[4.432E-12, -3.514E-9, 1.315E-6, 1.345E-5];
        %PREVIOUS fitBlue = [7.603E-12, -6.603E-9, 2.133E-6, 3.398E-5];
        %PREVIOUS fitBlue = [1.0791E-11 -6.3562E-09 1.8909E-06 2.8196E-05];
    end
    
    
    methods
        
        function obj = SchwartzLab_Rig_B_upperProjector()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
%             
            daq = HekaDaqController(HekaDeviceType.USB18);
            obj.daqController = daq;

            amp1 = MultiClampDevice('Amp1', 1, 834065).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);
            
            amp2 = MultiClampDevice('Amp2', 2, 834065).bindStream(daq.getStream('ao1')).bindStream(daq.getStream('ai1'));
            obj.addDevice(amp2);
            
            propertyDevice = sa_labs.devices.RigPropertyDevice(obj.rigName, obj.testMode);
            obj.addDevice(propertyDevice);

            oscopeTrigger = UnitConvertingDevice('Oscilloscope Trigger', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(oscopeTrigger, 0);
            obj.addDevice(oscopeTrigger);
            
            neutralDensityFilterWheel = sa_labs.devices.NeutralDensityFilterWheelDevice(obj.filterWheelComPort);
            neutralDensityFilterWheel.setConfigurationSetting('filterWheelNdfValues', obj.filterWheelNdfValues);
            neutralDensityFilterWheel.addResource('filterWheelAttentuationValues', obj.filterWheelAttentuationValues);
            obj.addDevice(neutralDensityFilterWheel);
            
            lightCrafter = sa_labs.devices.LightCrafterDevice('micronsPerPixel', obj.micronsPerPixel);
            lightCrafter.setConfigurationSetting('frameTrackerPosition', obj.frameTrackerPosition)
            lightCrafter.setConfigurationSetting('frameTrackerSize', obj.frameTrackerSize)
            lightCrafter.addResource('fitBlue', obj.fitBlue);
            lightCrafter.addResource('fitGreen', obj.fitGreen);
            lightCrafter.addResource('projectorAngleOffset', obj.projectorAngleOffset);
            obj.addDevice(lightCrafter);

        end
        
    end
    
end

