classdef SpatialNoiseFigure1 < sa_labs.figures.SpatialNoiseFigure
    
    methods
        
        function obj = SpatialNoiseFigure1(devices, varargin)
            obj = obj@sa_labs.figures.SpatialNoiseFigure(devices, varargin{:});
        end
        
        function createUi(obj)
            createUi@sa_labs.figures.SpatialNoiseFigure(obj);
            set(obj.figureHandle, 'Name', 'Spatial Noise: Amp1');
        end
    end
end