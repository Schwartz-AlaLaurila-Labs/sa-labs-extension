classdef SchwartzLab_Rig_B_DynamicClamp < sa_labs.rigs.SchwartzLab_Rig_B
    methods
        function obj = SchwartzLab_Rig_B_DynamicClamp
            obj.enableDyanmicClamp = true;
            obj.initializeRig();
        end
    end
end