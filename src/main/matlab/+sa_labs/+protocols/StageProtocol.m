classdef (Abstract) StageProtocol < sa_labs.protocols.BaseProtocol
    % This class handles protocol control which is visual stimulus specific
    
    properties
        meanLevel = 0.0         % Background light intensity (0-1)
        backgroundSize          % um
        meanLevel1 = 0.5        % Background intensity value pattern 1
        meanLevel2 = 0.5        % Background intensity value pattern 2
        contrast1 = 1           % Weber contrast from mean for object, color 1
        contrast2 = 1           % Weber contrast from mean for object, color 2
        offsetX = 0             % um
        offsetY = 0             % um
        NDF = 5                 % Filter NDF value
        blueLED = 20            % 0-255
        greenLED = 0            % 0-255
        redLED = 0              % 0-255
        uvLED = 0               % 0-255
        colorPattern1 = 'blue'; 
        colorPattern2 = 'none';
        colorPattern3 = 'none';
        primaryObjectPattern = 1
        secondaryObjectPattern = 1
        backgroundPattern = 2
        colorCombinationMode = 'contrast'
    end
    
    properties (Dependent)
        numberOfPatterns = 1
        RstarMean
        RstarIntensity1
        MstarIntensity1
        SstarIntensity1
        RstarIntensity2
        MstarIntensity2
        SstarIntensity2
        bitDepth = 8
        prerender = false
        frameRate = 60; % changing this isn't implemented
    end
    
    properties % again, for ordering
        forcePrerender = 'auto'; % enable to force prerender mode to reduce frame dropping
    end
    
    properties (Hidden)
        colorPattern1Type = symphonyui.core.PropertyType('char', 'row', {'green', 'blue', 'uv', 'blue+green', 'green+uv', 'blue+uv', 'blue+uv+green','red'});
        colorPattern2Type = symphonyui.core.PropertyType('char', 'row', {'none','green', 'blue', 'uv', 'blue+green', 'green+uv', 'blue+uv', 'blue+uv+green','red'});
        colorPattern3Type = symphonyui.core.PropertyType('char', 'row', {'none','green', 'blue', 'uv', 'blue+green', 'green+uv', 'blue+uv', 'blue+uv+green','red'});
        colorCombinationModeType = symphonyui.core.PropertyType('char', 'row', {'add','replace','contrast'});
        forcePrerenderType = symphonyui.core.PropertyType('char', 'row', {'auto','prerender on','prerender off'});
        colorMode = '';
    end

    properties (Hidden, Transient)
        rigProperty
    end 
    
    methods (Abstract)
        p = createPresentation(obj);
    end
    
    methods
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.BaseProtocol(obj, name);

            switch name
                case {'meanLevel', 'intensity'}
                    d.isHidden = obj.numberOfPatterns > 1 && strcmp(obj.colorCombinationMode, 'contrast');
                    
                case {'offsetX','offsetY','NDF','blueLED','greenLED', 'backgroundSize'}
                    d.category = '7 Projector';
                    
                case 'redLED'
                    d.category = '7 Projector';
                    d.isHidden = strcmp(obj.colorMode, 'uv');
                    
                case 'uvLED'
                    d.category = '7 Projector';
                    d.isHidden = strcmp(obj.colorMode, 'standard');
                    
                case {'numberOfPatterns','frameRate','bitDepth',...
                        'colorPattern1','colorPattern2','colorPattern3',...
                        'prerender','forcePrerender'}
                    d.category = '8 Color';
                    
                case {'meanLevel1','meanLevel2','contrast1','contrast2'}
                    d.isHidden = obj.numberOfPatterns == 1 || ~strcmp(obj.colorCombinationMode, 'contrast');
                    
                case {'colorCombinationMode'}
                    d.isHidden = obj.numberOfPatterns == 1;
                    d.category = '8 Color';
                    
                case {'primaryObjectPattern','secondaryObjectPattern','backgroundPattern'}
                    d.isHidden = obj.numberOfPatterns == 1 || logical(strcmp(obj.colorCombinationMode, 'contrast'));
                    d.category = '8 Color';
                    
                case {'RstarIntensity2','MstarIntensity2','SstarIntensity2'}
                    d.category = '6 Isomerizations';
                    d.isHidden = obj.numberOfPatterns == 1;
                    
                case {'RstarMean','RstarIntensity1','MstarIntensity1','SstarIntensity1'}
                    d.category = '6 Isomerizations';
            end
            
            if obj.rigProperty.rigDescription.toBeHidden(name)
                d.isHidden = true;
            end
        end
        
        function didSetRig(obj)
            didSetRig@sa_labs.protocols.BaseProtocol(obj);
            
            if ~isempty(obj.rig.getDevices('LightCrafter'))
                lcr = obj.rig.getDevice('LightCrafter');
                obj.backgroundSize = lcr.getBackgroundSizeInMicrons();
                obj.colorMode = lcr.getColorMode();
            end
            
            if strcmp(obj.colorMode, 'uv')
                obj.blueLED = 0;
                obj.greenLED = 10;
                obj.redLED = 0;
                obj.uvLED = 50;
                obj.colorPattern1 = 'green';
            elseif strcmp(obj.colorMode, 'standard')
                obj.blueLED = 20;
                obj.greenLED = 0;
                obj.redLED = 0;
                obj.uvLED = 0;
                obj.colorPattern1 = 'blue';
            end
            
            if ~ isempty(obj.rig.getDevices('neutralDensityFilterWheel'))
                obj.NDF = obj.rig.getDevice('neutralDensityFilterWheel').getResource('defaultNdfValue');
            end
            obj.rigProperty = sa_labs.factory.getInstance('rigProperty');
        end
        
        function p = getPreview(obj, panel)
            if isempty(obj.rig.getDevices('Stage'))
                p = [];
                return;
            end
            p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
                'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
        end
        
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@sa_labs.protocols.BaseProtocol(obj);
            obj.rig.getDevice('Stage').play(obj.createPresentation());
        end
        
        function prepareRun(obj, setAmpHoldSignals)
            
            if nargin < 2
                setAmpHoldSignals = true;
            end
            prepareRun@sa_labs.protocols.BaseProtocol(obj, setAmpHoldSignals);
            
            % obj.showFigure('sa_labs.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));
            
            % set the NDF filter wheel
            if ~ isempty(obj.rig.getDevices('neutralDensityFilterWheel'))
                ndfs = obj.rig.getDevices('neutralDensityFilterWheel');
                ndfs{1}.setNdfValue(obj.NDF);
                DaqLogger.log('Set the NDF position to ', num2str(obj.NDF));
            end
            
            if ~isempty(obj.rig.getDevices('LightCrafter'))
                obj.prepareProjector();
            end
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            % uses the frame tracker on the monitor to inform the HEKA that
            % the stage presentation has begun. Improves temporal alignment
            epoch.shouldWaitForTrigger = true;
            
            testMode = obj.rig.getDevice('rigProperty').getConfigurationSetting('testMode');
            if testMode
                % gaussian noise for analysis testing
                sa_labs.daq.log('Running the rig in test mode ');
                obj.addGaussianLoopbackSignals(epoch);
            else
                % it is required to have an amp stimulus for stage protocols
                device = obj.rig.getDevice(obj.chan1);
                duration = (obj.preTime + obj.stimTime + obj.tailTime) / 1e3;
                epoch.addDirectCurrentStimulus(device, device.background, duration, obj.sampleRate);
            end
            
        end
        
        function tf = shouldContinuePreloadingEpochs(obj) %#ok<MANU>
            tf = false;
        end
        
        function tf = shouldWaitToContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared > obj.numEpochsCompleted || obj.numIntervalsPrepared > obj.numIntervalsCompleted;
        end
        
        function completeEpoch(obj, epoch)
           
            testMode = obj.rig.getDevice('rigProperty').getConfigurationSetting('testMode');
            if ~ testMode
                epoch.removeStimulus(obj.rig.getDevice(obj.chan1));
            end
            completeEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
        end
        
        function completeRun(obj)
            completeRun@sa_labs.protocols.BaseProtocol(obj);
            obj.rig.getDevice('Stage').clearMemory();
         end
        
        function [tf, msg] = isValid(obj)
            [tf, msg] = isValid@sa_labs.protocols.BaseProtocol(obj);
            if tf
                tf = ~isempty(obj.rig.getDevices('Stage'));
                msg = 'No stage';
            end
        end
        
        % shared controller setup code for multi-pattern objects
        function setColorController(obj, p, stageObject)
            
            function c = patternSelect(state, activePatternNumber)
                c = 1 * (state.pattern == activePatternNumber - 1);
            end
            
            if obj.numberOfPatterns > 1
                % replace mode uses the intensity value and
                % puts the object on a separate pattern, with 0 on the background pattern
                if strcmp(obj.colorCombinationMode, 'replace')
                    pattern = obj.primaryObjectPattern;
                    patternController = stage.builtin.controllers.PropertyController(stageObject, 'color', ...
                        @(s)(obj.intensity * patternSelect(s, pattern)));
                    p.addController(patternController);
                    
                    % add mode uses the intensity value on one pattern,
                    % but keeps the object on at the meanLevel at the other pattern
                elseif strcmp(obj.colorCombinationMode, 'add')
                    pattern = obj.primaryObjectPattern;
                    bgPattern = obj.backgroundPattern;
                    patternController = stage.builtin.controllers.PropertyController(stageObject, 'color', ...
                        @(s)(obj.intensity * patternSelect(s, pattern) + obj.meanLevel * patternSelect(s, bgPattern)));
                    p.addController(patternController);
                else
                    % two-color contrast mode has separate intensity values as weber contrast of the mean
                    intensity1 = obj.meanLevel1 * (1 + obj.contrast1);
                    intensity2 = obj.meanLevel2 * (1 + obj.contrast2);
                    patternController = stage.builtin.controllers.PropertyController(stageObject, 'color', ...
                        @(s)(intensity1 * patternSelect(s, 1) + intensity2 * patternSelect(s, 2)));
                    p.addController(patternController);
                end
            else
                stageObject.color = obj.intensity; % wasn't life simpler back then?
            end
        end
        
        function setOnDuringStimController(obj, p, stageObject)
            function c = onDuringStim(state, preTime, stimTime)
                c = 1 * (state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3);
            end
            
            controller = stage.builtin.controllers.PropertyController(stageObject, 'opacity', ...
                @(s)onDuringStim(s, obj.preTime, obj.stimTime));
            p.addController(controller);
        end
        
        function RstarMean = get.RstarMean(obj)
            pattern = 1;
            if obj.numberOfPatterns == 1
                [RstarMean, ~, ~] = obj.invokeGetIsomerizations(pattern);
            else
                [RstarMean, ~, ~] = obj.invokeGetIsomerizations(obj.backgroundPattern);
            end
        end
        
        function RstarIntensity = get.RstarIntensity1(obj)
            pattern = 1;
            [RstarIntensity, ~, ~] = obj.invokeGetIsomerizations(pattern);
        end
        
        function MstarIntensity = get.MstarIntensity1(obj)
            pattern = 1;
            [~, MstarIntensity, ~] = obj.invokeGetIsomerizations(pattern);
        end
        
        function SstarIntensity = get.SstarIntensity1(obj)
            pattern = 1;
            [~, ~, SstarIntensity] = obj.invokeGetIsomerizations(pattern);
        end
        
        function RstarIntensity = get.RstarIntensity2(obj)
            pattern = 2;
            [RstarIntensity, ~, ~] = obj.invokeGetIsomerizations(pattern);
        end
        
        function MstarIntensity = get.MstarIntensity2(obj)
            pattern = 2;
            [~, MstarIntensity, ~] = obj.invokeGetIsomerizations(pattern);
        end
        
        function SstarIntensity = get.SstarIntensity2(obj)
            pattern = 2;
            [~, ~, SstarIntensity] = obj.invokeGetIsomerizations(pattern);
        end
        
        function [rStar, mStar, sStar] = invokeGetIsomerizations(obj, pattern)
            [rStar, mStar, sStar] = obj.rigProperty.rigDescription.getIsomerizations(obj, pattern);
        end
        
        function bitDepth = get.bitDepth(obj)
            if obj.numberOfPatterns == 1
                bitDepth = 8;
            else
                bitDepth = 6;
            end
        end
        
        function frameRate = get.frameRate(obj)
            frameRate = 60; % changing this isn't implemented
        end
        
        function prerender = get.prerender(obj)
            prerender = false;
            
            if strcmp(obj.forcePrerender, 'auto') && obj.numberOfPatterns ~= 1
                prerender = true;
            elseif strcmp(obj.forcePrerender, 'pr on')
                prerender = true;
            end
        end
        
        function numberOfPatterns = get.numberOfPatterns(obj)
            if ~ strcmp(obj.colorPattern3, 'none')
                numberOfPatterns = 3;
            elseif ~ strcmp(obj.colorPattern2, 'none')
                numberOfPatterns = 2;
            else
                numberOfPatterns = 1;
            end
        end
    end
    
    methods (Access = protected)
        
        function [pround, p] = um2pix(obj, um)
            stage = obj.rig.getDevice('Stage');
            micronsPerPixel = stage.getConfigurationSetting('micronsPerPixel');
            p = um / micronsPerPixel;
            pround = round(p);
        end
        
        function prepareProjector(obj)
            % Set the projector configuration
            lightCrafter = obj.rig.getDevice('LightCrafter');
            if obj.numberOfPatterns > 1
                if strcmp(obj.colorCombinationMode, 'contrast')
                    lightCrafter.setBackgroundConfiguration('twoPattern', obj.meanLevel1, obj.meanLevel2);
                else
                    lightCrafter.setBackgroundConfiguration('singlePattern', obj.meanLevel, obj.backgroundPattern);
                end
            else
                lightCrafter.setBackgroundConfiguration('noPattern', obj.meanLevel);
            end
            lightCrafter.setPrerender(obj.prerender);
            lightCrafter.setPatternAttributes(obj.bitDepth, {obj.colorPattern1,obj.colorPattern2,obj.colorPattern3}, obj.numberOfPatterns);
            lightCrafter.setLedCurrents(obj.redLED, obj.greenLED, obj.blueLED, obj.uvLED);
            lightCrafter.setLedEnables(true, 0, 0, 0, 0); % auto mode, should be set from pattern
            lightCrafter.setCanvasTranslation(round([obj.um2pix(obj.offsetX), obj.um2pix(obj.offsetY)]));
            lightCrafter.setConfigurationSetting('backgroundSize', obj.backgroundSize);
            pause(0.2); % let the projector get set up
        end
    end
    
end

