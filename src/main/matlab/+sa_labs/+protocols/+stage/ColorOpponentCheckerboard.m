classdef ColorOpponentCheckerboard < sa_labs.protocols.StageProtocol
    
    properties
        %times in ms
        preTime = 500	% Texture leading duration (ms)
        stimTime = 1000	% Texture duration (ms)
        tailTime = 1000	% Texture trailing duration (ms)
                
        textureSize = 200; % um
        numberOfPixels = uint16(80);
        numberOfEpochs = 24;
        
        maxIntensity1 = 1;
        maxIntensity2 = 1;

    end
    
    properties (Hidden)
        version = 1;
        responsePlotMode = false;

    end
    
    properties (Dependent)
        totalNumEpochs
        pixelSize %the size of a texture pixel in microns
    end
    
    methods

        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            
            switch name
                case {'colorCombinationMode', 'contrast1', 'contrast2', 'RstarMean','colorPattern3'}
                    d.isHidden = true;
                case {'meanLevel1', 'meanLevel2'}
                    d.isHidden = false;
                case {'RstarIntensity1', 'RstarIntensity2', 'MstarIntensity1', 'MstarIntensity2', 'SstarIntensity1', 'SstarIntensity2'}
                    d.isHidden = false;
                    d.displayName = [d.displayName(1), '* mean ', d.displayName(end)];
            end
        end

        function obj = ColorOpponentCheckerboard(obj)
            obj@sa_labs.protocols.StageProtocol();
            obj.colorCombinationMode = 'contrast';
            obj.colorPattern1 = 'green';
            obj.colorPattern2 = 'uv';
        end

        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            maxIntensity = obj.maxIntensity1;
            obj.maxIntensity1 = maxIntensity;
            if maxIntensity ~= obj.maxIntensity1
                warning('Adjusted max intensity of pattern 1 to %f', obj.maxIntensity1);
            end

            maxIntensity = obj.maxIntensity2;
            obj.maxIntensity2 = maxIntensity;
            if maxIntensity ~= obj.maxIntensity2
                warning('Adjusted max intensity of pattern 2 to %f', obj.maxIntensity2);
            end
        end
        
        function prepareEpoch(obj, epoch)
           
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime)*1e-3);
            % TODO: 
            %   We should reference the selected patterns against the leds on the rig to set the color planes correctly
            %   Should we adjust the intensities so that the actual mean is equal to the background?
            %   What to do about 'pixel sizes' smaller than the projector resolution?
            %   Save seed as a parameter? Can we possibly use the epoch block start time + epoch num as a default seed?
            %       check what info is available under epoch... note epochs don't necessarily have an epoch block

            % Lara: for white noise stimulation, it would be good to match the mean intensity to that of the mouse movie, which is approximately 37 (in the range from 0 to 255)
            % ranging from 0-255, should map onto a stimulator intensity range from ~.5 * 10³ to 20 * 10³ P* per s per cone

            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            textureDimPix = obj.um2pix(obj.textureSize); % Convert texture size from microns to pixels
            minIntensity1 = 2*obj.meanLevel1 - obj.maxIntensity1;
            minIntensity2 = 2*obj.meanLevel2 - obj.maxIntensity2;

            Im = single(rand(obj.numberOfPixels,obj.numberOfPixels,3,'single') > .5);

            Im(:,:,1) = Im(:,:,1)*(obj.maxIntensity1 - minIntensity1) + minIntensity1;
            Im(:,:,2) = Im(:,:,2)*(obj.maxIntensity2 - minIntensity2) + minIntensity2;

            Im(:,:,3) = 0;


            tex = stage.builtin.stimuli.Image(Im);
            tex.color = 1;
            tex.opacity = 1;
            tex.position = canvasSize / 2;
            tex.size = [textureDimPix, textureDimPix];
            tex.setMagFunction(GL.NEAREST);%% == 9728
            
            p.addStimulus(tex);
            obj.setOnDuringStimController(p, tex);

        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end

        function pixelSize = get.pixelSize(obj)
            pixelSize = obj.textureSize / obj.numberOfPixels;
        end

        % this is already done by the stage protocol...
        % function obj = set.textureSize(obj, size)
        %     %force an integer number of pixels on the projector
        %     % (technically this operates on the canvas?)
        %     obj.textureSize = obj.pix2um(round(obj.um2pix(obj.textureSize)));
        % end

        % max intensities are bounded between the mean level and 1
        % further the max intensity cannot exceed twice the mean, otherwise we can't make a uniform distribution with the same mean
        function obj = set.maxIntensity1(obj, maxIntensity)
            obj.maxIntensity1 = min(1, min(max(obj.meanLevel1, maxIntensity), obj.meanLevel1 * 2));
        end

        function obj = set.maxIntensity2(obj, maxIntensity)
            obj.maxIntensity2 = min(1, min(max(obj.meanLevel2, maxIntensity), obj.meanLevel2 * 2));
        end

        % function obj = set.meanLevel1(obj, meanLevel)
        %     obj.maxIntensity1 = min(obj.maxIntensity1, meanLevel * 2);
        %     obj.meanLevel1 = meanLevel;
        % end

        % function obj = set.meanLevel2(obj, meanLevel)
        %     obj.maxIntensity2 = min(obj.maxIntensity2, meanLevel * 2);
        %     obj.meanLevel2 = meanLevel;
        % end
    end
end

