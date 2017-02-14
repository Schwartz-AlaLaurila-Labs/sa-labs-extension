classdef (Abstract) StageProtocol < sa_labs.protocols.BaseProtocol
% this class handles protocol control which is visual stimulus specific

    properties
        meanLevel = 0.0     % Background light intensity (0-1)
        offsetX = 0         % um
        offsetY = 0         % um
        
        NDF = 5             % Filter NDF value
        frameRate = 60;     % Hz
        blueLED = 30        % 0-255
        greenOrUvLED = 30   % 0-255
        redOrGreenLED = 30   % 0-255 
        numberOfPatterns = 1
        colorPattern1 = 'blue';
        colorPattern2 = 'none';
        colorPattern3 = 'none';
        primaryObjectPattern = 1
        secondaryObjectPattern = 1
        backgroundPattern = 1
    end
    
    properties (Dependent)
        bitDepth       
        RstarMean
        RstarIntensity
        MstarIntensity
        SstarIntensity
    end
    
    properties (Hidden)
        colorPattern1Type = symphonyui.core.PropertyType('char', 'row', {'green', 'blue', 'uv', 'blue+green', 'blue+uv', 'blue+uv+green','red'});
        colorPattern2Type = symphonyui.core.PropertyType('char', 'row', {'none','green', 'blue', 'uv', 'blue+green', 'blue+uv', 'blue+uv+green','red'});
        colorPattern3Type = symphonyui.core.PropertyType('char', 'row', {'none','green', 'blue', 'uv', 'blue+green', 'blue+uv', 'blue+uv+green','red'});
    end
       
    methods (Abstract)
        p = createPresentation(obj);
    end
    
    methods
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.BaseProtocol(obj, name);
            
            switch name
                case {'meanLevel', 'intensity'}
                    d.category = '1 Basic';
                    
                case {'color','offsetX','offsetY','greenOrUvLED','redOrGreenLED','blueLED',...
                        'numberOfPatterns','NDF','frameRate','bitDepth','RstarMean','RstarIntensity','MstarIntensity','SstarIntensity',...
                        'colorPattern1','colorPattern2','colorPattern3','primaryObjectPattern','secondaryObjectPattern','backgroundPattern'}
                    d.category = '8 Projector';
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
            if ~ isempty(obj.rig.getDevices('neutralDensityFilterWheel'))
                filterWheel = obj.rig.getDevice('neutralDensityFilterWheel');
                filterWheel.setNdfValue(obj.NDF);
            end
            
            if ~isempty(obj.rig.getDevices('LightCrafter'))
                % Set the projector configuration
                lightCrafter = obj.rig.getDevice('LightCrafter');
                lightCrafter.setBackground(obj.meanLevel, obj.backgroundPattern);
                lightCrafter.setPatternAttributes(obj.bitDepth, {obj.colorPattern1,obj.colorPattern2,obj.colorPattern3}, obj.numberOfPatterns);
                lightCrafter.setLedCurrents(obj.redOrGreenLED, obj.greenOrUvLED, obj.blueLED);
                lightCrafter.setConfigurationSetting('canvasTranslation', [obj.um2pix(obj.offsetX), obj.um2pix(obj.offsetY)]);
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
            if isempty(intensity)
                return
            end
            if isempty(obj.rig.getDevices('neutralDensityFilterWheel'))
                filterWheelNdfValues = 1:7;
                filterWheelAttentuationValues = [1e0, 1e-1, 1e-2, 1e-3, 1e-4, 1e-5, 1e-6];
            else
                filterWheel = obj.rig.getDevice('neutralDensityFilterWheel');
                filterWheelNdfValues = filterWheel.getConfigurationSetting('filterWheelNdfValues');
                filterWheelAttentuationValues = filterWheel.getResource('filterWheelAttentuationValues');
            end

            filterIndex = find(filterWheelNdfValues == obj.NDF, 1);

            NDF_attenuation = filterWheelAttentuationValues(filterIndex);
            lightCrafter = obj.rig.getDevice('LightCrafter');
            if strcmp('standard', lightCrafter.getColorMode())
                [R, M, S] = sa_labs.util.photoIsom2_triColor(obj.blueLED, obj.greenOrUvLED, 0, ...
                    obj.colorPattern1, lightCrafter.getResource('fitBlue'), lightCrafter.getResource('fitGreen'), 0)
            else
                % UV mode
                [R, M, S] = sa_labs.util.photoIsom2_triColor(obj.blueLED, obj.redOrGreenLED, obj.greenOrUvLED, ...
                    obj.colorPattern1, lightCrafter.getResource('fitBlue'), lightCrafter.getResource('fitGreen'), lightCrafter.getResource('fitUV'));
            end
            
            rstar = R * intensity * NDF_attenuation;
            mstar = M * intensity * NDF_attenuation;
            sstar = S * intensity * NDF_attenuation;
            
            %deal with patternsPerFrame in Rstar calculation
            maxPatternsPerFrame  = [24 12 8 6 4 4 3 2];
            rstar = round(rstar * obj.numberOfPatterns ./ maxPatternsPerFrame(obj.bitDepth) * 2, 1);
            mstar = round(mstar * obj.numberOfPatterns ./ maxPatternsPerFrame(obj.bitDepth) * 2, 1);
            sstar = round(sstar * obj.numberOfPatterns ./ maxPatternsPerFrame(obj.bitDepth) * 2, 1);
        end
         
        function RstarMean = get.RstarMean(obj)
            RstarMean = [];
            if ~isempty(obj.rig.getDevices('LightCrafter'))
                [RstarMean, ~, ~] = obj.convertIntensityToIsomerizations(obj.meanLevel);
            end
        end
    
        function RstarIntensity = get.RstarIntensity(obj)
            RstarIntensity = [];
            if isprop(obj, 'intensity') && ~isempty(obj.rig.getDevices('LightCrafter'))
                [RstarIntensity, ~, ~] = obj.convertIntensityToIsomerizations(obj.intensity);
            end
        end
        
        function MstarIntensity = get.MstarIntensity(obj)
            MstarIntensity = [];
            if isprop(obj, 'intensity') && ~isempty(obj.rig.getDevices('LightCrafter'))
                [~, MstarIntensity, ~] = obj.convertIntensityToIsomerizations(obj.intensity);
            end
        end
        
        function SstarIntensity = get.SstarIntensity(obj)
            SstarIntensity = [];
            if isprop(obj, 'intensity') && ~isempty(obj.rig.getDevices('LightCrafter'))
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
    end
    
    
    methods (Access = protected)
        
        function p = um2pix(obj, um)
            stage = obj.rig.getDevice('Stage');
            micronsPerPixel = stage.getConfigurationSetting('micronsPerPixel');
            p = round(um / micronsPerPixel);
        end
        
    end
    
end

