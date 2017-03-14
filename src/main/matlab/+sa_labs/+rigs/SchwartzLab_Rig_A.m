classdef SchwartzLab_Rig_A < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig A';
        testMode = false;
        filterWheelNdfValues = [2, 4, 5, 6, 7, 8];
        filterWheelDefaultValue = 5;
        filterWheelAttenuationValues = [0.0105, 8.0057e-05, 6.5631e-06, 5.5485e-07, 5.5485e-08, 5.5485e-09];
        micronsPerPixel = 1.38;
        frameTrackerPosition = [70,110];
        frameTrackerSize = [60,60];
        filterWheelComPort = 'COM8';
        orientation = [false, false];
        angleOffset = 180;
        
        fitBlue = [1.97967e-11,	-4.35548e-09,	8.49409e-07,	1.07816e-05];
        fitGreen =[1.9510e-12, -1.4200e-09, 5.1430e-07, 9.6550e-06];
        fitUV = [];
        
        projectorColorMode = 'standard';
        numberOfAmplifiers = 1;
    end
    
    methods
        
        function obj = SchwartzLab_Rig_A()
            obj.initializeRig();
        end
        
    end
    
end

