classdef TestRig_SchwartzLab < sa_labs.rigs.SchwartzLab_Rig_Base

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
        filterWheelComPort = nan;
        
        projectorColorMode = 'standard';
    end
    
    methods
        
        function obj = TestRig_SchwartzLab()

            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            if obj.testMode
                daq = HekaSimulationDaqController();
            else
                daq = HekaDaqController(HekaDeviceType.USB18);
            end
            
            obj.daqController = daq;

%             if obj.testMode
                amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
                amp2 = MultiClampDevice('Amp2', 2).bindStream(daq.getStream('ao1')).bindStream(daq.getStream('ai1'));
%             else
%                 amp1 = MultiClampDevice('Amp1', 1, obj.amp1Id).bindStream(daq.getStream('ao0')).bindStream(daq.getStream('ai0'));
%                 amp2 = MultiClampDevice('Amp2', 2, obj.amp2Id).bindStream(daq.getStream('ao1')).bindStream(daq.getStream('ai1'));
%             end
            obj.addDevice(amp1);
            obj.addDevice(amp2);
                
            
            propertyDevice = sa_labs.devices.RigPropertyDevice(obj.rigName, obj.testMode);
            obj.addDevice(propertyDevice);

            if ~obj.testMode
                oscopeTrigger = UnitConvertingDevice('Oscilloscope Trigger', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
                daq.getStream('doport1').setBitPosition(oscopeTrigger, 0);
                obj.addDevice(oscopeTrigger);
            end
            
            if ~isnan(obj.filterWheelComPort)
                neutralDensityFilterWheel = sa_labs.devices.NeutralDensityFilterWheelDevice(obj.filterWheelComPort);
                neutralDensityFilterWheel.setConfigurationSetting('filterWheelNdfValues', obj.filterWheelNdfValues);
                neutralDensityFilterWheel.addResource('filterWheelAttentuationValues', obj.filterWheelAttentuationValues);
                obj.addDevice(neutralDensityFilterWheel);
            end
            
            lightCrafter = sa_labs.devices.LightCrafterDevice('colorMode', obj.projectorColorMode);
            lightCrafter.setConfigurationSetting('micronsPerPixel', obj.micronsPerPixel);
            lightCrafter.setConfigurationSetting('frameTrackerPosition', obj.frameTrackerPosition);
            lightCrafter.setConfigurationSetting('frameTrackerSize', obj.frameTrackerSize);
            lightCrafter.addResource('fitBlue', obj.fitBlue);
            lightCrafter.addResource('fitGreen', obj.fitGreen);
            lightCrafter.addResource('projectorAngleOffset', obj.projectorAngleOffset);
            obj.addDevice(lightCrafter);

        end        
        
    end
end

