classdef SchwartzLab_Rig_B_testing < SchwartzLab_Rig_B
    properties
        %overwrite the default rig properties so that we don't need to be
        %connected to anything
        host = 'localhost';
        lcr = @MockLightCrafter4500;
    end  
    
end