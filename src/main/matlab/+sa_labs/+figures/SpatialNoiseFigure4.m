classdef SpatialNoiseFigure4 < sa_labs.figures.SpatialNoiseFigure
    
    methods
        
        function obj = SpatialNoiseFigure4(devices, varargin)
            obj = obj@sa_labs.figures.SpatialNoiseFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.SpatialNoiseFigure(obj);
            set(obj.figureHandle, 'Name', 'Spatial Noise: Amp4');
        end
    end
end