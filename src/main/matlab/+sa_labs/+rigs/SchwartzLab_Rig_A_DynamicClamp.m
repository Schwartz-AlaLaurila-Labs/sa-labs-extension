classdef SchwartzLab_Rig_A_DynamicClamp < sa_labs.rigs.SchwartzLab_Rig_A
    methods
        function obj = SchwartzLab_Rig_A_DynamicClamp
            obj.enableDynamicClamp = true;
            obj.initializeRig();
        end
    end
    
end