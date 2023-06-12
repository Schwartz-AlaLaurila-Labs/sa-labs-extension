classdef SpotsMultiLocationFigure4 < sa_labs.figures.SpotsMultiLocationFigure
    
    methods
        
        function obj = SpotsMultiLocationFigure4(devices, varargin)
            obj = obj@sa_labs.figures.SpotsMultiLocationFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.SpotsMultiLocationFigure(obj);
            set(obj.figureHandle, 'Name', 'Spots Multi Location: Amp4');
        end
    end
end