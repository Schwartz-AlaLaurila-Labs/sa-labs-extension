classdef SchwartzLab_Rig_A_UVProjector < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig A UV Projector';
        testMode = false;
        filterWheelNdfValues = [1, 2, 3, 4, 5, 22];
        filterWheelDefaultValue = 5;
        
        filterWheelAttenuationValues_Blue = [.1, .00702, .000551, .0000477, .00000523, .001];%updated 11/21/2019 -David
        filterWheelAttenuationValues_Green = [1,1,1,1,1,1];%Green projector broken 
        filterWheelAttenuationValues_UV = [.1, .00172, .0000807, .00000652, .0000027, .00172];%updated 11/21/2019 -David
        
        fitBlue = [4.71e-12, -7.68e-9, 2.84e-6, -1.19e-5];%updated 11/21/2019 -David
        fitGreen =[-6.80e-13, -4.58e-11, 1.56e-7, 1.49e-5];%Green projector broken
        fitUV = [-6.80e-13, -4.58e-11, 1.56e-7, 1.49e-5];%updated 11/21/2019 -David
        
        micronsPerPixel = 1.21;%updated 11/21/2019 -David
        frameTrackerPosition = [0,0];
        frameTrackerSize = [550,550];
        filterWheelComPort = 'COM8';
        orientation = [false, true];
        angleOffset = 0;
        
        %Overlap of the Rod, S_cone, and M_cone spectrum with each LED. Must be in order [1 Rod, 2 S cone, 3 M cone]
        spectralOverlap_Blue = [4.73506311955843e+18,4.35096443208340e+15,3.77614022065689e+18];%updated 11/21/2019 -David
        spectralOverlap_Green = [3.23202384601926e+18,470157632364029,4.54479333609599e+18];%Green projector broken
        spectralOverlap_UV = [9.35392735238728e+17,1.45353301827043e+18,1.11745334749763e+18];%updated 11/21/2019 -David
        
        projectorColorMode = 'uv2'; % Rig A has MkII projector
        numberOfAmplifiers = 2;
        
        enableDynamicClamp = false;
    end
    
    methods
        
        function obj = SchwartzLab_Rig_A_UVProjector(delayInit)
            if nargin < 1
                delayInit = false;
            end
            
            if ~delayInit
                obj.initializeRig();
            end
        end
        
    end
    
end

