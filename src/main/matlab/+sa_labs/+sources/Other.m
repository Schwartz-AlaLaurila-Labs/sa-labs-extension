classdef Other < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Other()
            import symphonyui.core.*;
            
            obj.addProperty('Description','',...
                'description', 'What is being recorded?');

            obj.addAllowableParentType([]);
        end
        
    end
    
end

