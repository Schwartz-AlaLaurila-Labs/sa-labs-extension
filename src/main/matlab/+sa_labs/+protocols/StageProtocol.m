classdef (Abstract) StageProtocol < sa_labs.protocols.BaseProtocol
% this class handles protocol control which is visual stimulus specific

    properties
        meanLevel = 0.0     % Background light intensity (0-1)
        offsetX = 0         % um
        offsetY = 0         % um
        
        NDF = 5             % Filter NDF value
        frameRate = 60;     % Hz
        patternRate = 60;   % Hz
        blueLED = 10        % 0-255
        greenLED = 0        % 0-255
    end
    
    properties (Dependent)
        RstarMean
        RstarIntensity
    end
    
    properties (Hidden)
        color = 'blue';
        bitDepth = 8;
        numPatternsPerFrame = 1
        
        colorType = symphonyui.core.PropertyType('char', 'row', {'cyan','blue','green'});
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
                    
                case {'color','offsetX','offsetY','blueLED','greenLED','patternsPerFrame','NDF','frameRate','patternRate','bitDepth','RstarMean','RstarIntensity'}
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
            obj.rig.getDevice('Stage').play(obj.createPresentation()); % may need mods for different devices
        end
        
        function prepareRun(obj)

            obj.showFigure('io.github.stage_vss.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));

            % set the NDF filter wheel
            if ~ isempty(obj.rig.getDevices('neutralDensityFilterWheel'))
                filterWheel = obj.rig.getDevice('neutralDensityFilterWheel');
                filterWheel.setNdfValue(obj.NDF);
%                 obj.NDF = filterWheel.getValue();
            end
            
            if ~ isempty(obj.rig.getDevices('LightCrafter'))
                % Set the projector configuration
                lightCrafter = obj.rig.getDevice('LightCrafter');
                lightCrafter.setPatternAttributes(obj.bitDepth, obj.color, obj.numPatternsPerFrame);
                lightCrafter.setLedCurrents(0, obj.greenLED, obj.blueLED);
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
    
        function rstar = convertRelativeToRStar(obj, inval)
            rstar = [];
            if isempty(inval)
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
            [R,~,~] = sa_labs.util.photoIsom2(obj.blueLED, obj.greenLED, obj.color, lightCrafter.getResource('fitBlue'), lightCrafter.getResource('fitGreen'));
            rstar = R * inval * NDF_attenuation;
            %deal with patternsPerFrame in Rstar calculation
            maxPatternsPerFrame  = [24 12 8 6 4 4 3 2];
            rstar = rstar * obj.numPatternsPerFrame./maxPatternsPerFrame(obj.bitDepth) * 2;
        end
         
        function RstarMean = get.RstarMean(obj)
            RstarMean = [];
            if ~ isempty(obj.rig.getDevices('LightCrafter'))
                RstarMean = obj.convertRelativeToRStar(obj.meanLevel);
            end
        end
    
        function RstarIntensity = get.RstarIntensity(obj)
            if isprop(obj, 'intensity') && ~ isempty(obj.rig.getDevices('LightCrafter'))
                RstarIntensity = obj.convertRelativeToRStar(obj.intensity);
            else
                RstarIntensity = [];
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

