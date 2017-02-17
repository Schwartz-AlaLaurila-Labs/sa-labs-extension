classdef (Abstract) StageProtocol < sa_labs.protocols.BaseProtocol
% this class handles protocol control which is visual stimulus specific

    properties
        meanLevel = 0.0     % Background light intensity (0-1)
        offsetX = 0         % um
        offsetY = 0         % um
        
        NDF = 5             % Filter NDF value
%         frameRate = 60;     % [15, 30, 45, 60] Hz
        blueLED = 20        % 0-255
        greenLED = 0   % 0-255
        redLED = 0   % 0-255 
        uvLED = 0
        numberOfPatterns = 1
        colorPattern1 = 'blue';
        colorPattern2 = 'none';
        colorPattern3 = 'none';
        primaryObjectPattern = 1
        secondaryObjectPattern = 1
        backgroundPattern = 1
    end
    
    properties (Dependent)
        RstarMean
        RstarIntensity
        MstarIntensity
        SstarIntensity
        bitDepth = 8
        prerender = false
    end
    
    properties (Hidden)
        colorPattern1Type = symphonyui.core.PropertyType('char', 'row', {'green', 'blue', 'uv', 'blue+green', 'green+uv', 'blue+uv', 'blue+uv+green','red'});
        colorPattern2Type = symphonyui.core.PropertyType('char', 'row', {'none','green', 'blue', 'uv', 'blue+green', 'green+uv', 'blue+uv', 'blue+uv+green','red'});
        colorPattern3Type = symphonyui.core.PropertyType('char', 'row', {'none','green', 'blue', 'uv', 'blue+green', 'green+uv', 'blue+uv', 'blue+uv+green','red'});
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
                    
                case {'offsetX','offsetY','RstarMean','RstarIntensity','MstarIntensity','SstarIntensity'}
                    d.category = '7 Projector';
                    
                case {'greenLED','redLED','blueLED','uvLED','NDF'}
                    d.category = '7 Projector';
                    if strcmp(obj.colorMode, 'standard')
                        if strcmp(name, 'uvLED')
                            d.isHidden = true;
                        end
                    else 
                        if strcmp(name, 'redLED') || strcmp(name, 'NDF')
                            d.isHidden = true;
                        end
                    end
                    
                case {'color', 'numberOfPatterns','frameRate','bitDepth',...
                        'colorPattern1','colorPattern2','colorPattern3',...
                        'primaryObjectPattern','secondaryObjectPattern','backgroundPattern',...
                        'prerender'}
                    d.category = '8 Color';
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
                obj.colorMode = lightCrafter.getColorMode();
            else
                obj.colorMode = '';
                obj.lightCrafterParams = [];
            end
            
            if isempty(obj.rig.getDevices('neutralDensityFilterWheel'))
                obj.filterWheelNdfValues = [0, 2, 3, 4, 5, 6];
                obj.filterWheelAttenuationValues = [1.0, 0.0076, 6.23E-4, 6.93E-5, 8.32E-6, 1.0E-6];
            else
                filterWheel = obj.rig.getDevice('neutralDensityFilterWheel');
                obj.filterWheelNdfValues = filterWheel.getConfigurationSetting('filterWheelNdfValues');
                obj.filterWheelAttenuationValues = filterWheel.getResource('filterWheelAttenuationValues');
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
                filterWheel.setNdfValue(obj.NDF);
            end
            
            if ~isempty(obj.rig.getDevices('LightCrafter'))
                % Set the projector configuration
                lightCrafter = obj.rig.getDevice('LightCrafter');
                lightCrafter.setBackground(obj.meanLevel, obj.backgroundPattern);
                lightCrafter.setPrerender(obj.prerender);
                lightCrafter.setPatternAttributes(obj.bitDepth, {obj.colorPattern1,obj.colorPattern2,obj.colorPattern3}, obj.numberOfPatterns);
                lightCrafter.setLedCurrents(obj.redLED, obj.greenLED, obj.blueLED, obj.uvLED);
                lightCrafter.setCanvasTranslation([obj.um2pix(obj.offsetX), obj.um2pix(obj.offsetY)]);
                pause(0.2); % let the projector get set up
            end
            prepareRun@sa_labs.protocols.BaseProtocol(obj);
        end

        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
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
    
        function [rstar, mstar, sstar] = convertIntensityToIsomerizations(obj, intensity)
            rstar = [];
            mstar = [];
            sstar = [];
            if isempty(intensity) || isempty(obj.lightCrafterParams)
                return
            end
            
            if strcmp('standard', obj.colorMode)
                [R, M, S] = sa_labs.util.photoIsom2(obj.blueLED, obj.greenLED, ...
                    obj.colorPattern1, obj.lightCrafterParams.fitBlue, obj.lightCrafterParams.fitGreen);
                filterIndex = find(obj.filterWheelNdfValues == obj.NDF, 1);            
                NDF_attenuation = obj.filterWheelAttenuationValues(filterIndex);
            else
                % UV mode
                [R, M, S] = sa_labs.util.photoIsom2_triColor(obj.blueLED, obj.greenLED, obj.uvLED, ...
                    obj.colorPattern1, obj.lightCrafterParams.fitBlue, obj.lightCrafterParams.fitGreen, obj.lightCrafterParams.fitUV);
                NDF_attenuation = 1; % there's an NDF3 already included in the calculation for the upper projector
            end
            
            rstar = round(R * intensity * NDF_attenuation / obj.numberOfPatterns, 1);
            mstar = round(M * intensity * NDF_attenuation / obj.numberOfPatterns, 1);
            sstar = round(S * intensity * NDF_attenuation / obj.numberOfPatterns, 1);
        end
         
        function RstarMean = get.RstarMean(obj)
            [RstarMean, ~, ~] = obj.convertIntensityToIsomerizations(obj.meanLevel);
        end
    
        function RstarIntensity = get.RstarIntensity(obj)
            RstarIntensity = [];
            if isprop(obj, 'intensity')
                [RstarIntensity, ~, ~] = obj.convertIntensityToIsomerizations(obj.intensity);
            end
        end
        
        function MstarIntensity = get.MstarIntensity(obj)
            MstarIntensity = [];
            if isprop(obj, 'intensity')
                [~, MstarIntensity, ~] = obj.convertIntensityToIsomerizations(obj.intensity);
            end
        end
        
        function SstarIntensity = get.SstarIntensity(obj)
            SstarIntensity = [];
            if isprop(obj, 'intensity')
                [~, ~, SstarIntensity] = obj.convertIntensityToIsomerizations(obj.intensity);
            end
        end        
        
        function bitDepth = get.bitDepth(obj)
            if obj.numberOfPatterns == 1
                bitDepth = 8;
            else
                bitDepth = 6;
            end
        end
        
        function prerender = get.prerender(obj)
            if obj.numberOfPatterns == 1
                prerender = false;
            else
                prerender = true;
            end
        end
    end
    
    
    methods (Access = protected)
        
        function p = um2pix(obj, um)
            stage = obj.rig.getDevice('Stage');
            micronsPerPixel = stage.getConfigurationSetting('micronsPerPixel');
            p = round(um / micronsPerPixel);
        end
        
    end
    
end

