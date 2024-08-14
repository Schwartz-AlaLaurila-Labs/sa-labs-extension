classdef TextureNoise < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500 % ms
        stimTime = 30000 % ms
        tailTime = 500 % ms
        
        sizeX = 500 % um
        sizeY = 500 % um
    
        contrast = 1;
        
        seedStartValue = 1
        
        numSeeds = 1
        numRepeats = 1
        
        noisePowerDistribution = 2 %1/(freq)^n noise
        highPassSpatial = 0.01 % 1/mm        
        lowPassSpatial = 100 % 1/mm
        peakSpatialFrequency = 12.5 % 1/mm
        peakWidth = 4 % 1/mm
        peakAmplitude = 0.03

        temporalWidth = 3 % Hz
        highPassTemporal = 0.01 % Hz
        
    end
    
    properties (Transient)
        subsampleT = uint8(10) %number of time steps per frame to use for display
        RFMemory = uint8(120) %total number of time steps to use for display
    end
    
    properties (Hidden)
        version = 1;
        
        noiseStream
        seeds
        
        filt
        texs
        tex

        responsePlotMode = false;
        % responsePlotMode = 'cartesian';
        % responsePlotSplitParameter = 'noiseSeed';
    end
    
    properties (Dependent, Hidden)
        totalNumEpochs
    end
    
    methods
        function obj = TextureNoise()
            obj@sa_labs.protocols.StageProtocol();
            obj.contrast = 1;
            obj.meanLevel = 0.5;
        end
        function [fs,ft,filt_s,filt_t] = calcFilter(obj)
            % resX = obj.um2pix(obj.sizeX);
            % resY = obj.um2pix(obj.sizeY);
            resX = ceil(obj.lowPassSpatial * 3 / 1000 * obj.sizeX);
            resY = ceil(obj.lowPassSpatial * 3 / 1000 * obj.sizeY);


            nFrames = round(obj.frameRate * (obj.stimTime/1e3));
            ft = ((1:nFrames) - 1 - nFrames/2)/nFrames*obj.frameRate; %1/sec

            % [~,fy] = obj.um2pix(((1:resY) - 1 - resY/2)/resY); % 1/mm
            % [~,fx] = obj.um2pix(((1:resX) - 1 - resX/2)/resX); % 1/mm

            fy = ((1:resY) - 1 - resY/2)/obj.sizeY; % 1/mm
            fx = ((1:resX) - 1 - resX/2)/obj.sizeX; % 1/mm

            fy = fy * 1000;
            fx = fx * 1000;

            fs = sqrt(bsxfun(@plus,fy'.^2,fx.^2)); %backwards compatibility

            filt_s = (fs>obj.highPassSpatial & fs<obj.lowPassSpatial) .* (1./fs.^obj.noisePowerDistribution + obj.peakAmplitude * exp(-(fs-obj.peakSpatialFrequency).^2 ./ obj.peakWidth.^2));
            filt_s(fs==0) = 0;
            filt_t = exp(-(ft).^2./obj.temporalWidth.^2) .* (abs(ft) > obj.highPassTemporal);
            filt_t(ft==0) = 0;

            obj.filt = single(bsxfun(@times, filt_s, shiftdim(filt_t,-1)));
        end


        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            for ci = 1%:4
                ampName = obj.(['chan' num2str(ci)]);
                ampMode = obj.(['chan' num2str(ci) 'Mode']);
                if ~(strcmp(ampName, 'None') || strcmp(ampMode, 'Off'))
                    device = obj.rig.getDevice(ampName);
                    obj.showFigure('sa_labs.figures.TextureNoiseFigure', device, ampMode, ...
                        'totalNumEpochs', obj.totalNumEpochs,...
                        'preTime', obj.preTime,...
                        'stimTime', obj.stimTime,...
                        'tailTime', obj.tailTime,...
                        'frameRate', obj.frameRate,...
                        'extent', [obj.sizeY, obj.sizeX],...
                        'dimensions', obj.um2pix([obj.sizeY,obj.sizeX]),...
                        'getStimulus', @(seed) obj.texs{seed},...
                        'temporalSubsample', obj.subsampleT,...
                        'memory', obj.RFMemory,...
                        'spikeThreshold', obj.spikeThreshold, 'spikeDetectorMode', obj.spikeDetectorMode);
                end
            end

            obj.calcFilter();
            obj.texs = cell(obj.numSeeds,1);
        end
        
        function prepareEpoch(obj, epoch)
             
            %get seed
            index = mod(obj.numEpochsPrepared, obj.numSeeds) + 1;
            if index == 1
                obj.seeds = randperm(obj.numSeeds) + obj.seedStartValue - 1; 
            end
            
            if isempty(obj.texs{index}) %only generate the textures once
            
                % set the random stream for texture generation
                obj.noiseStream = RandStream('mt19937ar', 'Seed', obj.seeds(index));
                

                % generate texture from filter with random phase
                % this step takes ~5seconds for a 30second texture in testing on office PC with default params
                t = fftshift(fftn(randn(obj.noiseStream, size(obj.filt), 'single')));
                t = real(ifftn(ifftshift(t .* obj.filt)));
                t = (t - mean(t(:))) ./ std(t(:));
                t(t >  3) =  3;
                t(t < -3) = -3;
                t = uint8(((t * (obj.meanLevel * obj.contrast / 6)) + obj.meanLevel) * 255);

                obj.texs{index} = t;
            end
            epoch.addParameter('noiseSeed', obj.seeds(index));

            obj.tex =  obj.texs{index};
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
           
        
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3); %create presentation of specified duration
            preFrames = round(obj.frameRate * (obj.preTime/1e3));
            nFrames = round(obj.frameRate * (obj.stimTime/1e3));
            
            % texture is filled from top left (1,1)
            tex_ = obj.tex;

            resX = obj.um2pix(obj.sizeX);
            resY = obj.um2pix(obj.sizeY);
            texture = stage.builtin.stimuli.Image(uint8(zeros(size(tex_,1), size(tex_,2))));
            texture.position = canvasSize / 2;
            texture.size = [resX, resY];
            texture.setMinFunction(GL.NEAREST);
            texture.setMagFunction(GL.NEAREST);
            p.addStimulus(texture);
            

            % add controllers
            textureImageController = stage.builtin.controllers.PropertyController(texture, 'imageMatrix',...
                @(state) tex_(:,:, min(max(state.frame - preFrames,1),nFrames)));
                
            p.addController(textureImageController);
            
            obj.setOnDuringStimController(p, texture);            
        end

        function p = getPreview(self, panel)
            p = sa_labs.previews.TextureNoisePreview(panel, @self.calcFilter);
        end

        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numSeeds * obj.numRepeats;
        end
               
    end
end