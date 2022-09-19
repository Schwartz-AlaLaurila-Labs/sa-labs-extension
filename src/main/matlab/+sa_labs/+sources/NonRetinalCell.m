classdef NonRetinalCell < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = NonRetinalCell()
            import symphonyui.core.*;
            
            users = sln_lab.ActiveUser().fetchn('user_name');
            
            obj.addProperty('recordingBy', '', ...
                'description', 'name of person recording',...
                'type',PropertyType('char','row',[{''};users]));   
            
            obj.addProperty('number',uint8(0),'type',PropertyType('uint8','scalar'),...
                'description', 'The number of the cell (just the number)')
            
            obj.addProperty('type', '', ...
                'description', 'The guessed type of the recorded cell');            
            
            obj.addProperty('notes', '', ...
                'description', 'Additional information about this cell other than type');  
            
            obj.addAllowableParentType([]);
        end
        
    end
    
end

