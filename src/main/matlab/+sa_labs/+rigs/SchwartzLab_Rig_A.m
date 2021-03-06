classdef SchwartzLab_Rig_A < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig A';
        testMode = false;
        daq_type = 'Heka';
        
        filterWheelNdfValues = [2, 4, 5, 6, 7, 8];
        filterWheelDefaultValue = 5;
        filterWheelAttenuationValues = [0.0105, 8.0057e-05, 6.5631e-06, 5.5485e-07, 5.5485e-08, 5.5485e-09];
        micronsPerPixel = 1.38;
        frameTrackerPosition = [0,0];
        frameTrackerSize = [550,550];
        filterWheelComPort = 'COM8';
        orientation = [false, true]; %[flip Y, flip X]
        angleOffset = 0;  %Does not actually change presentation.  %Does not actually change presentation.  Could be used in analysis but not right now.
        
        fitBlue = [1.97967e-11,	-4.35548e-09,	8.49409e-07,	1.07816e-05];
        fitGreen =[1.9510e-12, -1.4200e-09, 5.1430e-07, 9.6550e-06];
        fitUV = [];
        
        projectorColorMode = 'standard';
        numberOfAmplifiers = 2;
        
        enableDynamicClamp = false;
    end
    
    methods
        
        function obj = SchwartzLab_Rig_A(delayInit)
            if nargin < 1
                delayInit = false;
            end
            
            if ~delayInit
                obj.initializeRig();
            end
        end
        
    end
    
end

