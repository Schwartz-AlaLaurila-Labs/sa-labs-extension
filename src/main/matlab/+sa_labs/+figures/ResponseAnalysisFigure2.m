classdef ResponseAnalysisFigure2 < sa_labs.figures.ResponseAnalysisFigure
    
    
    methods
        
        function obj = ResponseAnalysisFigure2(devices, varargin)
            obj = obj@sa_labs.figures.ResponseAnalysisFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.ResponseAnalysisFigure(obj);
            set(obj.figureHandle, 'Name', 'Amp2');
        end
    end
end


