classdef (Abstract) Preparation < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Preparation()
            import symphonyui.core.*;
            
            obj.addProperty('time', datestr(now), ...
                'type', PropertyType('char', 'row', 'datestr'), ...
                'description', 'Time the preparation was prepared');
            obj.addProperty('region', {}, ...
                'type', PropertyType('cellstr', 'row', {'fovea', 'parafovea', 'peripheral', 'temporal', 'nasal', 'dorsal', 'ventral'}));
            obj.addProperty('preparation', '', ...
                'type', PropertyType('char', 'row', {'', 'shredded retina', 'whole mount, cones up', 'whole mount, RGCs up', 'slice'}));
            obj.addProperty('bathSolution', '', ...
                'type', PropertyType('char', 'row', {'', 'Ames'}), ...
                'description', 'The solution the preparation is bathed in');   
        end
        
    end
    
end

