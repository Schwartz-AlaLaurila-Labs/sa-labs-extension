classdef SchwartzLab_Rig_B < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B';
        testMode = true;
        filterWheelNdfValues = [0, 2, 3, 4, 5, 6];
        %filterWheelAttenuationValues = [1, 0.006623377, 0.000527273, 6.49351E-05, 1.36883E-05, 9.87013E-06];
        filterWheelAttenuationValues_Blue = [1, 0.006623377, 0.000527273, 6.49351E-05, 1.36883E-05, 9.87013E-06];
        filterWheelAttenuationValues_Green = [1.0, 0.0076, 6.23E-4, 6.93E-5, 8.32E-6, 1.0E-6];
        filterWheelAttenuationValues_UV = [1.0, 0.0076, 6.23E-4, 6.93E-5, 8.32E-6, 1.0E-6];
        filterWheelDefaultValue = 5;
             
        %micronsPerPixel = 2.3;
        micronsPerPixel = 2.27; %updated 11/21/2019 -David
        frameTrackerPosition = [90,240];
        frameTrackerSize = [50,50];
        filterWheelComPort = 'COM7';
        orientation = [false, false];
        angleOffset = 270;


        fitBlue = [2.11680702221393e-11,-1.68958902094615e-08,6.04551140124767e-06,-6.49883631979073e-05]; %updated 11/21/2019 -David
        fitGreen =[4.432E-12, -3.514E-9, 1.315E-6, 1.345E-5];
        fitUV = [-0.0004    0.0320   -0.3053    0.2924];

        
        projectorColorMode = 'standard';
        numberOfAmplifiers = 2;
        
        enableDynamicClamp = false;
    end
    
    methods
        
        function obj = SchwartzLab_Rig_B(delayInit)
            if nargin < 1
                delayInit = false;
            end
            
            if ~delayInit
                obj.initializeRig();
            end
        end

    end
    
end

