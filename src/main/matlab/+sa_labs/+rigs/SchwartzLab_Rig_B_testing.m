classdef SchwartzLab_Rig_B_testing < sa_labs.rigs.SchwartzLab_Rig_B
    
    methods
        function self = SchwartzLab_Rig_B_testing(delayInit)
            self@sa_labs.rigs.SchwartzLab_Rig_B(true); %delay init
            self.host = 'localhost';
            self.lcr = @MockLightCrafter4500;
            self.filterWheelComPort = -1;

            if nargin < 1
                delayInit = false;
            end

            if ~delayInit
                self.initializeRig();
            end

        end

    end
    
end