classdef MaximallyDiscriminatingStimulus < sa_labs.protocols.StageProtocol
    % TODO:
    %   - colors
    %       - check our LED spectra vs. theirs (silent substitution?)
    %       - consider luminance level
    %   - scaling
    %  - stage.builtin.stimuli.Movie(filename)

    properties
        tailTime = 500

        moviePath = 'C:\stage_movies\recon_group_mdi_24_over_28.avi';
        
        numberOfEpochs = 24;

        % playbackSpeed = 1; %speed of the video relative to the original

        ventralUp = false;

        % UVIntensity = 1;
        % greenIntensity = 1;
    end

    properties (Hidden)
        version = 1;
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = '';
    end
    
    properties (Dependent)
        preTime
        stimTime
        totalNumEpochs
    end
    
    methods

        function obj = MaximallyDiscriminatingStimulus(obj)
            obj@sa_labs.protocols.StageProtocol();
            obj.colorCombinationMode = 'contrast';
            obj.meanLevel1 = 36/255;
            obj.meanLevel2 = 37/255;
            obj.colorPattern1 = 'green';
            obj.colorPattern2 = 'uv';
        end

        function didSetRig(obj)
            didSetRig@sa_labs.protocols.StageProtocol(obj);
            obj.colorPattern1 = 'green';
            obj.colorPattern2 = 'uv';
        end

        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case {'preTime','stimTime','meanLevel1','meanLevel2','colorCombinationMode', 'contrast1', 'contrast2', 'colorPattern1','colorPattern2','colorPattern3','primaryObjectPattern','secondaryObjectPattern','backgroundPattern','numberOfPatterns'}
                    d.isReadOnly = true;
                case {'RstarIntenssity1', 'RstarIntensity2', 'MstarIntensity1', 'MstarIntensity2', 'SstarIntensity1', 'SstarIntensity2'}
                    d.isHidden = false;
                    d.displayName = [d.displayName(1), '* mean ', d.displayName(end)];
            end
        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime)*1e-3);
            mov = sa_labs.util.PatternMovie(obj.moviePath);
            mov.setWrapModeS(GL.CLAMP_TO_EDGE);
            mov.setWrapModeT(GL.CLAMP_TO_EDGE);
            mov.position = obj.rig.getDevice('Stage').getCanvasSize() / 2;
            mov.setPreloading(true); %the movies are tiny

            mov.size = [-obj.um2pix(50*16), obj.um2pix(50*18)*(obj.ventralUp*2-1)];
            %TODO: if n/t doesn't matter, we should just rotate it...

            % mov.color = [obj.UVIntensity, obj.greenIntensity, 0];
            % mov.color = 1;
            % mov.setPlaybackSpeed(obj.playbackSpeed);
            mov.setPlaybackSpeed(PlaybackSpeed.FRAME_BY_FRAME);

            lightCrafter = obj.rig.getDevice('LightCrafter');
            relSpeed = lightCrafter.getFrameRate() / 30;

            %50 frame duration
            %movies have no red channel, only green and blue


            % intensity range from ~.5 * 10³ to 20 * 10³ P*
            %mean is ~ 14.1% of max
            %range is 19.5e3 P*
            %so mean is 3.25e3 P*

            preFrames = round(obj.frameRate * (obj.preTime/1e3));

            channelController = stage.builtin.controllers.PropertyController(mov,'channel',...
                @(state) state.pattern + 2);

            %movies are at 
            frameController = stage.builtin.controllers.PropertyController(mov,'nextFrame',...
                @(state) floor((state.frame - preFrames) / relSpeed));
            p.addController(channelController);
            p.addController(frameController);

            p.addStimulus(mov);
            obj.setOnDuringStimController(p, mov);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end

        function stimTime = get.stimTime(obj)
            stimTime = 50/30 * 1e3;
        end

        function preTime = get.preTime(obj)
            preTime = 0;
        end
    end
end

