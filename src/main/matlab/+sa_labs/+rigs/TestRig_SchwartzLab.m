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
            
%             amp3 = MultiClampDevice('Amp3', 3).bindStream(daq.getStream('ANALOG_OUT.2')).bindStream(daq.getStream('ANALOG_IN.2'));
%             obj.addDevice(amp3);
% 
%             amp4 = MultiClampDevice('Amp4', 4).bindStream(daq.getStream('ANALOG_OUT.3')).bindStream(daq.getStream('ANALOG_IN.3'));
%             obj.addDevice(amp4);
                        
%             trigger1 = UnitConvertingDevice('Trigger1', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('DIGITAL_OUT.1'));
%             daq.getStream('DIGITAL_OUT.1').setBitPosition(trigger1, 0);
%             obj.addDevice(trigger1);


            filterWheelValidPositions = [2, 4, 5, 6, 7, 8];
            filterWheelAttentuationValues = [0.0105, 8.0057e-05, 6.5631e-06, 5.5485e-07, 5.5485e-08, 5.5485e-09];
            
            neutralDensityFilterWheel = sa_labs.devices.NeutralDensityFilterWheelDevice('COM8');
            neutralDensityFilterWheel.setConfigurationSetting('filterWheelValidPositions', filterWheelValidPositions);
            neutralDensityFilterWheel.addResource('filterWheelAttentuationValues', filterWheelAttentuationValues);
            obj.addDevice(neutralDensityFilterWheel);
            
            lightCrafter = sa_labs.devices.LightCrafterDevice('micronsPerPixel', 1.6);
            lightCrafter.setConfigurationSetting('frameTrackerPosition', [40,40])
            lightCrafter.setConfigurationSetting('frameTrackerSize', [80,80])
            obj.addDevice(lightCrafter);
        end
    end
end

