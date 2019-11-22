classdef SchwartzLab_Rig_B < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B';
        testMode = true;
        filterWheelNdfValues = [0, 2, 3, 4, 5, 6];
        filterWheelDefaultValue = 5;
        
        filterWheelAttenuationValues_Blue = [1, 0.006623377, 0.000527273, 6.49351E-05, 1.36883E-05, 9.87013E-06];%updated 11/21/2019 -David
        filterWheelAttenuationValues_Green = [1	0.008701299	0.000746753	0.000101948	3.1039E-05	2.48701E-05];%updated 11/21/2019 -David
        filterWheelAttenuationValues_UV = [1, 1, 1, 1, 1, 1]; %There is no UV
        
        fitBlue = [2.11680702221393e-11,-1.68958902094615e-08,6.04551140124767e-06,-6.49883631979073e-05]; %updated 11/21/2019 -David
        fitGreen =[9.96590499225804e-12,-8.40676772857698e-09,3.41802854614407e-06,-7.41382302342572e-05];%updated 11/21/2019 -David
        fitUV = 0;
        
        micronsPerPixel = 2.27; %updated 11/21/2019 -David
        frameTrackerPosition = [90,240];
        frameTrackerSize = [50,50];
        filterWheelComPort = 'COM7';
        orientation = [false, false];
        angleOffset = 270;
        
        %Overlap of the Rod, S_cone, and M_cone spectrum with each LED. Must be in order [1 Rod, 2 S cone, 3 M cone]
        spectralOverlap_Blue = [4.49937844347436e+18,4.24282748934854e+15,3.54491702447797e+18];%updated 11/21/2019 -David
        spectralOverlap_Green = [3.23202384601926e+18,470157632364029,4.54479333609599e+18];%updated 11/21/2019 -David
        spectralOverlap_UV = [0, 0, 0];
        
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

