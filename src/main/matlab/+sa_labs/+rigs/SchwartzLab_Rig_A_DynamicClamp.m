classdef SchwartzLab_Rig_A_DynamicClamp < sa_labs.rigs.SchwartzLab_Rig_A_UVProjector
    methods
        function obj = SchwartzLab_Rig_A_DynamicClamp
            obj = obj@sa_labs.rigs.SchwartzLab_Rig_A_UVProjector(true);
            
            obj.enableDynamicClamp = true;
            
            obj.initializeRig();
        end
    end
    
end