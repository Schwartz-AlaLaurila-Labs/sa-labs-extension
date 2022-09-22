classdef LightCrafterDevice < symphonyui.core.Device
    
    properties (Access = private, Transient)
        stageClient
        lightCrafter
        orientation
        baseTranslation = [0,0]
    end
    
    methods
        
        function obj = LightCrafterDevice(RigConfig, lcr)    
            %% Default values that might be changed by RigConfig
            settings = containers.Map();
            settings('host') = 'localhost';
            settings('port') = 5678;
            settings('projectorColorMode') = 'standard';
            settings('orientation') = [0,0];
            settings('micronsPerPixel') = 1;
            settings('canvasTranslation') = [0,0];
            settings('angleOffset') = 0;
            settings('frameTrackerPosition') = [40,40];
            settings('frameTrackerSize') = [80,80];
            settings('frameTrackerBackgroundSize') = [80,80];
            settings('frameTrackerDuration') = .1;
            settings('fitBlue') = 0;
            settings('fitGreen') = 0;
            settings('fitUV') = 0;
            settings('spectralOverlap_Blue') = 0;
            settings('spectralOverlap_Green') = 0;
            settings('spectralOverlap_UV') = 0;
            settings('blankingFactor') = 1;
            
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
            obj.orientation = settings('orientation');
            
            monitorRefreshRate = obj.stageClient.getMonitorRefreshRate();
            
            fprintf('init proj color %s\n', settings('projectorColorMode'))
            
            obj.lightCrafter = lcr(monitorRefreshRate, settings('projectorColorMode'));
            obj.baseTranslation = settings('canvasTranslation');
            %TODO: oncleanup, lcr.disconnect()
            obj.connect();
            
            
            %% Save Settings
            obj.addConfigurationSetting('canvasSize', canvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('trueCanvasSize', trueCanvasSize, 'isReadOnly', true);
            obj.addConfigurationSetting('frameTrackerSize', settings('frameTrackerSize'));
            obj.addConfigurationSetting('frameTrackerBackgroundSize', settings('frameTrackerBackgroundSize'));
            obj.addConfigurationSetting('frameTrackerPosition', settings('frameTrackerPosition'));
            obj.addConfigurationSetting('monitorRefreshRate', monitorRefreshRate, 'isReadOnly', true);
            obj.addConfigurationSetting('prerender', false);
            obj.addConfigurationSetting('micronsPerPixel', settings('micronsPerPixel'));
            obj.addConfigurationSetting('canvasTranslation', settings('canvasTranslation'));
            obj.addConfigurationSetting('frameTrackerDuration', settings('frameTrackerDuration'));
            obj.addConfigurationSetting('colorMode', settings('projectorColorMode'), 'isReadOnly', true);
            obj.addConfigurationSetting('numberOfPatterns', 1);
            obj.addConfigurationSetting('backgroundPatternMode', 'noPattern');
            obj.addConfigurationSetting('backgroundIntensity', 0); % also pattern 1 if contrast mode
            obj.addConfigurationSetting('backgroundIntensity2', 0)
            obj.addConfigurationSetting('backgroundPattern', 1);
            obj.addConfigurationSetting('laserCorrectionSize', [0,0]); %central region to remove background, for imaging
            obj.addConfigurationSetting('laserCorrectionIntensity', 0);
            obj.addConfigurationSetting('laserCorrectionIntensity2', 0);
            obj.addConfigurationSetting('imageOrientation',obj.orientation, 'isReadOnly', true);
            obj.addConfigurationSetting('angleOffset', settings('angleOffset'));
            
            obj.addResource('fitBlue', settings('fitBlue'));
            obj.addResource('fitGreen', settings('fitGreen'));
            obj.addResource('fitUV', settings('fitUV'));
            obj.addResource('spectralOverlap_Blue', settings('spectralOverlap_Blue'));
            obj.addResource('spectralOverlap_Green', settings('spectralOverlap_Green'));
            obj.addResource('spectralOverlap_UV', settings('spectralOverlap_UV'));
            obj.addResource('blankingFactor', settings('blankingFactor'));

                        
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
            obj.setConfigurationSetting('canvasTranslation', t + obj.baseTranslation);
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

        function setLaserCorrection(obj, width, height, intensity1, intensity2)
            obj.setConfigurationSetting('laserCorrectionSize',[width, height]);
            obj.setConfigurationSetting('laserCorrectionIntensity', intensity1);
            obj.setConfigurationSetting('laserCorrectionIntensity2',intensity2)
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
            
            
            %TODO: change this to correct contrast

            laserCorrection = sa_labs.util.SubtractiveRectangle();
            laserCorrection.size = obj.getConfigurationSetting('laserCorrectionSize');
            laserCorrection.position = canvasSize/2 - canvasTranslation;
            laserCorrection.opacity = 1;
            laserCorrectionIntensity = obj.getConfigurationSetting('laserCorrectionIntensity');
            laserCorrectionIntensity2 = obj.getConfigurationSetting('laserCorrectionIntensity2');
            

            mode = obj.getConfigurationSetting('backgroundPatternMode');
            intensity1 = obj.getConfigurationSetting('backgroundIntensity');
            intensity2 = obj.getConfigurationSetting('backgroundIntensity2');
            backgroundPattern = obj.getConfigurationSetting('backgroundPattern');
           
            switch mode
                case 'noPattern'
                    background.color = intensity1;
                    laserCorrection.color = laserCorrectionIntensity;
                    
                case 'singlePattern'
                    background.color = intensity1;
                    backgroundPatternController = stage.builtin.controllers.PropertyController(background, 'opacity',...
                        @(state)(1 * (state.pattern == backgroundPattern - 1)));
                    presentation.addController(backgroundPatternController);

                    if any(laserCorrection.size)
                        laserCorrection.color = laserCorrectionIntensity;
                        laserCorrectionPatternController = stage.builtin.controllers.PropertyController(laserCorrection, 'opacity',...
                        @(state)(1 * (state.pattern == backgroundPattern - 1)));
                        presentation.addController(laserCorrectionPatternController);
                    end

                case 'twoPattern'
                    backgroundPatternController = stage.builtin.controllers.PropertyController(background, 'color',...
                        @(state)(intensity1 * (state.pattern == 0) + intensity2 * (state.pattern == 1)));
                    presentation.addController(backgroundPatternController);
                    
                    if any(laserCorrection.size)
                        laserCorrectionPatternController = stage.builtin.controllers.PropertyController(background, 'color',...
                            @(state)(laserCorrectionIntensity1 * (state.pattern == 0) + laserCorrectionIntensity2 * (state.pattern == 1)));
                        presentation.addController(laserCorrectionPatternController);
                    end

            end
            if any(laserCorrection.size)
            presentation.addStimulus(laserCorrection); %insert the laserCorrection in front of the stimulus
            end
            presentation.insertStimulus(1, background);
            
            % FRAME TRACKER
            % tracker = stage.builtin.stimuli.Rectangle();
            frameTrackerBackgroundSize = obj.getConfigurationSetting('frameTrackerBackgroundSize');
            frameTrackerSize = obj.getFrameTrackerSize();
            frameTrackerArea = frameTrackerSize(1) * frameTrackerSize(2);

            trackerBackground = stage.builtin.stimuli.Rectangle();
            trackerBackground.size = frameTrackerBackgroundSize;
            trackerBackground.position = obj.getFrameTrackerPosition() - canvasTranslation;
            trackerBackground.color = 0;

            tracker = stage.builtin.stimuli.Rectangle();
            tracker.size = frameTrackerSize;
            tracker.position = obj.getFrameTrackerPosition() - canvasTranslation;
            tracker.color = 1.0;
            
            presentation.addStimulus(trackerBackground);
            presentation.addStimulus(tracker);
            % appears on all patterns

            % trackerDuration = obj.getFrameTrackerDuration();
            frameRate = obj.getFrameRate();

            % trackerOpacity = stage.builtin.controllers.PropertyController(tracker, 'color', ...
            %     @(s) s.time < trackerDuration);% && s.time < (presentation.duration - (1/frameRate))); % mod(s.frame, 2) &&
            % presentation.addController(trackerOpacity);

            trackerOpacity = stage.builtin.controllers.PropertyController(tracker, 'opacity', ...
                @(s) 1.0*(s.time < (presentation.duration - (1/frameRate))));
            presentation.addController(trackerOpacity);
            
            % trackerSize = stage.builtin.controllers.PropertyController(tracker, 'opacity', ...
            %     @(s) (s.frame == 0)*.75 + (mod(s.frame,4)==0)*.25 + (mod(s.frame,4)==3)*.125 + (mod(s.frame,4)==3)*.375);
            
            xy_yx = [frameTrackerSize(1)/frameTrackerSize(2) frameTrackerSize(2)/frameTrackerSize(1)];
            function sz = resizeFrameTracker(s)
                if s.frame == 0
                    sz = frameTrackerSize;
                    return;
                end
                framei = mod(s.frame, 4);
                A = (framei==0) .* .5 + (framei==2) * .375 + (framei==3) * .125;
                sz = sqrt(A* xy_yx * frameTrackerArea) ;
            end
            trackerSize = stage.builtin.controllers.PropertyController(tracker, 'size', ...
                @(s) resizeFrameTracker(s));
            presentation.addController(trackerSize);
            
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
            try
                obj.lightCrafter.setPatternAttributes(bitDepth, color, numPatterns)
            catch
                obj.connect();
                obj.lightCrafter.setPatternAttributes(bitDepth, color, numPatterns)
            end
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
        
        function obj = connect(obj)
            obj.lightCrafter.connect();
            %TODO: set parallel RGB, 24bit?
            obj.lightCrafter.setMode('pattern');
            obj.lightCrafter.setImageOrientation(obj.orientation(1),obj.orientation(2));
        end
    end
    
end

