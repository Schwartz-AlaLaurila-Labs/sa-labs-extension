classdef Cell < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Cell()
            import symphonyui.core.*;
            
            obj.addProperty('number',int32(1),...
                'description', 'The number of the cell (just the number)',...
                PropertyType('int32', 'scalar'))
            
            obj.addProperty('type', '', ...
                'description', 'The type of the recorded cell');
            
            obj.addProperty('location',[0,0],...
                'description', 'coordinates of the cell on the retina');
            
            obj.addAllowableParentType('sa_labs.sources.Mouse');
        end
        
    end
    
end

