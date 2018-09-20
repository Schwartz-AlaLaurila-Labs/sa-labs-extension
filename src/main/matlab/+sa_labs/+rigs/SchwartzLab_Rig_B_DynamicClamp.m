classdef SchwartzLab_Rig_B_DynamicClamp < sa_labs.rigs.SchwartzLab_Rig_B
    methods
        function obj = SchwartzLab_Rig_B_DynamicClamp()
            obj = obj@sa_labs.rigs.SchwartzLab_Rig_B(true);
            
            obj.enableDynamicClamp = true;
            
            obj.initializeRig();
        end
    end
end