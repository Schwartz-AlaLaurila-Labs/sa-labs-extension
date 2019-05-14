classdef SchwartzLab_Rig_A_UVProjector < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig A UV Projector';
        testMode = false;
        filterWheelNdfValues = [2, 4, 5, 6, 7, 8];
        filterWheelDefaultValue = 5;
        
        % updated 5/14/19 SAC
        filterWheelAttenuationValues_Green = [1, .0106, .0016, .0001, 0, .0663];
        filterWheelAttenuationValues_Blue = [1, .0113, .0027, .0001, .00001, .0578];
        filterWheelAttenuationValues_UV = [1, .0026, 0, 0, 0, .948];
        
        fitBlue = [-4.12969088427779e-12,1.76186023670153e-09,-7.25142913686745e-09];
        fitGreen =[-4.89191631033382e-12,2.25392165538544e-09,-1.31352770835765e-08];
        fitUV = [-2.78028975564508e-14,2.23045870111502e-11,1.89444080767412e-09];
        
        micronsPerPixel = 1.38;
        frameTrackerPosition = [0,0];
        frameTrackerSize = [550,550];
        filterWheelComPort = 'COM8';
        orientation = [false, true];
        angleOffset = 0;
        
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

