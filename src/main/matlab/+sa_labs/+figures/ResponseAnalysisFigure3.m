classdef ResponseAnalysisFigure3 < sa_labs.figures.ResponseAnalysisFigure
    
    
    methods
        
        function obj = ResponseAnalysisFigure3(devices, varargin)
            obj = obj@sa_labs.figures.ResponseAnalysisFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.ResponseAnalysisFigure(obj);
            set(obj.figureHandle, 'Name', 'Amp3');
        end
    end
end


