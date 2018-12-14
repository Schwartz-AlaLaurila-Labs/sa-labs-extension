classdef SchwartzLab_Rig_A_UVProjector < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig A UV Projector';
        testMode = false;
        filterWheelNdfValues = [2, 4, 5, 6, 7, 8];
        filterWheelDefaultValue = 5;
        filterWheelAttenuationValues_Green = [1, .01, .001, .0001, 0, 0];
        filterWheelAttenuationValues_Blue = [1, .0073, .00072, .0001, .00001, .000001];
        filterWheelAttenuationValues_UV = [1, .0049, .0027, 0, 0, 0];
        micronsPerPixel = 1.38;
        frameTrackerPosition = [0,0];
        frameTrackerSize = [550,550];
        filterWheelComPort = 'COM8';
        orientation = [false, true];
        angleOffset = 0;
        
        fitBlue = [3.46902552495379e-14,-1.37685313164116e-11,3.15370683929025e-09,-1.44962712464649e-08];
        fitGreen =[2.58038688962281e-14,-1.29545015871977e-11,3.60389025129295e-09,-2.16775315211613e-08];
        fitUV = [2.96965590127296e-16,-1.32952775434061e-13,4.14642042203279e-11,2.82460395102315e-09];
        
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

