classdef Mouse < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Mouse()
            import symphonyui.core.*;
            
            obj.addProperty('genotype', 'WT',...
                'type', PropertyType('char', 'row'));
            
            obj.addProperty('eye', 'left', ...
                'type',PropertyType('char', 'row', {'left','right'}),...
                'description', 'The eye');
            
            obj.addProperty('orientation', 'ventral down', ...
                'type',PropertyType('char', 'row', {'ventral down','ventral up'}),...
                'description', 'eye placement orientation');
            
            obj.addAllowableParentType([]);
        end
        
    end
    
end

