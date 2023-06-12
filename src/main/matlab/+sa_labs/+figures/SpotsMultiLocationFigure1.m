classdef SpotsMultiLocationFigure1 < sa_labs.figures.SpotsMultiLocationFigure
    
    methods
        
        function obj = SpotsMultiLocationFigure1(devices, varargin)
            obj = obj@sa_labs.figures.SpotsMultiLocationFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.SpotsMultiLocationFigure(obj);
            set(obj.figureHandle, 'Name', 'Spots Multi Location: Amp1');
        end
    end
end