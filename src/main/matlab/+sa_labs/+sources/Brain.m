classdef Brain < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Brain()
            import symphonyui.core.*;
            
            users = sln_lab.ActiveUser().fetchn('user_name');
            % mice = fetchn(sl.AnimalEventDeceased() & sprintf('date=%s',datestr(datetime,'YYYYmmDD')),'animal_id');
            mice = fetchn((sln_animal.AnimalEvent * sln_animal.Deceased) & sprintf('date=%s',datestr(datetime,'YYYYmmDD')),'animal_id');
            
%             obj.addProperty('genotype', 'WT',...
%                 'type', PropertyType('char', 'row'));
            
            obj.addProperty('DataJoint Identifier','0',...
                'type',PropertyType('char','row', ['0';arrayfun(@num2str, mice,'uni',0)]),...
                'description', 'The datajoint ID of this mouse');
            
            obj.addProperty('slice_thickness',uint8(0),'type',PropertyType('uint8','scalar'),...
                'description', 'The thickness of the slices for this brain')

            obj.addProperty('recordingBy', '', ...
                'description', 'name of person recording',...
                'type',PropertyType('char','row',[{''};users]));            
            
            obj.addAllowableParentType([]);
        end
        
    end
    
end
