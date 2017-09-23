classdef ShapeResponseFigure2 < sa_labs.figures.ShapeResponseFigure
    
    methods
        
        function obj = ShapeResponseFigure2(devices, varargin)
            obj = obj@sa_labs.figures.ShapeResponseFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.ShapeResponseFigure(obj);
            set(obj.figureHandle, 'Name', 'Shape Response Amp2');
        end
    end
end