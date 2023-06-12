classdef SpotsMultiLocationFigure2 < sa_labs.figures.SpotsMultiLocationFigure
    
    methods
        
        function obj = SpotsMultiLocationFigure2(devices, varargin)
            obj = obj@sa_labs.figures.SpotsMultiLocationFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.SpotsMultiLocationFigure(obj);
            set(obj.figureHandle, 'Name', 'Spots Multi Location: Amp2');
        end
    end
end