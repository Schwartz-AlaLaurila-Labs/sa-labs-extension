classdef LightCrafterDevice < symphonyui.core.Device
    
    properties (Access = private, Transient)
        stageClient
        lightCrafter
    end
    
    methods
        
        function obj = LightCrafterDevice(varargin)
            ip = inputParser();
            ip.addParameter('host', 'localhost', @ischar);
            ip.addParameter('port', 5678, @isnumeric);
            ip.addParameter('micronsPerPixel', @isnumeric);
            ip.addParameter('colorMode', 'standard', @ischar);
            ip.addParameter('orientation', [0,0]);
            ip.parse(varargin{:});
            
            cobj = Symphony.Core.UnitConvertingExternalDevice(['LightCrafter Stage@' ip.Results.host], 'Texas Instruments', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
            
            % Set up Stage
            obj.stageClient = stage.core.network.StageClient();
            obj.stageClient.connect(ip.Results.host, ip.Results.port);
            obj.stageClient.setMonitorGamma(1);
            
            trueCanvasSize = obj.stageClient.getCanvasSize();
            canvasSize = [trueCanvasSize(1) * 2, trueCanvasSize(2)];
            frameTrackerSizeDefault = [80,80];
            frameTrackerPositionDefault = [40,40];
            
            obj.stageClient.setCanvasProjectionIdentity();
            obj.stageClient.setCanvasProjectionOrthographic(0, canvasSize(1), 0, canvasSize(2));
            
            % Set up Lightcrafter
            colorMode = ip.Results.colorMode;
            orientation = ip.Results.orientation;
            
            monitorRefreshRate = obj.stageClient.getMonitorRefreshRate();
            
            obj.lightCrafter = LightCrafter4500(monitorRefreshRate, ip.Results.colorMode);
            obj.lightCrafter.connect();
            obj.lightCrafter.setMode('pattern');
            obj.lightCrafter.setImageOrientation(orientation(1),orientation(2));
            
            obj.addConfigurationSetting('canvasSize', canvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('trueCanvasSize', trueCanvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('frameTrackerSize', frameTrackerSizeDefault);
            obj.addConfigurationSetting('frameTrackerPosition', frameTrackerPositionDefault);
            obj.addConfigurationSetting('monitorRefreshRate', monitorRefreshRate, 'isReadOnly', true);
            obj.addConfigurationSetting('prerender', false);
            obj.addConfigurationSetting('micronsPerPixel', 1);
            obj.addConfigurationSetting('canvasTranslation', [0,0]);
            obj.addConfigurationSetting('frameTrackerDuration', .1);
            obj.addConfigurationSetting('colorMode', colorMode, 'isReadOnly', true);
            obj.addConfigurationSetting('numberOfPatterns', 1);
            obj.addConfigurationSetting('backgroundPatternMode', 'noPattern');
            obj.addConfigurationSetting('backgroundIntensity', 0); % also pattern 1 if contrast mode
            obj.addConfigurationSetting('backgroundIntensity2', 0)
            obj.addConfigurationSetting('backgroundPattern', 1);
            obj.addConfigurationSetting('imageOrientation',orientation, 'isReadOnly', true);
            obj.addConfigurationSetting('angleOffset', 0);
                        
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
                @(s)mod(s.frame, 2) && s.time < trackerDuration && s.time < (presentation.duration - (1/frameRate)));
            presentation.addController(trackerColor);
            
            trackerOpacity = stage.builtin.controllers.PropertyController(tracker, 'opacity', ...
                @(s)s.time < trackerDuration && s.time < (presentation.duration - (1/frameRate)));
            presentation.addController(trackerOpacity);
            
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
            else
                obj.lightCrafter.setLedEnables(auto, green, uv, blue);
            end
        end
        
        function setLedCurrents(obj, red, green, blue, uv)
            if strcmp(obj.getColorMode(), 'standard')
                obj.lightCrafter.setLedCurrents(red, green, blue);
            else
                obj.lightCrafter.setLedCurrents(green, uv, blue);
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

