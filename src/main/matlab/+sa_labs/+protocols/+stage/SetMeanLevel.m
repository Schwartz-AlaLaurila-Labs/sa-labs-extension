classdef SetMeanLevel < sa_labs.protocols.StageProtocol

    properties
        %times in ms
        preTime = 250	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 500	% Spot trailing duration (ms)
    end
    
    properties (Hidden)
        displayName = 'Set mean level'
        responsePlotMode = false;
    end
    
    methods
      
        function p = createPresentation(obj)
            p = stage.core.Presentation(1.0);

            %set bg
            p.setBackgroundColor(obj.meanLevel);

        end
        
        
        function tf = shouldContinuePreparingEpochs(~)
            tf = false;
        end
        
        function tf = shouldContinueRun(~)
            tf = false;
        end
        
        
    end
    
end