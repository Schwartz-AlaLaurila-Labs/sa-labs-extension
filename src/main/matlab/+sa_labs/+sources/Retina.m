classdef Retina < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Retina()
            import symphonyui.core.*;
            
            users = sl.User().fetchn('user_name');
            mice = fetchn(sl.AnimalEventDeceased() & sprintf('date=%s',datestr(datetime,'YYYYmmDD')),'animal_id');
            
%             obj.addProperty('genotype', 'WT',...
%                 'type', PropertyType('char', 'row'));
            
            obj.addProperty('DataJoint Identifier','0',...
                'type',PropertyType('char','row', ['0';arrayfun(@num2str, mice,'uni',0)]),...
                'description', 'The datajoint ID of this mouse');

            obj.addProperty('eye', '', ...
                'type',PropertyType('char', 'row', {'','left','right','unknown'}),...
                'description', 'The eye');
            
            obj.addProperty('orientation', '', ...
                'type',PropertyType('char', 'row', {'','ventral down','ventral up','unknown'}),...
                'description', 'eye placement orientation');
            
            obj.addProperty('recordingBy', '', ...
                'description', 'name of person recording',...
                'type',PropertyType('char','row',[{''};users]));            
            
            obj.addAllowableParentType([]);
        end
        
    end
    
end

