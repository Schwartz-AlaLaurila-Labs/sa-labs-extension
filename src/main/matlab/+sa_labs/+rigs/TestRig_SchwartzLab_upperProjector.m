classdef TestRig_SchwartzLab_upperProjector < sa_labs.rigs.SchwartzLab_Rig_Base

    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Test Rig';
        testMode = true;
        filterWheelNdfValues = [2, 4, 5, 6, 7, 8];
        filterWheelDefaultValue = 5;
        filterWheelAttenuationValues = [0.0105, 8.0057e-05, 6.5631e-06, 5.5485e-07, 5.5485e-08, 5.5485e-09];
        filterWheelComPort = -1; % 
        numberOfAmplifiers = 2;
        
        fitBlue = [-1.566e-10, 1.317e-07, -9.457e-07];
        fitGreen = [-1.931e-11, 1.278e-08,  1.389e-07];
        fitUV = [];
        
        micronsPerPixel = 0.7;
        projectorAngleOffset = 180;
        frameTrackerPosition = [20,20];
        frameTrackerSize = [40,40];
        
        
        projectorColorMode = 'uv';
    end
    
    methods
        
        function obj = TestRig_SchwartzLab_upperProjector()
            obj.initializeRig();
        end

        
    end
end

