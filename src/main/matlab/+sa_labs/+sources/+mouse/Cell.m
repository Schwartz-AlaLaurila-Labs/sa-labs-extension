classdef Cell < symphonyui.core.persistent.descriptions.SourceDescription
    
    methods
        
        function obj = Cell()
            import symphonyui.core.*;
            numberOfChannels = sa_labs.factory.getInstance('rigProperty').numberOfChannels;
            
            for i = 1 : numberOfChannels
                propName = @(str) strcat('Amp', num2str(i), str);
                category = propName('');
                obj.addProperty(propName('CellType'), '', ...
                    'description', 'The guessed type of the recorded cell',...
                    'category', category);

                obj.addProperty(propName('ConfirmedCellType'), '', ...
                    'description', 'The confirmed type of the recorded cell',...
                    'category', category);            

                obj.addProperty(propName('Location'),[0,0],...
                    'description', 'coordinates of the cell on the retina',...
                    'category', category);
            end
            obj.addAllowableParentType('sa_labs.sources.Mouse');
        end
        
    end
    
end

