classdef (Abstract) StageProtocol < sa_labs.protocols.BaseProtocol
% this class handles protocol control which is visual stimulus specific

    properties
        meanLevel = 0.0     % Background light intensity (0-1)
        offsetX = 0         % um
        offsetY = 0         % um
        
        NDF = 5             % Filter NDF value
        blueLED = 20        % 0-255
        greenLED = 0   % 0-255
        redLED = 0   % 0-255 
        uvLED = 0
        colorPattern1 = 'blue';
        colorPattern2 = 'none';
        colorPattern3 = 'none';
        primaryObjectPattern = 1
        secondaryObjectPattern = 1
        backgroundPattern = 2
        colorCombinationMode = 'add'
        forcePrerender = false; % enable to force prerender mode to reduce frame dropping
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
    
    properties (Hidden)
        colorPattern1Type = symphonyui.core.PropertyType('char', 'row', {'green', 'blue', 'uv', 'blue+green', 'green+uv', 'blue+uv', 'blue+uv+green','red'});
        colorPattern2Type = symphonyui.core.PropertyType('char', 'row', {'none','green', 'blue', 'uv', 'blue+green', 'green+uv', 'blue+uv', 'blue+uv+green','red'});
        colorPattern3Type = symphonyui.core.PropertyType('char', 'row', {'none','green', 'blue', 'uv', 'blue+green', 'green+uv', 'blue+uv', 'blue+uv+green','red'});
        colorCombinationModeType = symphonyui.core.PropertyType('char', 'row', {'add','replace'});

        colorMode = '';
        filterWheelNdfValues
        filterWheelAttenuationValues
        lightCrafterParams
    end
       
    methods (Abstract)
        p = createPresentation(obj);
    end
    
    methods
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.BaseProtocol(obj, name);
            
            switch name
%                 case {'meanLevel', 'intensity'}
%                     d.category = '1 Basic';
                    
                case {'offsetX','offsetY','NDF','blueLED','greenLED'}
                    d.category = '7 Projector';
                                        
                case 'redLED'
                    d.category = '7 Projector';
                    if strcmp(obj.colorMode, 'uv')
                        d.isHidden = true;
                    end
                    
                case 'uvLED'
                    d.category = '7 Projector';
                    if strcmp(obj.colorMode, 'standard')
                        d.isHidden = true;
                    end
                    
                case {'numberOfPatterns','frameRate','bitDepth',...
                        'colorPattern1','colorPattern2','colorPattern3',...
                        'prerender','forcePrerender'}
                    d.category = '8 Color';
                
                case {'colorCombinationMode','primaryObjectPattern','secondaryObjectPattern','backgroundPattern'}
                    if obj.numberOfPatterns == 1
                        d.isHidden = true;
                    end
                    d.category = '8 Color';
                    
                case {'RstarIntensity2','MstarIntensity2','SstarIntensity2'}
                    d.category = '6 Isomerizations';
                    if obj.numberOfPatterns == 1
                        d.isHidden = true;
                    end
                    
                case {'RstarMean','RstarIntensity1','MstarIntensity1','SstarIntensity1'}
                    d.category = '6 Isomerizations';
            end
            
        end
        
        function didSetRig(obj)
            didSetRig@sa_labs.protocols.BaseProtocol(obj);

            lcrSearch = obj.rig.getDevices('LightCrafter');
            if ~isempty(lcrSearch)
                lightCrafter = obj.rig.getDevice('LightCrafter');
                obj.lightCrafterParams = struct();
                obj.lightCrafterParams.fitBlue = lightCrafter.getResource('fitBlue');
                obj.lightCrafterParams.fitGreen = lightCrafter.getResource('fitGreen');
                obj.lightCrafterParams.fitUV = lightCrafter.getResource('fitUV');
                obj.lightCrafterParams.micronsPerPixel = lightCrafter.getConfigurationSetting('micronsPerPixel');
                obj.lightCrafterParams.angleOffset = lightCrafter.getConfigurationSetting('angleOffset');
                obj.colorMode = lightCrafter.getColorMode();
            else
                obj.colorMode = '';
                obj.lightCrafterParams = [];
            end
            
            if strcmp(obj.colorMode, 'uv')
                obj.blueLED = 0;
                obj.greenLED = 20;
                obj.redLED = 0;
                obj.uvLED = 30;
                obj.colorPattern1 = 'green';
            elseif strcmp(obj.colorMode, 'standard')
                obj.blueLED = 20;
                obj.greenLED = 0;
                obj.redLED = 0;
                obj.uvLED = 0;
                obj.colorPattern1 = 'blue';
            end
            
            if isempty(obj.rig.getDevices('neutralDensityFilterWheel'))
                % useless defaults
                obj.filterWheelNdfValues = [0];
                obj.filterWheelAttenuationValues = [1.0];
            else
                filterWheel = obj.rig.getDevice('neutralDensityFilterWheel');
                obj.filterWheelNdfValues = filterWheel.getConfigurationSetting('filterWheelNdfValues');
                obj.filterWheelAttenuationValues = filterWheel.getResource('filterWheelAttenuationValues');
                obj.NDF = filterWheel.getResource('defaultNdfValue');
            end
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
        
        function prepareRun(obj)
            
            obj.showFigure('sa_labs.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));

            % set the NDF filter wheel
            if ~isempty(obj.rig.getDevices('neutralDensityFilterWheel'))
                filterWheel = obj.rig.getDevice('neutralDensityFilterWheel');
                if filterWheel.getConfigurationSetting('comPort') > 0
                    filterWheel.setNdfValue(obj.NDF);
                end
            end
            
            % check for pattern setting correctness
            if obj.numberOfPatterns >= 2
                if ~obj.prerender
                    error('Must have prerender enabled to use multiple patterns')
                end
            end
            
            if ~isempty(obj.rig.getDevices('LightCrafter'))
                % Set the projector configuration
                lightCrafter = obj.rig.getDevice('LightCrafter');
                lightCrafter.setBackground(obj.meanLevel, obj.backgroundPattern);
                lightCrafter.setPrerender(obj.prerender);
                lightCrafter.setPatternAttributes(obj.bitDepth, {obj.colorPattern1,obj.colorPattern2,obj.colorPattern3}, obj.numberOfPatterns);
                lightCrafter.setLedCurrents(obj.redLED, obj.greenLED, obj.blueLED, obj.uvLED);
                lightCrafter.setLedEnables(true, 0, 0, 0, 0); % auto mode, should be set from pattern
                lightCrafter.setCanvasTranslation(round([obj.um2pix(obj.offsetX), obj.um2pix(obj.offsetY)]));
                pause(0.2); % let the projector get set up
            end
            prepareRun@sa_labs.protocols.BaseProtocol(obj);
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            % add the microns per pixel value for later upkeep
            epoch.addParameter('micronsPerPixel', obj.lightCrafterParams.micronsPerPixel);
            epoch.addParameter('angleOffsetFromRig', obj.lightCrafterParams.angleOffset);
            
            % uses the frame tracker on the monitor to inform the HEKA that
            % the stage presentation has begun. Improves temporal alignment
            epoch.shouldWaitForTrigger = true;
            
            testMode = obj.rig.getDevice('rigProperty').getConfigurationSetting('testMode');
            if testMode
                % gaussian noise for analysis testing
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
            if ~testMode
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
    
        
        function RstarMean = get.RstarMean(obj)
            props = {'meanLevel'};
            pattern = 1;
            if obj.numberOfPatterns == 1
                [RstarMean, ~, ~] = obj.getIsomerizations(props, pattern);
            else
                [RstarMean, ~, ~] = obj.getIsomerizations(props, obj.backgroundPattern);
            end
        end
    
        function RstarIntensity = get.RstarIntensity1(obj)
            props = {'intensity','baseIntensity1','intensity1'};
            pattern = 1;
            [RstarIntensity, ~, ~] = obj.getIsomerizations(props, pattern);
        end
        
        function MstarIntensity = get.MstarIntensity1(obj)
            props = {'intensity','baseIntensity1','intensity1'};
            pattern = 1;
            [~, MstarIntensity, ~] = obj.getIsomerizations(props, pattern);
        end
        
        function SstarIntensity = get.SstarIntensity1(obj)
            props = {'intensity','baseIntensity1','intensity1'};
            pattern = 1;
            [~, ~, SstarIntensity] = obj.getIsomerizations(props, pattern);
        end
        
        function RstarIntensity = get.RstarIntensity2(obj)
            props = {'baseIntensity2','intensity2','meanLevel'};
            pattern = 2;
            [RstarIntensity, ~, ~] = obj.getIsomerizations(props, pattern);
        end
        
        function MstarIntensity = get.MstarIntensity2(obj)
            props = {'baseIntensity2','intensity2','meanLevel'};
            pattern = 2;
            [~, MstarIntensity, ~] = obj.getIsomerizations(props, pattern);
        end
        
        function SstarIntensity = get.SstarIntensity2(obj)
            props = {'baseIntensity2','intensity2','meanLevel'};
            pattern = 2;
            [~, ~, SstarIntensity] = obj.getIsomerizations(props, pattern);
        end
        
            
        function [RstarIntensity, MstarIntensity, SstarIntensity] = getIsomerizations(obj, props, pattern)
            intensityToConvert = [];
            for i = 1:length(props)
                if isprop(obj, props{i})
                    intensityToConvert = obj.(props{i});
                    break;
                end
            end
            if ~isempty(intensityToConvert)
                patternColors = {obj.colorPattern1, obj.colorPattern2, obj.colorPattern3};
                [RstarIntensity, MstarIntensity, SstarIntensity] = obj.convertIntensityToIsomerizations(intensityToConvert, patternColors{pattern}, obj.isomerizationParameters());
            else
                RstarIntensity = [];
                MstarIntensity = [];
                SstarIntensity = [];
            end
        end

        function p = isomerizationParameters(obj)
%             source = [];
%             
%             if ~isempty(obj.persistor)
%                 source = obj.persistor.currentEpochGroup.source.getPropertyMap();
%             end
            p = struct();
            p.NDF = obj.NDF;
            p.blueLED = obj.blueLED;
            p.greenLED = obj.greenLED;
            p.uvLED = obj.uvLED;
            p.redLED = obj.redLED;
%             p.colorPattern1 = obj.colorPattern1;
%             p.colorPattern2 = obj.colorPattern2;
%             p.colorPattern3 = obj.colorPattern3;
            p.numberOfPatterns = obj.numberOfPatterns;
            
%             p.ledTypes = sort(strsplit(obj.colorPattern1, '+'));
%             p.mouse = source;
        end
        
        function [rstar, mstar, sstar] = convertIntensityToIsomerizations(obj, intensity, color, parameters)
            rstar = [];
            mstar = [];
            sstar = [];
            if isempty(intensity) || isempty(obj.lightCrafterParams)
                return
            end
            
            NDF_attenuation = obj.filterWheelAttenuationValues(obj.filterWheelNdfValues == parameters.NDF);
            
            if strcmp('standard', obj.colorMode)
                [R, M, S] = sa_labs.util.photoIsom2(parameters.blueLED, parameters.greenLED, ...
                    color, obj.lightCrafterParams.fitBlue, obj.lightCrafterParams.fitGreen);
            else
                % UV mode
                [R, M, S] = sa_labs.util.photoIsom2_triColor(parameters.blueLED, parameters.greenLED, parameters.uvLED, ...
                    color, obj.lightCrafterParams.fitBlue, obj.lightCrafterParams.fitGreen, obj.lightCrafterParams.fitUV);
            end
            
            rstar = round(R * intensity * NDF_attenuation / parameters.numberOfPatterns, 1);
            mstar = round(M * intensity * NDF_attenuation / parameters.numberOfPatterns, 1);
            sstar = round(S * intensity * NDF_attenuation / parameters.numberOfPatterns, 1);
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
            if obj.numberOfPatterns == 1 && ~obj.forcePrerender
                prerender = false;
            else
                prerender = true;
            end
        end
        
        function numberOfPatterns = get.numberOfPatterns(obj)
            if ~strcmp(obj.colorPattern3, 'none')
                numberOfPatterns = 3;
            elseif ~strcmp(obj.colorPattern2, 'none')
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
        
    end
    
end

