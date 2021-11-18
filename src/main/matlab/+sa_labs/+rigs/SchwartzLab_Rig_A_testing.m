classdef SchwartzLab_Rig_A_testing < sa_labs.rigs.SchwartzLab_Rig_A_UVProjector
    
    methods
        function self = SchwartzLab_Rig_A_testing(delayInit)
            self@sa_labs.rigs.SchwartzLab_Rig_A_UVProjector(true); %delay init
            self.host = 'localhost';
            self.lcr = @MockLightCrafter4500;
            self.filterWheelComPort = -1;
            self.testMode = true;

            if nargin < 1
                delayInit = false;
            end

            if ~delayInit
                self.initializeRig();
            end

        end

    end
    
end