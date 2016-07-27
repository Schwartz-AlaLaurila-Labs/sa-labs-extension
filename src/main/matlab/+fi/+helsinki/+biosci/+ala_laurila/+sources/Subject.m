classdef (Abstract) Subject < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Subject()
            import symphonyui.core.*;
            
            obj.addProperty('id', '', ...
                'description', 'ID of animal/person (lab convention)');
            obj.addProperty('description', '', ...
                'description', 'Description of subject and where subject came from (eg, breeder, if animal)');
            obj.addProperty('sex', '', ...
                'type', PropertyType('char', 'row', {'', 'male', 'female'}), ...
                'description', 'Gender of the subject');
            obj.addProperty('age', '', ...
                'description', 'Age of person, animal, embryo');
            obj.addProperty('weight', '', ...
                'description', 'Weight at time of experiment, at time of surgery, and at other important times');
            obj.addProperty('darkAdaptation', '', ...
                'type', PropertyType('char', 'row', {'', 'overnight', '1 hour', '2 hours'}), ...
                'description', 'Period of time the subject was allowed to adjust to the dark');      
        end
        
    end
    
end

