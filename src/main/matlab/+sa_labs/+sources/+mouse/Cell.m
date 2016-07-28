classdef Cell < sa_labs.sources.Cell
    
    methods
        
        function obj = Cell()
            import symphonyui.core.*;
            
            obj.addProperty('type', 'unknown', ...
                'type', PropertyType('char', 'row', containers.Map( ...
                    {'unknown', 'RGC', 'amacrine', 'bipolar', 'horizontal', 'photoreceptor'}, ...
                    {{}, ...
                    {'ON-alpha', 'ON-transient', 'OFF-transient', 'OFF-sustained', 'ON/OFF DS', 'ON DS', 'W3/local edge detector'}, ...
                    {'AII', 'A17', 'starburst', 'AC5170'}, ...
                    {'rod bipolar', 'cone bipolar'}, ...
                    {}, ...
                    {'S cone', 'M cone', 'rod'}})), ...
                'description', 'The confirmed type of the recorded cell');
            
            obj.addAllowableParentType('fi.helsinki.biosci.ala_laurila.sources.mouse.Preparation');
        end
        
    end
    
end

