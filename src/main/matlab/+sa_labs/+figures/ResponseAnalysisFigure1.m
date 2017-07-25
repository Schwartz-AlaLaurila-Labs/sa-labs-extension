classdef ResponseAnalysisFigure1 < sa_labs.figures.ResponseAnalysisFigure
    
    
    methods
        
        function obj = ResponseAnalysisFigure1(devices, varargin)
            obj = obj@sa_labs.figures.ResponseAnalysisFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.ResponseAnalysisFigure(obj);
            set(obj.figureHandle, 'Name', 'Amp1');
        end
    end
end


