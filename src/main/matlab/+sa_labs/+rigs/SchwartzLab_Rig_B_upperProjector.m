classdef SchwartzLab_Rig_B_upperProjector < symphonyui.core.descriptions.RigDescription
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B';
        testMode = false;
        filterWheelNdfValues = [0, 2, 3, 4, 5, 6];
        filterWheelAttentuationValues = [1.0, 0.0076, 6.23E-4, 6.93E-5, 8.32E-6, 1.0E-6];
             
        micronsPerPixel = 0.72;
        frameTrackerPosition = [40,250];
        frameTrackerSize = [60,60];
        filterWheelComPort = 'COM12';
        projectorAngleOffset = 270;
        
        NTCfitBlue = [-5.093e-10, 2.899e-07, -2.697e-06]; %added 04/01/16 by Todd -- fit coeff. for non tricolor stimuli on upper projector 6/16 edit
        NTCfitGreen = [-5.266e-11, 3.749e-08, 4.664e-07]; %added 04/01/16 by Todd -- fit coeff. for non tricolor stimuli on upper projector
        NTCfitUV = [-3.593e-12, 5.752e-09, 5.097e-07]; %added 04/01/16 by Todd -- fit coeff. for non tricolor stimuli on upper projector
        fitBlue = [-1.566e-10, 1.317e-07, -9.457e-07]; %added 3/21/16 by Todd for TriColor stims
        fitGreen = [-1.931e-11, 1.278e-08,  1.389e-07]; %added 3/21/16 by Todd for TriColor stims
        fitUV = [-2.346e-12, 1.883e-09,1.58e-07]; %added 3/21/16 by Todd for TriColor stims
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

