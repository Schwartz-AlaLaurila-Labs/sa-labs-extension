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
        colorPattern1 = 'blue';
        colorPattern2 = 'none';
        colorPattern3 = 'none';
        primaryObjectPattern = 1
        secondaryObjectPattern = 1
        backgroundPattern = 2
    end
    
    properties (Dependent)
        numberOfPatterns = 1        
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
                        if strcmp(name, 'redLED')
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

            obj.rigProperty = sa_labs.factory.getInstance('rigProperty');
            obj.colorMode = obj.rigProperty.rigDescription.projectorColorMode;
            
            if ~ isempty(obj.rig.getDevices('neutralDensityFilterWheel'))
                obj.NDF = obj.rig.getDevice('neutralDensityFilterWheel').getResource('defaultNdfValue');
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
                if filterWheel.getConfigurationSetting('comPort') > 0
                    filterWheel.setNdfValue(obj.NDF);
                end
            end
            
            % check for pattern setting correctness
            if ~ strcmp(obj.colorPattern2, 'none')
                if ~(obj.numberOfPatterns >= 2)
                    error('Must have >= 2 patterns to use second pattern')
                end
            end
            
            if ~ isempty(obj.rig.getDevices('LightCrafter'))
                % Set the projector configuration
                % TODO move the logic to light crafter
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
            if ~ isempty(obj.rig.getDevices('LightCrafter'))
                lightCrafter = obj.rig.getDevice('LightCrafter');
                
                % TODO how about setting this later h5 parsing, since h5 will have all the device configurations ?
                epoch.addParameter('micronsPerPixel', lightCrafter.getConfigurationSetting('micronsPerPixel'));
                epoch.addParameter('angleOffsetFromRig', lightCrafter.getConfigurationSetting('angleOffset'));
            end
            
            % uses the frame tracker on the monitor to inform the HEKA that
            % the stage presentation has begun. Improves temporal alignment
            epoch.shouldWaitForTrigger = true;
            

            if obj.rigProperty.testMode
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
            
            if ~ obj.rigProperty.testMode
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
            rigDesc =  obj.rigProperty.rigDescription;
            [RstarMean, ~, ~] = rigDesc.getIsomerizations(obj.meanLevel, obj.isomerizationParameters());
        end
    
        function RstarIntensity = get.RstarIntensity(obj)
            RstarIntensity = [];
            if isprop(obj, 'intensity')
                rigDesc =  obj.rigProperty.rigDescription;
                [RstarIntensity, ~, ~] = rigDesc.getIsomerizations(obj.intensity, obj.isomerizationParameters());
            end
        end
        
        function MstarIntensity = get.MstarIntensity(obj)
            MstarIntensity = [];
            if isprop(obj, 'intensity')
                rigDesc =  obj.rigProperty.rigDescription;
                [~, MstarIntensity, ~] = rigDesc.getIsomerizations(obj.intensity, obj.isomerizationParameters());
            end
        end
        
        function SstarIntensity = get.SstarIntensity(obj)
            SstarIntensity = [];
            if isprop(obj, 'intensity')
                rigDesc =  obj.rigProperty.rigDescription;
                [~, ~, SstarIntensity] = rigDesc.getIsomerizations(obj.intensity, obj.isomerizationParameters());
            end
        end

        function p = isomerizationParameters(obj)
            source = [];
            
            if ~ isempty(obj.persistor)
                source = obj.persistor.currentEpochGroup.source.getPropertyMap();
            end
            
            p = struct();
            p.NDF = obj.NDF;
            p.blueLED = obj.blueLED;
            p.greenLED = obj.greenLED;
            p.uvLED = obj.uvLED;
            p.colorPattern1 = obj.colorPattern1;
            p.numberOfPatterns = obj.numberOfPatterns;
            
            p.ledCurrents = [obj.blueLED, obj.greenLED obj.uvLED];
            p.ledTypes = sort(strsplit(obj.colorPattern1, '+'));
            p.mouse = source;
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

