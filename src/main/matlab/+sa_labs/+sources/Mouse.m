classdef Mouse < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Mouse()
            import symphonyui.core.*;
            
            obj.addProperty('genotype', 'WT',...
                'type', PropertyType('char', 'row'));
            
            obj.addProperty('eye', 'left', ...
                'type',PropertyType('char', 'row', {'left','right'}),...
                'description', 'The eye');
            
            obj.addAllowableParentType([]);
        end
        
    end
    
end

