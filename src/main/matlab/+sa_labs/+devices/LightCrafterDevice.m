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
            
            obj.stageClient.setCanvasProjectionIdentity();
            obj.stageClient.setCanvasProjectionOrthographic(0, canvasSize(1), 0, canvasSize(2));
            
            obj.lightCrafter = LightCrafter4500(obj.stageClient.getMonitorRefreshRate());
            obj.lightCrafter.connect();
            obj.lightCrafter.setMode('pattern');
            obj.lightCrafter.setLedEnables(true, false, false, false);
            [auto, red, green, blue] = obj.lightCrafter.getLedEnables();
            
            refreshRate = obj.stageClient.getMonitorRefreshRate();
            obj.patternRatesToAttributes = containers.Map('KeyType', 'double', 'ValueType', 'any');
            obj.patternRatesToAttributes(1 * refreshRate)  = {8, 'white', 1};
            obj.patternRatesToAttributes(2 * refreshRate)  = {8, 'white', 2};
            obj.patternRatesToAttributes(4 * refreshRate)  = {6, 'white', 4};
            obj.patternRatesToAttributes(6 * refreshRate)  = {4, 'white', 6};
            obj.patternRatesToAttributes(8 * refreshRate)  = {3, 'white', 8};
            obj.patternRatesToAttributes(12 * refreshRate) = {2, 'white', 12};
            obj.patternRatesToAttributes(24 * refreshRate) = {1, 'white', 24};
            
            attributes = obj.patternRatesToAttributes(refreshRate);
            obj.lightCrafter.setPatternAttributes(attributes{:});
            
            renderer = stage.builtin.renderers.PatternRenderer(attributes{3}, attributes{1});
            obj.stageClient.setCanvasRenderer(renderer);
            
            obj.addConfigurationSetting('canvasSize', canvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('trueCanvasSize', trueCanvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('monitorRefreshRate', refreshRate, 'isReadOnly', true);
            obj.addConfigurationSetting('frameTrackerDuration', frameTrackerDuration, 'isReadOnly', true);
            obj.addConfigurationSetting('frameTrackerPosition', frameTrackerPosition, 'isReadOnly', true);            
            obj.addConfigurationSetting('prerender', false, 'isReadOnly', true);
            obj.addConfigurationSetting('lightCrafterLedEnables',  [auto, red, green, blue], 'isReadOnly', true);
            obj.addConfigurationSetting('lightCrafterPatternRate', obj.lightCrafter.currentPatternRate(), 'isReadOnly', true);
            %obj.addConfigurationSetting('micronsPerPixel', ip.Results.micronsPerPixel, 'isReadOnly', true);
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
        
        function r = getMonitorRefreshRate(obj)
            r = obj.getConfigurationSetting('monitorRefreshRate');
        end
        
        function setPrerender(obj, tf)
            obj.setReadOnlyConfigurationSetting('prerender', logical(tf));
        end
        
        function tf = getPrerender(obj)
            tf = obj.getConfigurationSetting('prerender');
        end
        
        function play(obj, presentation)
            canvasSize = obj.getCanvasSize();
            
            background = stage.builtin.stimuli.Rectangle();
            background.size = canvasSize;
            background.position = canvasSize/2;
            background.color = presentation.backgroundColor;
            presentation.setBackgroundColor(0);
            presentation.insertStimulus(1, background);
            
            tracker = stage.builtin.stimuli.FrameTracker();
            tracker.position = obj.frameTrackerPosition;
            presentation.addStimulus(tracker);
            trackerColor =  stage.builtin.controllers.PropertyController(tracker, 'color', @(s)double(255.*repmat(s.time < obj.frameTrackerDuration *1e-3, 1, 3)));
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
        
        function setPatternRate(obj, rate)
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
