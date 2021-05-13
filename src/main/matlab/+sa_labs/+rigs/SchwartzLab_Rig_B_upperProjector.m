classdef SchwartzLab_Rig_B_upperProjector < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B Upper Projector';
        testMode = false;
        daq_type = 'NI';
        
        filterWheelNdfValues = [2, 3, 4]; % calibration code has the NDF3 built in, so these are relative to that
        filterWheelDefaultValue = 4;
        filterWheelAttenuationValues = [1/152, 1/1672, 1/4514]; %good for green, not UV, Adam 4/5/17
        
        micronsPerPixel = 0.72;
        frameTrackerPosition = [90,240];
        frameTrackerSize = [50,50];
        filterWheelComPort = -1;
        orientation = [false, false];
        angleOffset = 0;
        
%         fitBlue = [-5.093e-10, 2.899e-07, -2.697e-06]; %added 04/01/16 by Todd -- fit coeff. for non tricolor stimuli on upper projector 6/16 edit
%         fitGreen = [-5.266e-11, 3.749e-08, 4.664e-07]; %added 04/01/16 by Todd -- fit coeff. for non tricolor stimuli on upper projector
%         fitUV = [-3.593e-12, 5.752e-09, 5.097e-07]; %added 04/01/16 by Todd -- fit coeff. for non tricolor stimuli on upper projector
% %         fitBlue = [-1.566e-10, 1.317e-07, -9.457e-07]; %added 3/21/16 by Todd for TriColor stims
% %         fitGreen = [-1.931e-11, 1.278e-08,  1.389e-07]; %added 3/21/16 by Todd for TriColor stims
% %         fitUV = [-2.346e-12, 1.883e-09,1.58e-07]; %added 3/21/16 by Todd for TriColor stims
%         %PREVIOUS fitBlue = [7.603E-12, -6.603E-9, 2.133E-6, 3.398E-5];
%         %PREVIOUS fitBlue = [1.0791E-11 -6.3562E-09 1.8909E-06 2.8196E-05];
        
        %Adam 4/5/17
        fitUV = [3.84818763284936e-10,-5.45824996556614e-08,4.58490484179563e-06,0.000505227085705962]
        fitGreen = [7.79037903477471e-10,-1.74825438498730e-07,4.23593056692171e-05,0.000418635631221793]
        fitBlue = [-5.093e-10, 2.899e-07, -2.697e-06]; %added 04/01/16 by Todd -- fit coeff. for non tricolor
        
        
        projectorColorMode = 'uv';
        numberOfAmplifiers = 1;
    end
    
    
    methods
        
        function obj = SchwartzLab_Rig_B_upperProjector()
            obj.initializeRig();
        end
        
    end
    
end

