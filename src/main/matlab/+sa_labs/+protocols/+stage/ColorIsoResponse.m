classdef ColorIsoResponse < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 250                  % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 500                 % Spot trailing duration (ms)
        
        spotDiameter = 200
        
        baseIntensity1 = .5;
        contrastRange1 = [-1, 1];
        
        baseIntensity2 = .5;
        contrastRange2 = [-1, 1];
        
        enableSurround = false
        surroundDiameter = 1000

    end
    
    properties (Hidden)   
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'sortColors';
        
        colorChangeModeType = symphonyui.core.PropertyType('char', 'row', {'swap','ramp'});
        
        intensity1
        intensity2
        contrast1
        contrast2
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs

    end    
    
    properties (Transient, Hidden)
        isoResponseFigure
    end        
    
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if obj.numberOfPatterns == 1
                error('Must have > 1 pattern enabled to use color stim');
            end
            
            obj.isoResponseFigure = obj.showFigure('sa_labs.figures.ColorIsoResponseFigure', obj.devices, ...
                'analysisRegion', 1e-3 * [obj.preTime, obj.preTime + obj.stimTime + 0.5],...
                'spikeThreshold', obj.spikeThreshold, ...
                'spikeDetectorMode', obj.spikeDetectorMode, ...
                'contrastRange1', obj.contrastRange1, 'contrastRange2', obj.contrastRange2);
            
        end

        function prepareEpoch(obj, epoch)
            
            obj.contrast1 = obj.isoResponseFigure.nextContrast1;
            obj.contrast2 = obj.isoResponseFigure.nextContrast2;
            obj.intensity1 = obj.baseIntensity1 * (1 + obj.contrast1);
            obj.intensity2 = obj.baseIntensity2 * (1 + obj.contrast2);

            epoch.addParameter('intensity1', obj.intensity1);
            epoch.addParameter('intensity2', obj.intensity2);
            epoch.addParameter('contrast1', obj.contrast1);
            epoch.addParameter('contrast2', obj.contrast2);
            epoch.addParameter('sortColors', sum([1000,1] .* round([obj.intensity1, obj.intensity2]*100))); % for plot display
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            function c = surroundColor(state, backgroundColor)
                c = backgroundColor(state.pattern + 1);
            end
            
            if obj.enableSurround
                surround = stage.builtin.stimuli.Ellipse();
                surround.color = 1;
                surround.opacity = 1;
                surround.radiusX = obj.um2pix(obj.surroundDiameter/2);
                surround.radiusY = surround.radiusX;
                surround.position = canvasSize / 2;
                p.addStimulus(surround);
                surroundColorController = stage.builtin.controllers.PropertyController(surround, 'color',...
                    @(s) surroundColor(s, [obj.baseIntensity1, obj.baseIntensity2]));
                p.addController(surroundColorController);
            end
            
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.color = 1;
            spot.opacity = 1;
            spot.radiusX = obj.um2pix(obj.spotDiameter/2);
            spot.radiusY = spot.radiusX;
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            function c = spotColor(state, onColor, backgroundColor)
                if state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3
                    c = onColor(state.pattern + 1);
                else
                    c = backgroundColor(state.pattern + 1);
                end
            end
                    
            spotColorController = stage.builtin.controllers.PropertyController(spot, 'color',...
                @(s) spotColor(s, [obj.intensity1, obj.intensity2], [obj.baseIntensity1, obj.baseIntensity2]));
            p.addController(spotColorController);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = inf;
        end

    end
    
end

