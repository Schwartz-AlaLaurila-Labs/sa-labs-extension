classdef BrainCell < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = BrainCell(parent)
            import symphonyui.core.*;

            %fetch the acronym of the current brain regions
            all_regions = fetchn(sln_animal.BrainArea, 'target');
                       
            obj.addProperty('number',uint8(0),'type',PropertyType('uint8','scalar'),...
                'description', 'The number of the cell (just the number)')
            
            obj.addProperty('notes', '', ...
                'description', 'Notes about this recording');
                  
            %obj.addProperty('brain_region', '', ...
             %   'description', 'Plain text (for now) about the brain region ');
            
            %Getting brain region acronym from table sln_animal.BrainArea for selection
            obj.addProperty('brain_region', '', 'description', ...
                'acronym of the region', 'type', ...
                PropertyType('char', 'row', [{''}; all_regions]));

            obj.addAllowableParentType('sa_labs.sources.brain.BrainSlice');
        end
        
    end
    
end