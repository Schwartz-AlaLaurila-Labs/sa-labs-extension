classdef Cell < sa_labs.sources.Cell
    
    methods
        
        function obj = Cell()
            import symphonyui.core.*;
            
            obj.addProperty('type', '', ...
                'description', 'The type of the recorded cell');
            
            obj.addAllowableParentType('sa_labs.sources.Mouse');
        end
        
    end
    
end

