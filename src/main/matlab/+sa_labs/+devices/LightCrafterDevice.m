classdef LightCrafterDevice < symphonyui.core.Device
    
    properties (Access = private, Transient)
        stageClient
        lightCrafter
        patternRatesToAttributes
    end
    
    methods
        
        function obj = LightCrafterDevice(varargin)
            ip = inputParser();
            ip.addParameter('host', 'localhost', @ischar);
            ip.addParameter('port', 5678, @isnumeric);
            ip.addParameter('micronsPerPixel', @isnumeric);
            ip.parse(varargin{:});
            
            cobj = Symphony.Core.UnitConvertingExternalDevice(['LightCrafter Stage@' ip.Results.host], 'Texas Instruments', Symphony.Core.Measurement(0, symphonyui.core.Measurement.UNITLESS));
            obj@symphonyui.core.Device(cobj);
            obj.cobj.MeasurementConversionTarget = symphonyui.core.Measurement.UNITLESS;
            
            obj.stageClient = stage.core.network.StageClient();
            obj.stageClient.connect(ip.Results.host, ip.Results.port);
            obj.stageClient.setMonitorGamma(1);
            
            trueCanvasSize = obj.stageClient.getCanvasSize();
            canvasSize = [trueCanvasSize(1) * 2, trueCanvasSize(2)];
            frameTrackerSize = [80,80];
            frameTrackerPosition = [40,40];
            
            obj.stageClient.setCanvasProjectionIdentity();
            obj.stageClient.setCanvasProjectionOrthographic(0, canvasSize(1), 0, canvasSize(2));
            
            obj.lightCrafter = LightCrafter4500(obj.stageClient.getMonitorRefreshRate());
            obj.lightCrafter.connect();
            obj.lightCrafter.setMode('pattern');
            obj.lightCrafter.setLedEnables(true, false, false, false);
            [auto, red, green, blue] = obj.lightCrafter.getLedEnables();
            
            monitorRefreshRate = obj.stageClient.getMonitorRefreshRate();
            obj.patternRatesToAttributes = containers.Map('KeyType', 'double', 'ValueType', 'any');
            obj.patternRatesToAttributes(1 * monitorRefreshRate)  = {8, 'white', 1};
            obj.patternRatesToAttributes(2 * monitorRefreshRate)  = {8, 'white', 2};
            obj.patternRatesToAttributes(4 * monitorRefreshRate)  = {6, 'white', 4};
            obj.patternRatesToAttributes(6 * monitorRefreshRate)  = {4, 'white', 6};
            obj.patternRatesToAttributes(8 * monitorRefreshRate)  = {3, 'white', 8};
            obj.patternRatesToAttributes(12 * monitorRefreshRate) = {2, 'white', 12};
            obj.patternRatesToAttributes(24 * monitorRefreshRate) = {1, 'white', 24};

            attributes = obj.patternRatesToAttributes(monitorRefreshRate);
            obj.lightCrafter.setPatternAttributes(attributes{:});
            
            renderer = stage.builtin.renderers.PatternRenderer(attributes{3}, attributes{1});
            obj.stageClient.setCanvasRenderer(renderer);
            
            obj.addConfigurationSetting('canvasSize', canvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('trueCanvasSize', trueCanvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('frameTrackerSize', frameTrackerSize);
            obj.addConfigurationSetting('frameTrackerPosition', frameTrackerPosition);
            obj.addConfigurationSetting('monitorRefreshRate', monitorRefreshRate, 'isReadOnly', true);
            obj.addConfigurationSetting('prerender', false, 'isReadOnly', true);
            obj.addConfigurationSetting('lightCrafterLedEnables',  [auto, red, green, blue], 'isReadOnly', true);
            obj.addConfigurationSetting('lightCrafterPatternRate', obj.lightCrafter.currentPatternRate(), 'isReadOnly', true);
            obj.addConfigurationSetting('micronsPerPixel', ip.Results.micronsPerPixel, 'isReadOnly', true);
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
        
        function r = getMonitorRefreshRate(obj)
            r = obj.getConfigurationSetting('monitorRefreshRate');
        end
        
        function setPrerender(obj, tf)
            obj.setReadOnlyConfigurationSetting('prerender', logical(tf));
        end
        
        function tf = getPrerender(obj)
            tf = obj.getConfigurationSetting('prerender');
        end
        
        function setLedCurrents(obj, r, g, b)
            obj.lightCrafter.setLedCurrents(r, g, b)
        end
        
        function play(obj, presentation)
            canvasSize = obj.getCanvasSize();
            
            background = stage.builtin.stimuli.Rectangle();
            background.size = canvasSize;
            background.position = canvasSize/2;
            background.color = presentation.backgroundColor;
            presentation.setBackgroundColor(0);
            presentation.insertStimulus(1, background);
            
            tracker = stage.builtin.stimuli.Rectangle();
            tracker.size = obj.getFrameTrackerSize();
            tracker.position = obj.getFrameTrackerPosition();
            presentation.addStimulus(tracker);
            
            frameTrackerDuration = .20;
            trackerColor = stage.builtin.controllers.PropertyController(tracker, 'color', @(s)mod(s.frame, 2) && double(s.time + (1/s.frameRate) < frameTrackerDuration));
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
        
        function r = availablePatternRates(obj)
            r = obj.patternRatesToAttributes.keys;
        end
        
        function attributes = setPatternRate(obj, rate)
            if ~obj.patternRatesToAttributes.isKey(rate)
                error([num2str(rate) ' is not an available pattern rate']);
            end
            attributes = obj.patternRatesToAttributes(rate);
            obj.lightCrafter.setPatternAttributes(attributes{:});
            obj.setReadOnlyConfigurationSetting('lightCrafterPatternRate', obj.lightCrafter.currentPatternRate());
            
            renderer = stage.builtin.renderers.PatternRenderer(attributes{3}, attributes{1});
            obj.stageClient.setCanvasRenderer(renderer);
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

