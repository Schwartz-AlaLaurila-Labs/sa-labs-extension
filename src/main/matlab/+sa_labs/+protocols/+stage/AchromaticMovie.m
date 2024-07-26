classdef AchromaticMovie < sa_labs.protocols.StageProtocol

    properties
        preTime = 500; % (ms)
        tailTime = 500; % (ms)
        width = 1000; % (um)
        height = 1000; % (um)
        intensity = 1.0;    
        numberOfRepetitions = 10;
        preloading = true; % If true, loads entire movie into memory before playing, which helps prevent dropped frames but may fail for longer movies
        movieFolder = 'D:\\stage_movies'; % Absolute location of movies
        movieFileName = 'tmp.avi';
        movieChannel = 1; % channel of movie (1 = red, 2 = green, 3 = blue) to play as colorPattern1

    end

    properties (Hidden)
        version = 1;
        responsePlotMode
    end
    
    properties (Dependent)
        stimTime
        totalNumEpochs
    end
    
    methods

        function obj = AchromaticMovie(obj)
            obj@sa_labs.protocols.StageProtocol();
            obj.colorPattern2 = 'none';
            obj.colorPattern3 = 'none';
%             obj.NDF = 0.5;
%             obj.uvLED = 255;
%             obj.blueLED = 0;
%             obj.greenLED = 255;
        end

        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case {'colorPattern2','colorPattern3'}
                    d.isReadOnly = true;
            end
        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime)*1e-3);
          
            % mov = stage.builtin.stimuli.Movie(sprintf('%s%s%s', obj.movieFolder, filesep, obj.fileName));
            mov = sa_labs.util.PatternMovie(sprintf('%s%s%s', obj.movieFolder, filesep, obj.movieFileName));
            mov.color = obj.intensity;
            mov.opacity = 1;
            mov.channel = obj.movieChannel;
            
            % the movie should be clipped at the edges
            mov.setWrapModeS(GL.CLAMP_TO_EDGE);
            mov.setWrapModeT(GL.CLAMP_TO_EDGE);

            % if desired, preload the entire movie into memory
            mov.setPreloading(obj.preloading);

            % mov.setPlaybackSpeed(PlaybackSpeed.NORMAL); %if frames are dropped, skip the frame and continue playing the video. Preserves duration of movie.
            mov.setPlaybackSpeed(PlaybackSpeed.FRAME_BY_FRAME); %if frames are dropped, try to redraw the frame. Preserves frame order but not duration.
            % NOTE: PlaybackSpeed.NORMAL has not been thoroughly tested
            
            % position the movie over the center of the canvas
            mov.position = obj.rig.getDevice('Stage').getCanvasSize() / 2;
            
            % scale the movie to the desired size
            mov.size = [obj.um2pix(obj.width), obj.um2pix(obj.height)];
            mov.setMinFunction(GL.LINEAR); %interpolates between pixels by blurring
            mov.setMagFunction(GL.LINEAR); %interpolates between pixels by blurring
            % mov.setMinFunction = GL.NEAREST; %interpolates between pixels by selecting the value of one neighbor
            % mov.setMagFunction = GL.NEAREST; %interpolates between pixels by selecting the value of one neighbor
            
            % NOTE: we assume that the frame rate of the movie is already matched to the frame rate of the projector

            % 
            mask = stage.builtin.stimuli.Rectangle();
            mask.color = obj.meanLevel;
            mask.size = mov.size;
            mask.position = mov.position;
            preTime = obj.preTime;
            stimTime = obj.stimTime;

            maskController = stage.builtin.controllers.PropertyController(mask,'opacity',...
                @(state)  ((-1.0) * (state.time>preTime*1e-3 && state.time<(preTime+stimTime)*1e-3)) + 1.0);        
            p.addController(maskController);

            preFrames = round(obj.frameRate * (obj.preTime/1e3));
            nFrames = obj.frameRate * (obj.stimTime/1e3);

            frameController = stage.builtin.controllers.PropertyController(mov,'nextFrame',...
                @(state) min(max((state.frame - preFrames), 1), nFrames));
            p.addController(frameController);

            p.addStimulus(mov);
            p.addStimulus(mask);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfRepetitions;
        end

        function stimTime = get.stimTime(obj)
            fname = sprintf('%s%s%s', obj.movieFolder, filesep, obj.movieFileName);
            if exist(fname, 'file')
                s = VideoSource(fname);
                stimTime = s.duration / 1e3; % microseconds -> milliseconds
            else
                stimTime = 0;
            end
        end
     end
end