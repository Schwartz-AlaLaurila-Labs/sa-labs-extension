classdef ContrastResponse < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 250                  % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 1000                 % Spot trailing duration (ms)
        numberOfContrastSteps = 5       % Number of contrast steps (doubled for 'both' directions)
        minContrast = 0.02              % Minimum contrast (0-1)
        maxContrast = 1                 % Maximum contrast (0-1)
        contrastDirection = 'positive'  % Direction of contrast
        shape = 'circle'
        sizeY = 800
        spotDiameter = 200              % Spot diameter (um)
        numberOfCycles = 2               % Number of cycles through all contrasts
        
    end
    
    properties (Hidden)
        contrastDirectionType = symphonyui.core.PropertyType('char', 'row', {'both', 'positive', 'negative'})
        shapeType = symphonyui.core.PropertyType('char', 'row', {'circle', 'square'})
        contrastValues                  % Linspace range between min and max contrast for given contrast steps
        intensityValues                 % Spot meanLevel * (1 + contrast Values)
        contrast                        % Spot contrast value for current epoch @see prepareEpoch
        intensity                       % Spot intensity value for current epoch @see prepareEpoch
    
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'contrast';
    end
    
    properties (Dependent)
        realNumberOfContrastSteps       % compensate for "both" directions having double steps
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
%         function set.realNumberOfContrastSteps(obj,k)
%             obj.realNumberOfContrastSteps = k;
%         end        
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if obj.meanLevel == 0
                warning('Contrast calculation is undefined when mean level is zero');
            end
            
            contrasts = 2.^linspace(log2(obj.minContrast), log2(obj.maxContrast), obj.numberOfContrastSteps);
            
            if strcmp(obj.contrastDirection, 'positive')
                obj.contrastValues = contrasts;
            elseif strcmp(obj.contrastDirection, 'negative')
                obj.contrastValues = -1 * contrasts;
            else % both
                obj.contrastValues = [fliplr(-1 * contrasts), contrasts];
            end
            obj.intensityValues = obj.meanLevel + (obj.contrastValues .* obj.meanLevel);
%             obj.realNumberOfContrastSteps = length(obj.intensityValues);
            
        end

        function prepareEpoch(obj, epoch)

            index = mod(obj.numEpochsPrepared, obj.realNumberOfContrastSteps);
            if index == 0
                reorder = randperm(obj.realNumberOfContrastSteps);
                obj.contrastValues = obj.contrastValues(reorder);
                obj.intensityValues = obj.intensityValues(reorder);
            end
            
            obj.contrast = obj.contrastValues(index + 1);
            obj.intensity = obj.intensityValues(index + 1);
            epoch.addParameter('contrast', obj.contrast);
            epoch.addParameter('intensity', obj.intensity);
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            spotDiameterPix = obj.um2pix(obj.spotDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            if strcmp(obj.shape, 'circle')
                spot = stage.builtin.stimuli.Ellipse();
                spot.radiusX = spotDiameterPix/2;
                spot.radiusY = spotDiameterPix/2;
                
            elseif strcmp(obj.shape, 'square')
                spot = stage.builtin.stimuli.Rectangle();
                side = round(obj.um2pix(obj.spotDiameter));
                Y = round(obj.um2pix(obj.sizeY));
                spot.size = [side,Y];
            end

            spot.color = obj.intensity;
            
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            spotVisible = stage.builtin.controllers.PropertyController(spot, 'opacity', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(spotVisible);
            
%             obj.addFrameTracker(p);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.realNumberOfContrastSteps * obj.numberOfCycles;
        end

        
        function r = get.realNumberOfContrastSteps(obj)
            if strcmp(obj.contrastDirection, 'both')
                r = obj.numberOfContrastSteps * 2;
            else % both
                r = obj.numberOfContrastSteps;
            end
        end        
        
    end
    
end

