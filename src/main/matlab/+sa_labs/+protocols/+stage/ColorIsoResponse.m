classdef ColorIsoResponse < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500                  % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 1500                 % Spot trailing duration (ms)
        
        spotDiameter = 2000
        
        annulusMode = false;
        annulusInnerDiameter = 300;
        annulusOuterDiameter = 2000;

    end
        
    properties (Hidden)   
        responsePlotMode = false;
        responsePlotSplitParameter = '';

        sessionId
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
        
    end    
    
    properties (Transient, Hidden)
        isoResponseFigure
    end        
    
    
    methods
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case {'contrast1', 'contrast2'}
                    d.isHidden = true;
            end
        end
        
        function didSetRig(obj)
            didSetRig@sa_labs.protocols.StageProtocol(obj);
            
            obj.colorCombinationMode = 'contrast';
        end        
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            obj.sessionId = [regexprep(num2str(fix(clock),'%1d'),' +','') '_']; % this is how you get a datetime string in MATLAB            
            
            if obj.numberOfPatterns == 1
                error('Must have > 1 pattern enabled to use color stim');
            end
            
            obj.isoResponseFigure = obj.showFigure('sa_labs.figures.ColorIsoResponseFigure', obj.devices, ...
                'responseMode', obj.chan1Mode, ...
                'analysisRegion', 1e-3 * [obj.preTime, obj.preTime + obj.stimTime] + [0.005, 0],...
                'spikeThreshold', obj.spikeThreshold, ...
                'spikeDetectorMode', obj.spikeDetectorMode, ...
                'baseIntensity1', obj.meanLevel1, 'baseIntensity2', obj.meanLevel2, ...
                'colorNames', {obj.colorPattern1, obj.colorPattern2});
            
        end

        function prepareEpoch(obj, epoch)
            obj.contrast1 = obj.isoResponseFigure.nextContrast1;
            obj.contrast2 = obj.isoResponseFigure.nextContrast2;
            intensity1 = obj.meanLevel1 * (1 + obj.contrast1);
            intensity2 = obj.meanLevel2 * (1 + obj.contrast2);
            stimulusInfo = obj.isoResponseFigure.nextStimulusInfoOutput;

            epoch.addParameter('sessionId', obj.sessionId);
            epoch.addParameter('intensity1', intensity1);
            epoch.addParameter('intensity2', intensity2);
            epoch.addParameter('contrast1', obj.contrast1);
            epoch.addParameter('contrast2', obj.contrast2);
            keys = stimulusInfo.keys();
            values = stimulusInfo.values();
            for ki = 1:length(keys)
                epoch.addParameter(keys{ki}, values{ki});
            end
%             epoch.addParameter('sortColors', sum([1000,1] .* round([*100))); % for plot display
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            if ~obj.annulusMode
                spotOrAnnulus = stage.builtin.stimuli.Ellipse();
                spotOrAnnulus.color = 1;
                spotOrAnnulus.opacity = 1;
                spotOrAnnulus.radiusX = obj.um2pix(obj.spotDiameter/2);
                spotOrAnnulus.radiusY = spotOrAnnulus.radiusX;
                spotOrAnnulus.position = canvasSize / 2;
                p.addStimulus(spotOrAnnulus);
            else
                spotOrAnnulus = stage.builtin.stimuli.Ellipse();
                spotOrAnnulus.color = 1;
                spotOrAnnulus.opacity = 1;
                spotOrAnnulus.radiusX = obj.um2pix(obj.annulusOuterDiameter/2);
                spotOrAnnulus.radiusY = spotOrAnnulus.radiusX;
                spotOrAnnulus.position = canvasSize / 2;
                p.addStimulus(spotOrAnnulus);
                
                centerMask = stage.builtin.stimuli.Ellipse();
                centerMask.color = 1;
                centerMask.opacity = 1;
                centerMask.radiusX = obj.um2pix(obj.annulusInnerDiameter/2);
                centerMask.radiusY = centerMask.radiusX;
                centerMask.position = canvasSize / 2;
                p.addStimulus(centerMask);
                centerMaskColorController = stage.builtin.controllers.PropertyController(centerMask, 'color',...
                    @(s) surroundColor(s, [obj.meanLevel1, obj.meanLevel2]));
                p.addController(centerMaskColorController);
            end
                
            obj.setOnDuringStimController(p, spotOrAnnulus);
            obj.setColorController(p, spotOrAnnulus);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = inf;
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            if ~isvalid(obj.isoResponseFigure)
                tf = false;
            else
                tf = ~obj.isoResponseFigure.protocolShouldStop;
            end
        end
        
        function tf = shouldContinueRun(obj)
            if ~isvalid(obj.isoResponseFigure)
                tf = false;
            else
                tf = ~obj.isoResponseFigure.protocolShouldStop;
            end
        end
               
    end
    
end

