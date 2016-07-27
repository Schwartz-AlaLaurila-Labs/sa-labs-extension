classdef Preparation < fi.helsinki.biosci.ala_laurila.sources.Preparation
    
    methods
        
        function obj = Preparation()
            import symphonyui.core.*;
            
            obj.addAllowableParentType('fi.helsinki.biosci.ala_laurila.sources.mouse.Mouse');
        end
        
    end
    
end

