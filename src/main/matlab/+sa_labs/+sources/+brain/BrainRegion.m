classdef BrainRegion < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = BrainRegion(parent)
            import symphonyui.core.*;
            
            if nargin == 1
                if strcmp(parent.getProperty('DataJoint Identifier'),'0')
                    error('Parent brain needs a valid DataJoint ID!');
                end

                if strcmp(parent.getProperty('recordingBy'),'')
                    error('Parent brain needs a valid experimenter!');
                end
            end
                        
            obj.addProperty('region_name', '', ...
                'description', 'A plain text (for now) brain region name');
            
            obj.addAllowableParentType('sa_labs.sources.Brain');
        end
        
    end
    
end