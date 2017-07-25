classdef ResponseAnalysisFigure4 < sa_labs.figures.ResponseAnalysisFigure
    
    
    methods
        
        function obj = ResponseAnalysisFigure4(devices, varargin)
           obj = obj@sa_labs.figures.ResponseAnalysisFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.ResponseAnalysisFigure(obj);
            set(obj.figureHandle, 'Name', 'Amp4');
        end
    end
end


