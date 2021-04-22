classdef LightCrafterDevice < symphonyui.core.Device
    
    properties (Access = private, Transient)
        stageClient
        lightCrafter
    end
    
    methods
        
        function obj = LightCrafterDevice(RigConfig)    
            %% Default values that might be changed by RigConfig
            settings = containers.Map();
            settings('host') = 'localhost';
            settings('port') = 5678;
            settings('projectorColorMode') = 'standard';
            settings('orientation') = [0,0];
            settings('micronsPerPixel') = 1;
            settings('angleOffset') = 0;
            settings('frameTrackerPosition') = [40,40];
            settings('frameTrackerSize') = [80,80];
            settings('fitBlue') = 0;
            settings('fitGreen') = 0;
            settings('fitUV') = 0;
            settings('spectralOverlap_Blue') = 0;
            settings('spectralOverlap_Green') = 0;
            settings('spectralOverlap_UV') = 0;
            
            %% Overwrite default values with values from RigConfig if present
            RigProperties = properties(RigConfig);
            for ii = 1:length(RigProperties)
                if settings.isKey(RigProperties{ii})
                    settings(RigProperties{ii}) = RigConfig.(RigProperties{ii});
                end
            end
            
            %%
            cobj = Symphony.Core.UnitConvertingExternalDevice(['LightCrafter Stage@' settings('host')], 'Texas Instruments', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
            
            %% Set up Stage
            obj.stageClient = stage.core.network.StageClient();
            obj.stageClient.connect(settings('host'), settings('port'));
            obj.stageClient.setMonitorGamma(1);
            
            trueCanvasSize = obj.stageClient.getCanvasSize();
            canvasSize = [trueCanvasSize(1) * 2, trueCanvasSize(2)];
            
            obj.stageClient.setCanvasProjectionIdentity();
            obj.stageClient.setCanvasProjectionOrthographic(0, canvasSize(1), 0, canvasSize(2));
            
            %% Set up Lightcrafter
            orientation = settings('orientation');
            
            monitorRefreshRate = obj.stageClient.getMonitorRefreshRate();
            
            fprintf('init proj color %s\n', settings('projectorColorMode'))
            
            obj.lightCrafter = LightCrafter4500(monitorRefreshRate, settings('projectorColorMode'));
            obj.lightCrafter.connect();
            obj.lightCrafter.setMode('pattern');
            obj.lightCrafter.setImageOrientation(orientation(1),orientation(2));
            
            
            %% Save Settings
            obj.addConfigurationSetting('canvasSize', canvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('trueCanvasSize', trueCanvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('frameTrackerSize', settings('frameTrackerSize'));
            obj.addConfigurationSetting('frameTrackerPosition', settings('frameTrackerPosition'));
            obj.addConfigurationSetting('monitorRefreshRate', monitorRefreshRate, 'isReadOnly', true);
            obj.addConfigurationSetting('prerender', false);
            obj.addConfigurationSetting('micronsPerPixel', settings('micronsPerPixel'));
            obj.addConfigurationSetting('canvasTranslation', [0,0]);
            obj.addConfigurationSetting('frameTrackerDuration', .1);
            obj.addConfigurationSetting('colorMode', settings('projectorColorMode'), 'isReadOnly', true);
            obj.addConfigurationSetting('numberOfPatterns', 1);
            obj.addConfigurationSetting('backgroundPatternMode', 'noPattern');
            obj.addConfigurationSetting('backgroundIntensity', 0); % also pattern 1 if contrast mode
            obj.addConfigurationSetting('backgroundIntensity2', 0)
            obj.addConfigurationSetting('backgroundPattern', 1);
            obj.addConfigurationSetting('imageOrientation',orientation, 'isReadOnly', true);
            obj.addConfigurationSetting('angleOffset', settings('angleOffset'));
            
            obj.addResource('fitBlue', settings('fitBlue'));
            obj.addResource('fitGreen', settings('fitGreen'));
            obj.addResource('fitUV', settings('fitUV'));
            obj.addResource('spectralOverlap_Blue', settings('spectralOverlap_Blue'));
            obj.addResource('spectralOverlap_Green', settings('spectralOverlap_Green'));
            obj.addResource('spectralOverlap_UV', settings('spectralOverlap_UV'));

                        
        end
        
        function close(obj)
            try %#ok<TRYNC>
                obj.stageClient.resetCanvasProjection();
                obj.stageClient.resetCanvasRenderer();
            end
            if ~isempty(obj.stageClient)
                obj.stageClient.disconnect();
            end
            if ~isempty(obj.lightCrafter)
                obj.lightCrafter.disconnect();
            end
        end
        
        function s = getColorMode(obj)
            s = obj.getConfigurationSetting('colorMode');
        end
        
        function s = getFrameRate(obj)
            s = obj.getConfigurationSetting('monitorRefreshRate');
        end
        
        function s = getCanvasSize(obj)
            s = obj.getConfigurationSetting('canvasSize');
        end
        
        function s = getTrueCanvasSize(obj)
            s = obj.getConfigurationSetting('trueCanvasSize');
        end
        
        function s = getFrameTrackerSize(obj)
            s = obj.getConfigurationSetting('frameTrackerSize');
        end
        
        function s = getFrameTrackerPosition(obj)
            s = obj.getConfigurationSetting('frameTrackerPosition');
        end
        
        function s = getFrameTrackerDuration(obj)
            s = obj.getConfigurationSetting('frameTrackerDuration');
        end        
        
%         function setFrameTrackerDuration(obj, s)
%             obj.setConfigurationSetting('frameTrackerDuration', s);
%         end        
        
        function s = getCanvasTranslation(obj)
            s = obj.getConfigurationSetting('canvasTranslation');
        end     
        
        function setCanvasTranslation(obj, t)
            obj.setConfigurationSetting('canvasTranslation', t);
        end
        
        function r = getMonitorRefreshRate(obj)
            r = obj.getConfigurationSetting('monitorRefreshRate');
        end
        
        function setBackgroundConfiguration(obj, mode, a, b)

            obj.setConfigurationSetting('backgroundPatternMode', mode)
            
            switch mode
                case 'noPattern'
                    obj.setConfigurationSetting('backgroundIntensity', a)
                    
                case 'singlePattern'
                    obj.setConfigurationSetting('backgroundIntensity', a)
                    obj.setConfigurationSetting('backgroundPattern', b)
                    
                case 'twoPattern'
                    obj.setConfigurationSetting('backgroundIntensity', a)
                    obj.setConfigurationSetting('backgroundIntensity2', b)
            end
            
        end
        
        function tf = getPrerender(obj)
            tf = obj.getConfigurationSetting('prerender');
        end
        
        function setPrerender(obj, tf)
            obj.setConfigurationSetting('prerender', tf);
        end
                
        function play(obj, presentation)
            canvasSize = obj.getCanvasSize();
            canvasTranslation = obj.getConfigurationSetting('canvasTranslation');
            obj.stageClient.setCanvasProjectionIdentity();
            
            obj.stageClient.setCanvasProjectionOrthographic(0, canvasSize(1), 0, canvasSize(2));            
            obj.stageClient.setCanvasProjectionTranslate(canvasTranslation(1), canvasTranslation(2), 0);
            
            % BACKGROUND 
            background = stage.builtin.stimuli.Rectangle();
            background.size = canvasSize;
            background.position = canvasSize/2 - canvasTranslation;
            background.opacity = 1;
            
            mode = obj.getConfigurationSetting('backgroundPatternMode');
            intensity1 = obj.getConfigurationSetting('backgroundIntensity');
            intensity2 = obj.getConfigurationSetting('backgroundIntensity2');
            backgroundPattern = obj.getConfigurationSetting('backgroundPattern');
           
            switch mode
                case 'noPattern'
                    background.color = intensity1;
                    
                case 'singlePattern'
                    background.color = intensity1;
                    backgroundPatternController = stage.builtin.controllers.PropertyController(background, 'opacity',...
                        @(state)(1 * (state.pattern == backgroundPattern - 1)));
                    presentation.addController(backgroundPatternController);
                    
                case 'twoPattern'
                    backgroundPatternController = stage.builtin.controllers.PropertyController(background, 'color',...
                        @(state)(intensity1 * (state.pattern == 0) + intensity2 * (state.pattern == 1)));
                    presentation.addController(backgroundPatternController);
            end
            
            presentation.insertStimulus(1, background);
            
            % FRAME TRACKER
            tracker = stage.builtin.stimuli.Rectangle();
            tracker.size = obj.getFrameTrackerSize();
            tracker.position = obj.getFrameTrackerPosition() - canvasTranslation;
            presentation.addStimulus(tracker);
            % appears on all patterns
            trackerDuration = obj.getFrameTrackerDuration();
            frameRate = obj.getFrameRate();
            trackerColor = stage.builtin.controllers.PropertyController(tracker, 'color', ...
                @(s) s.time < trackerDuration && s.time < (presentation.duration - (1/frameRate))); % mod(s.frame, 2) &&
            presentation.addController(trackerColor);
            
            % RENDER
            if obj.getPrerender()
                player = stage.builtin.players.PrerenderedPlayer(presentation);
            else
                player = stage.builtin.players.RealtimePlayer(presentation);
            end
            player.setCompositor(stage.builtin.compositors.PatternCompositor());
            obj.stageClient.play(player);
        end
        
        function replay(obj)
            obj.stageClient.replay();
        end
        
        function i = getPlayInfo(obj)
            i = obj.stageClient.getPlayInfo();
        end
        
        function clearMemory(obj)
           obj.stageClient.clearMemory();
        end
        
        function setLedEnables(obj, auto, red, green, blue, uv)
            if strcmp(obj.getColorMode(), 'standard')
                obj.lightCrafter.setLedEnables(auto, red, green, blue);
            elseif strcmp(obj.getColorMode(), 'uv')
                obj.lightCrafter.setLedEnables(auto, green, uv, blue);
            elseif strcmp(obj.getColorMode(), 'uv2')
                obj.lightCrafter.setLedEnables(auto, blue, uv, green);
            end
        end
        
        function setLedCurrents(obj, red, green, blue, uv)
            if strcmp(obj.getColorMode(), 'standard')
                obj.lightCrafter.setLedCurrents(red, green, blue);
            elseif strcmp(obj.getColorMode(), 'uv')
                obj.lightCrafter.setLedCurrents(green, uv, blue);
            elseif strcmp(obj.getColorMode(), 'uv2')
                obj.lightCrafter.setLedCurrents(blue, uv, green);
            end
        end        
        
        function [auto, red, green, blue] = getLedEnables(obj)
            [auto, red, green, blue] = obj.lightCrafter.getLedEnables();
        end
        
        function setPatternAttributes(obj, bitDepth, color, numPatterns)
            % configure the lightcrafter
            obj.lightCrafter.setPatternAttributes(bitDepth, color, numPatterns)
            obj.setConfigurationSetting('numberOfPatterns', numPatterns)
            
            % configure the stage renderer
            renderer = stage.builtin.renderers.PatternRenderer(numPatterns, bitDepth);
            obj.stageClient.setCanvasRenderer(renderer);
        end
        
        function [bitDepth, color, numPatterns] = getPatternAttributes(obj)
            [bitDepth, color, numPatterns] = obj.lightCrafter.getPatternAttributes();
        end                
            
            
        function r = getPatternRate(obj)
            r = obj.lightCrafter.currentPatternRate();
        end
        
        function p = um2pix(obj, um)
            micronsPerPixel = obj.getConfigurationSetting('micronsPerPixel');
            p = round(um / micronsPerPixel);
        end
        
    end
    
end

