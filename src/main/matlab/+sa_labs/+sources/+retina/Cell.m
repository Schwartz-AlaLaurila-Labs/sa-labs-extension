classdef Cell < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Cell(parent)
            import symphonyui.core.*;
            
            if nargin == 1
                if strcmp(parent.getProperty('DataJoint Identifier'),'0')
                    error('Parent retina needs a valid DataJoint ID!');
                end

                if strcmp(parent.getProperty('eye'),'')
                    error('Parent retina needs a valid eye!');
                end

                if strcmp(parent.getProperty('orientation'),'')
                    error('Parent retina needs a valid orientation!');
                end

                if strcmp(parent.getProperty('recordingBy'),'')
                    error('Parent retina needs a valid experimenter!');
                end
            end
            
            obj.addProperty('number',1,...
                'description', 'The number of the cell (just the number)')
            
            obj.addProperty('type', '', ...
                'description', 'The guessed type of the recorded cell');
            
            obj.addProperty('confirmedType', '', ...
                'description', 'The confirmed type of the recorded cell');            
            
            obj.addProperty('location',[0,0],...
                'description', 'coordinates of the cell on the retina');
            
            obj.addAllowableParentType('sa_labs.sources.Retina');
        end
        
    end
    
end

