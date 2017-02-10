classdef TestRig_SchwartzLab_upperProjector < sa_labs.rigs.SchwartzLab_Rig_Base

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
        amp1Id = 1;
        amp2Id = 2;        
        
        projectorColorMode = 'uv';
    end
    
    methods
        
        function obj = TestRig_SchwartzLab_upperProjector()
            obj.initializeRig();
        end
    end
end

