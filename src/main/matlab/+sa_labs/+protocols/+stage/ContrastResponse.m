classdef ContrastResponse < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 250                   % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 1000                 % Spot trailing duration (ms)
        numberOfContrastSteps = 5       % Number of contrast steps (doubled for 'both' directions)
        minContrast = 0.02              % Minimum contrast (0-1)
        maxContrast = 1                 % Maximum contrast (0-1)
        contrastDirection = 'positive'  % Direction of contrast
        shape = 'ellipse'               % The shape of the stimulus (circle or square)
        uniformXY = true                % Should the X and Y size be uniform (eg. circle or ellipse)
        spotDiameter = 200              % Spot diameter (um)
        sizeY = 200                     % Length of Y (um)
        sizeX = 200                     % Length of Y (um)
        numberOfCycles = 2              % Number of cycles through all contrasts
        
    end
    
    properties (Hidden)
        contrastDirectionType = symphonyui.core.PropertyType('char', 'row', {'both', 'positive', 'negative'})
        shapeType = symphonyui.core.PropertyType('char', 'row', {'ellipse', 'rectangle'})
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

        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case 'spotDiameter'
                    if ~obj.uniformXY
                        d.isHidden = true;
                    end
                case 'sizeY'
                    if obj.uniformXY
                        d.isHidden = true;
                    end
                case 'sizeX'
                    if obj.uniformXY
                        d.isHidden = true;
                    end
            end
        end
        
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
            
            
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            if obj.uniformXY
                numXPixels = round(obj.um2pix(obj.spotDiameter));
                numYPixels = numXPixels;
            else
                numXPixels = round(obj.um2pix(obj.sizeX));
                numYPixels = round(obj.um2pix(obj.sizeY));
            end
            
            if strcmp(obj.shape, 'ellipse')
                spot = stage.builtin.stimuli.Ellipse();
                spot.radiusX = numXPixels/2;
                spot.radiusY = numYPixels/2;
                
            elseif strcmp(obj.shape, 'rectangle')
                spot = stage.builtin.stimuli.Rectangle();
                spot.size = [numXPixels,numYPixels];
            else
                error('Did not recognize shape')
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

