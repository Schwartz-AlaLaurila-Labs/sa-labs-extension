classdef CellPair < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = CellPair(parent)
            import symphonyui.core.*;
            
            if nargin == 1
                sources = parent.getAllSources;
                cells = cellfun(@(x) strcmp(x.getDescriptionType,'sa_labs.sources.retina.Cell'), sources);
                cell_ids = cellfun(@(x) num2str(x.getProperty('number')), sources(cells),'uni',0);
                if numel(cell_ids) < 2
                    error('Parent retina needs at least 2 cell children!');
                end
                if numel(unique(cell_ids)) < numel(cell_ids)
                    error('Parent retina has multiple cells with the same number! This must be corrected before creating a pair.');
                end
            else
                cell_ids = [];
            end
            allowable_cell_numbers = [{''},cell_ids];%cat(2,uint8(0),cell_ids);
            
            obj.addProperty('Amplifier 1 cell number','',...
                'description', 'The number of the cell in amp 1','type',PropertyType('char','row',allowable_cell_numbers));
            
            obj.addProperty('Amplifier 2 cell number','',...
                'description', 'The number of the cell in amp 2','type',PropertyType('char','row',allowable_cell_numbers));
            
            obj.addAllowableParentType('sa_labs.sources.Retina');
        end
    end
    
end

