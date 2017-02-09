classdef TestRig_SchwartzLab_upperProjector < symphonyui.core.descriptions.RigDescription

    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Test Rig';
        testMode = true;
        filterWheelValidPositions = [2, 4, 5, 6, 7, 8];
        filterWheelAttentuationValues = [0.0105, 8.0057e-05, 6.5631e-06, 5.5485e-07, 5.5485e-08, 5.5485e-09];
        fitBlue = [3.1690e-12, -2.2180e-09, 7.3530e-07, 1.0620e-05];
        fitGreen =[1.9510e-12, -1.4200e-09, 5.1430e-07, 9.6550e-06];
        micronsPerPixel = 1.6;
        projectorAngleOffset = 180;
        frameTrackerPosition = [40,40];
        frameTrackerSize = [80,80];
        filterWheelComPort = 'COM8';
        
        projectorColorMode = 'BUG';
    end
    
    methods
        
        function obj = TestRig_SchwartzLab_upperProjector()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
                        
            daq = HekaSimulationDaqController();
            obj.daqController = daq;
            
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
            obj.addDevice(amp1);
            
            amp2 = MultiClampDevice('Amp2', 2).bindStream(daq.getStream('ao1')).bindStream(daq.getStream('ai1'));
            obj.addDevice(amp2);
            
%             amp3 = MultiClampDevice('Amp3', 3).bindStream(daq.getStream('ANALOG_OUT.2')).bindStream(daq.getStream('ANALOG_IN.2'));
%             obj.addDevice(amp3);
% 
%             amp4 = MultiClampDevice('Amp4', 4).bindStream(daq.getStream('ANALOG_OUT.3')).bindStream(daq.getStream('ANALOG_IN.3'));
%             obj.addDevice(amp4);
                        
            oscopeTrigger = UnitConvertingDevice('Oscilloscope Trigger', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('doport0'));
            daq.getStream('doport0').setBitPosition(oscopeTrigger, 0);
            obj.addDevice(oscopeTrigger);

            propertyDevice = sa_labs.devices.RigPropertyDevice(obj.rigName, obj.testMode);
            obj.addDevice(propertyDevice);
            
%             neutralDensityFilterWheel = sa_labs.devices.NeutralDensityFilterWheelDevice(obj.filterWheelComPort);
%             neutralDensityFilterWheel.setConfigurationSetting('filterWheelValidPositions', obj.filterWheelValidPositions);
%             neutralDensityFilterWheel.addResource('filterWheelAttentuationValues', obj.filterWheelAttentuationValues);
%             obj.addDevice(neutralDensityFilterWheel);
            
            lightCrafter = sa_labs.devices.LightCrafterDevice('micronsPerPixel', obj.micronsPerPixel, 'colorMode', 'tricolor');
            lightCrafter.setConfigurationSetting('frameTrackerPosition', obj.frameTrackerPosition)
            lightCrafter.setConfigurationSetting('frameTrackerSize', obj.frameTrackerSize)
            lightCrafter.addResource('fitBlue', obj.fitBlue);
            lightCrafter.addResource('fitGreen', obj.fitGreen);
            lightCrafter.addResource('projectorAngleOffset', obj.projectorAngleOffset);
            obj.addDevice(lightCrafter);
        end
    end
end

