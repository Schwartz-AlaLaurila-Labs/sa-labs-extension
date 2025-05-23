classdef BrainCell < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = BrainCell(parent)
            import symphonyui.core.*;
                       
            obj.addProperty('number',uint8(0),'type',PropertyType('uint8','scalar'),...
                'description', 'The number of the cell (just the number)')
            
            obj.addProperty('notes', '', ...
                'description', 'Notes about this recording');
                                 
            obj.addProperty('location',[0,0],...
                'description', 'coordinates of the cell relative to some landmark in the brain');
            
            obj.addAllowableParentType('sa_labs.sources.BrainRegion');
        end
        
    end
    
end