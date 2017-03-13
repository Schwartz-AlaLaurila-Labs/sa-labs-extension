classdef SchwartzLab_Rig_B_upperProjector < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B Upper Projector';
        testMode = false;
        filterWheelNdfValues = [2, 3, 4]; % calibration code has the NDF3 built in, so these are relative to that
        filterWheelDefaultValue = 4;
        filterWheelAttenuationValues = [10, 1.0, 0.1];
        
        micronsPerPixel = 0.72;
        frameTrackerPosition = [90,240];
        frameTrackerSize = [50,50];
        filterWheelComPort = -1;
        orientation = [true, false];
        
        fitBlue = [-5.093e-10, 2.899e-07, -2.697e-06]; %added 04/01/16 by Todd -- fit coeff. for non tricolor stimuli on upper projector 6/16 edit
        fitGreen = [-5.266e-11, 3.749e-08, 4.664e-07]; %added 04/01/16 by Todd -- fit coeff. for non tricolor stimuli on upper projector
        fitUV = [-3.593e-12, 5.752e-09, 5.097e-07]; %added 04/01/16 by Todd -- fit coeff. for non tricolor stimuli on upper projector
%         fitBlue = [-1.566e-10, 1.317e-07, -9.457e-07]; %added 3/21/16 by Todd for TriColor stims
%         fitGreen = [-1.931e-11, 1.278e-08,  1.389e-07]; %added 3/21/16 by Todd for TriColor stims
%         fitUV = [-2.346e-12, 1.883e-09,1.58e-07]; %added 3/21/16 by Todd for TriColor stims
        %PREVIOUS fitBlue = [7.603E-12, -6.603E-9, 2.133E-6, 3.398E-5];
        %PREVIOUS fitBlue = [1.0791E-11 -6.3562E-09 1.8909E-06 2.8196E-05];
        
        projectorColorMode = 'uv';
        numberOfAmplifiers = 1;
    end
    
    
    methods
        
        function obj = SchwartzLab_Rig_B_upperProjector()
            obj.initializeRig();
        end
        
    end
    
end

