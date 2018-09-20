classdef SchwartzLab_Rig_A_DynamicClamp < sa_labs.rigs.SchwartzLab_Rig_A
    methods
        function obj = SchwartzLab_Rig_A_DynamicClamp
            obj = obj@sa_labs.rigs.SchwartzLab_Rig_A(true);
            
            obj.enableDynamicClamp = true;
            
            obj.initializeRig();
        end
    end
    
end