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
            ip.addParameter('colorMode', @ischar);
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
            frameTrackerSize = [80,80];
            frameTrackerPosition = [40,40];
            
            obj.stageClient.setCanvasProjectionIdentity();
            obj.stageClient.setCanvasProjectionOrthographic(0, canvasSize(1), 0, canvasSize(2));
            
            % Set up Lightcrafter
            colorMode = ip.Results.colorMode
            if strcmp(colorMode, 'tricolor')
                bitDepth = 6;
                numPatterns = 3;
                color = 'blue+uv+green';
            else
                bitDepth = 8;
                numPatterns = 1;
                color = 'blue';
            end            
            
            obj.lightCrafter = LightCrafter4500(obj.stageClient.getMonitorRefreshRate(), colorMode);
            obj.lightCrafter.connect();
            obj.lightCrafter.setMode('pattern');
%             [auto, red, green, blue] = obj.lightCrafter.getLedEnables();

            monitorRefreshRate = obj.stageClient.getMonitorRefreshRate();
            obj.setPatternAttributes(bitDepth, color, numPatterns);
            
            obj.addConfigurationSetting('canvasSize', canvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('trueCanvasSize', trueCanvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('frameTrackerSize', frameTrackerSize);
            obj.addConfigurationSetting('frameTrackerPosition', frameTrackerPosition);
            obj.addConfigurationSetting('monitorRefreshRate', monitorRefreshRate, 'isReadOnly', true);
            obj.addConfigurationSetting('prerender', false, 'isReadOnly', true);
%             obj.addConfigurationSetting('lightCrafterLedEnables',  [auto, red, green, blue], 'isReadOnly', false);
%             obj.addConfigurationSetting('lightCrafterPatternRate', patternRate, 'isReadOnly', false);
            obj.addConfigurationSetting('micronsPerPixel', ip.Results.micronsPerPixel, 'isReadOnly', true);
            obj.addConfigurationSetting('canvasTranslation', [0,0]);
            obj.addConfigurationSetting('frameTrackerDuration', 0.2, 'isReadOnly', false);
            obj.addConfigurationSetting('colorMode', colorMode, 'isReadOnly', true); % 'tricolor'
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
        
        function r = getMonitorRefreshRate(obj)
            r = obj.getConfigurationSetting('monitorRefreshRate');
        end
        
%         function setPrerender(obj, tf)
%             obj.setReadOnlyConfigurationSetting('prerender', logical(tf));
%         end
        
        function tf = getPrerender(obj)
            tf = obj.getConfigurationSetting('prerender');
        end
        
        function setLedCurrents(obj, r, g, b)
            obj.lightCrafter.setLedCurrents(r, g, b)
        end
        
        function play(obj, presentation)
            canvasSize = obj.getCanvasSize();
            canvasTranslation = obj.getConfigurationSetting('canvasTranslation');
            obj.stageClient.setCanvasProjectionIdentity();
            obj.stageClient.setCanvasProjectionOrthographic(0, canvasSize(1), 0, canvasSize(2));            
            obj.stageClient.setCanvasProjectionTranslate(canvasTranslation(1), canvasTranslation(2), 0);

            background = stage.builtin.stimuli.Rectangle();
            background.size = canvasSize;
            background.position = canvasSize/2 - canvasTranslation;
            background.color = presentation.backgroundColor;
            presentation.setBackgroundColor(0);
            presentation.insertStimulus(1, background);
            
            tracker = stage.builtin.stimuli.Rectangle();
            tracker.size = obj.getFrameTrackerSize();
            tracker.position = obj.getFrameTrackerPosition() - canvasTranslation;
            presentation.addStimulus(tracker);
            
            trackerColor = stage.builtin.controllers.PropertyController(tracker, 'color', ...
                @(s)mod(s.frame, 2) && double(s.time + (1/s.frameRate) < obj.getFrameTrackerDuration()));
            presentation.addController(trackerColor);
            
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
        
        function setLedEnables(obj, auto, red, green, blue)
            obj.lightCrafter.setLedEnables(auto, red, green, blue);
            [a, r, g, b] = obj.lightCrafter.getLedEnables();
            obj.setReadOnlyConfigurationSetting('lightCrafterLedEnables', [a, r, g, b]);
        end
        
        function [auto, red, green, blue] = getLedEnables(obj)
            [auto, red, green, blue] = obj.lightCrafter.getLedEnables();
        end
        
        function setPatternAttributes(obj, bitDepth, color, numPatterns)
            % configure the lightcrafter
            obj.lightCrafter.setPatternAttributes(bitDepth, color, numPatterns)
            
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

