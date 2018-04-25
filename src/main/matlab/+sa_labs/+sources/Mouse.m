classdef Mouse < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Mouse()
            import symphonyui.core.*;
            
            obj.addProperty('genotype', 'WT',...
                'type', PropertyType('char', 'row'));
            
            obj.addProperty('strain', 'C57BL/6j',...
                'type', PropertyType('char', 'row',  {'C57BL/6j'}));
            
            obj.addProperty('sex', 'Male',...
                'type', PropertyType('char', 'row', {'Male', 'Female'}));
            
            obj.addProperty('age', '',...
                'type', PropertyType('char', 'row'),...
                'description', 'Age in days');

            obj.addProperty('eye', 'right', ...
                'type',PropertyType('char', 'row', {'left','right'}),...
                'description', 'The eye');
            
            obj.addProperty('eyePart', 'Nasal', ...
                'type',PropertyType('char', 'row', {'Nasal','Temporal', 'Dorsal', 'Ventral'}),...
                'description', 'The section of eye');
            
            obj.addProperty('orientation', 'ventral down', ...
                'type',PropertyType('char', 'row', {'ventral down','ventral up'}),...
                'description', 'eye placement orientation');
            
            obj.addProperty('opticNerve', [0,0],...
                'description', 'eye optic nerve coordinates');

            obj.addProperty('orientationDorsal', [0,0],...
                'description', 'Alignment point above the optic nerve');

            obj.addProperty('orientationVentral', [0,0],...
                'description', 'Alignment point below the optic nerve');
            
            obj.addProperty('orientationSide', [0,0],...
                'description', 'Alignment point along the side of optic nerve');
                       
            obj.addAllowableParentType([]);
        end
        
    end
    
end

