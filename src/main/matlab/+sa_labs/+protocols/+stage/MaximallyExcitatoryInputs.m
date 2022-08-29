classdef MaximallyExcitatoryInputs < sa_labs.protocols.StageProtocol
    % TODO:
    %   - colors
    %       - check our LED spectra vs. theirs (silent substitution?)
    %       - consider luminance level
    %   - scaling
    %  - stage.builtin.stimuli.Movie(filename)

    properties
        preTime = 500
        tailTime = 500
        
        numberOfRepetitions = 10;

        % playbackSpeed = 1; %speed of the video relative to the original

        ventralUp = false;

        randomOrdering = true;

        % UVIntensity = 1;
        % greenIntensity = 1;
    end

    properties (Hidden)
        version = 1;
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'MEI';
        moviePath = 'C:\\stage_movies\\meis\\%d.avi';
        order;
        MEI;
    end
    
    properties (Dependent)
        stimTime
        totalNumEpochs
    end
    
    methods

        function obj = MaximallyExcitatoryInputs(obj)
            obj@sa_labs.protocols.StageProtocol();
            obj.colorCombinationMode = 'contrast';
            obj.meanLevel1 = 70/255;
            obj.meanLevel2 = 94/255;
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
                case {'stimTime','meanLevel1','meanLevel2','colorCombinationMode', 'contrast1', 'contrast2', 'colorPattern1','colorPattern2','colorPattern3','primaryObjectPattern','secondaryObjectPattern','backgroundPattern','numberOfPatterns'}
                    d.isReadOnly = true;
                case {'RstarIntensity1', 'RstarIntensity2', 'MstarIntensity1', 'MstarIntensity2', 'SstarIntensity1', 'SstarIntensity2'}
                    d.isHidden = false;
                    d.displayName = [d.displayName(1), '* mean ', d.displayName(end)];
            end
        end

        function prepareRun(obj, epoch)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            obj.order = [28,24,1,5,10,18,20,21,23,31,32];
        end

        function prepareEpoch(obj, epoch)
            
            index = mod(obj.numEpochsPrepared, length(obj.order)) + 1;
            if index == 1 && obj.randomOrdering
                obj.order = obj.order(randperm(length(obj.order)));
            end

            obj.MEI = obj.order(index);
            epoch.addParameter('MEI', obj.MEI);            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end

        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime)*1e-3);
            mov = sa_labs.util.PatternMovie(sprintf(obj.moviePath, obj.MEI));
            mov.channel = 2;

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

            mask = stage.builtin.stimuli.Rectangle();
            mask.size = mov.size;
            mask.position = mov.position;
            % mask.color = [0,70/255, 94/255];

            % function c = onDuringStim(state, preTime, stimTime)
            %     c = 1 * (state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3);
            % end
            preTime = obj.preTime;
            stimTime = obj.stimTime;
            maskController = stage.builtin.controllers.PropertyController(mask,'opacity',...
                @(state)  - 1 * (state.time>ceil(preTime*1e-3) && state.time<floor((preTime+stimTime)*1e-3)) + 1);
            
            maskControllerC = stage.builtin.controllers.PropertyController(mask, 'color',...
                @(state) (state.pattern==0) * 70/255 + (state.pattern==1) * 94/255);
            
            % intensity range from ~.5 * 10³ to 20 * 10³ P*
            %mean is ~ 14.1% of max
            %range is 19.5e3 P*
            %so mean is 3.25e3 P*

            preFrames = round(obj.frameRate * (obj.preTime/1e3));
            
            channelController = stage.builtin.controllers.PropertyController(mov,'channel',...
                @(state) state.pattern + 2);

            %movies are at 
            frameController = stage.builtin.controllers.PropertyController(mov,'nextFrame',...
                @(state) min(max((state.frame - preFrames) / relSpeed, 1), 50));
            stimController = stage.builtin.controllers.PropertyController(mask,'opacity',...
            @(state)  1 * (state.time>ceil(preTime*1e-3) && state.time<floor((preTime+stimTime)*1e-3)));
        
            p.addController(maskController);
            p.addController(maskControllerC);

            p.addController(channelController);
            p.addController(frameController);
            p.addController(stimController);

            p.addStimulus(mov);
            p.addStimulus(mask);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfRepetitions * 11;
        end

        function stimTime = get.stimTime(obj)
            stimTime = 50/30 * 1e3;
        end

        % function preTime = get.preTime(obj)
        %     preTime = 0;
        % end
    end
end

