classdef Cell < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Cell()
            import symphonyui.core.*;
            
            obj.addProperty('number',int32(1),...
                'description', 'The number of the cell')
            obj.addProperty('type', '', ...
                'description', 'The type of the recorded cell');
            
            obj.addAllowableParentType('sa_labs.sources.Mouse');
        end
        
    end
    
end

