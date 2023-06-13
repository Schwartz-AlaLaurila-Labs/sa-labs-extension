classdef SpatialNoiseFigure < symphonyui.core.FigureHandler
    
    properties
        device
        ampMode

        spikeThreshold
        spikeDetectorMode
        spikeRateBinLength
        totalNumEpochs
        epochData
        spikeDetector
        epochCount
        sampleRate
        
        % preTime
        % stimTime
        % tailTime
        
        % timebase
        rawTimebase
        ampUnits
        
        topAxis
        topPlot
        topRaster
        
        bottomAxis
        rfMap

        %% spatial noise params
        nFrames
        preFrames
        stimFrame
        tailFrames
        frameRate

        dimensions
        colorNoiseDistribution
        colorNoiseMode
        frameDwell
        meanLevel
        contrast

        spatialSubsample
        temporalSubsample
        memory

        spikeCount
        STA

    end

    properties (Hidden)
        mat
    end
    
    methods
        function obj = SpatialNoiseFigure(device, ampMode, varargin)
            obj = obj@symphonyui.core.FigureHandler();
            
            ip = inputParser();
            ip.addParameter('spikeDetectorMode',@(x)ischar(x));
            ip.addParameter('spikeThreshold', 0, @(x)isnumeric(x));
            ip.addParameter('spikeRateBinLength', 0.05, @(x)isnumeric(x));
            ip.addParameter('totalNumEpochs',1,@(x)isnumeric(x));
            ip.addParameter('preTime',1.0,@(x)isnumeric(x));
            ip.addParameter('stimTime',1.0,@(x)isnumeric(x));
            ip.addParameter('tailTime',1.0,@(x)isnumeric(x));
            ip.addParameter('frameRate',60.0,@(x)isnumeric(x));

            ip.addParameter('meanLevel',1.0,@(x)isnumeric(x));
            ip.addParameter('contrast',1.0,@(x)isnumeric(x));


            ip.addParameter('dimensions',[4,4]);
            ip.addParameter('spatialSubsample',[1,1]);
            ip.addParameter('temporalSubsample',10);
            ip.addParameter('memory',30);
            ip.addParameter('colorNoiseDistribution','binary');
            ip.addParameter('colorNoiseMode','1 pattern');
            ip.addParameter('frameDwell', 1);           
                       

            ip.parse(varargin{:});
            
            
            obj.device = device;
            obj.ampMode = ampMode;

            obj.spikeThreshold = ip.Results.spikeThreshold;
            obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            obj.spikeRateBinLength = ip.Results.spikeRateBinLength;
            obj.totalNumEpochs = ip.Results.totalNumEpochs;
            
            frameRate = ip.Results.frameRate;
            obj.preFrames = ip.Results.preTime * frameRate;
            obj.stimFrames = ip.Results.stimTime * frameRate;
            obj.tailFrames = ip.Results.tailTime * frameRate;
            obj.nFrames = obj.preFrames + obj.stimFrames + obj.tailFrames;

            obj.dimensions = ip.Results.dimensions;
            obj.colorNoiseDistribution = ip.Results.colorNoiseDistribution;
            obj.colorNoiseMode = ip.Results.colorNoiseMode;
            obj.frameDwell = ip.Results.frameDwell;
            obj.meanLevel = ip.Results.meanLevel;
            obj.contrast = ip.Results.contrast;

            obj.spatialSubsample = ip.Results.spatialSubsample;
            obj.temporalSubsample = ip.Results.temporalSubsample;
            obj.memory = ip.Results.memory;            

            obj.createUi();
            
            % obj.epochData = {};
            emp = cell(1, obj.totalNumEpochs);
            obj.epochData = struct(...
                'responseObject', emp, ...
                'rawSignal', emp, ...
                ...% 'units', emp, ...
                ...% 'sampleRate', emp, ...
                'spikeIndices', emp);%, ...
            % 'spikeTimes', emp);
            
            obj.spikeDetector = sa_labs.util.SpikeDetector(obj.spikeDetectorMode, obj.spikeThreshold);
            
            
            obj.epochCount = 0;
            % obj.timebase = [];
            obj.rawTimebase = [];
            % obj.ampUnits = cell(obj.numChannels,1);
            obj.ampUnits = '';

            obj.STA = zeros(obj.dimensions(1) * obj.spatialSubsample(1), obj.dimensions(2) * obj.spatialSubsample(2), obj.memory);
            obj.tmat = zeros([obj.dimensions(1), obj.dimensions(2), obj.nFrames]);
            obj.mat = zeros([obj.dimensions(1) * obj.spatialSubsample(1), obj.dimensions(2) * obj.spatialSubsample(2), obj.nFrames*obj.temporalSubsample]);
        end
        
        function createUi(obj)
            import appbox.*;
            
            set(obj.figureHandle, 'Name', sprintf('Spatial Noise Figure: %s', obj.devices{1}.name));
            
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            fullBox = uix.VBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
            topBox = uix.HBox('Parent', fullBox, 'Spacing', 10);
            bottomBox = uix.HBox('Parent', fullBox, 'Spacing', 10);
            
            obj.topAxis = axes('Parent', topBox);
            hold(obj.topAxis,'on');
            set(obj.topAxis,'LooseInset',get(obj.topAxis,'TightInset'))
            
            obj.topPlots = plot(obj.topAxis, 0, 0);
            obj.topRaster = plot(obj.topAxis,[]);

            obj.bottomAxis = axes('Parent', bottomBox);
            set(obj.bottomAxis,'LooseInset',get(obj.bottomAxis,'TightInset'))
        
            obj.rfMap = imagesc(obj.bottomAxis,obj.STA(:,:,1));        
            
        end
        
        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            if obj.epochCount > obj.totalNumEpochs
                % we've finished the first epoch block
                obj.totalNumEpochs = obj.epochCount;
            end
            
            if epoch.hasResponse(obj.devices{ci}) % TODO: this should always happen?    
                obj.epochData(obj.epochCount).responseObject = epoch.getResponse(obj.device);                    
                [obj.epochData(obj.epochCount).rawSignal,~] = obj.epochData(obj.epochCount).responseObject.getData();

                if isempty(obj.ampUnits)
                    obj.sampleRate = obj.epochData(obj.epochCount).responseObject.sampleRate.quantityInBaseUnits;
                    responseLength = length(obj.epochData(obj.epochCount).rawSignal);
                        
                    obj.rawTimebase = (0:responseLength-1) / obj.sampleRate; % in seconds
                    
                    set(obj.topPlot, 'xdata', obj.rawTimebase,'ydata', obj.epochData(obj.epochCount).rawSignal);
                    ylabel(obj.topAxis, obj.ampUnits, 'Interpreter', 'none');
                end
                
                if strcmp(obj.ampModes{ci}, 'Whole cell')
                else
                    % Extract spikes from signal
                    result = obj.spikeDetector.detectSpikes(obj.epochData(obj.epochCount).rawSignal);
                    obj.epochData(obj.epochCount).spikeIndices = result.sp;


                    %% Update RF map

                    noiseStream = RandStream('mt19937ar', 'Seed', obj.epochData(obj.epochCount).noiseSeed);
                    
                    switch obj.colorNoiseDistribution
                        case 'uniform'
                            noiseFn = @(x) 2 * noiseStream.rand(x) - 1;
                        case 'gaussian'
                            noiseFn = @(x) noiseStream.randn(x);
                        case 'binary'
                            noiseFn = @(x) 2 * (noiseStream.rand(x) > .5) - 1;
                    end
                    
                    if strcmp(obj.colorNoiseMode, '1 pattern')
                        for i = 1:obj.nFrames
                            frame = i - obj.preFrames - 1; %frame counter starts at 0
                            obj.tmat(:,:,i) = getImageMatrix(frame, obj.dimensions, obj.frameDwell, obj.meanLevel(1), obj.contrast, noiseFn);
                        end
                    else
                        warning('Plotting for 2 color mode not yet implemented');
                        for i = 1:obj.nFrames
                            frame = i - obj.preFrames - 1;
                            obj.tmat(:,:,i) = getImageMatrix2Pattern(frame, 1, obj.dimensions, obj.frameDwell, obj.meanLevel(1), obj.contrast(1), obj.meanLevel(2), obj.contrast(2), noiseFn);

                            %need to get the second pattern to advance the seed
                            getImageMatrix2Pattern(frame, 2, obj.dimensions, obj.frameDwell, obj.meanLevel(1), obj.contrast(1), obj.meanLevel(2), obj.contrast(2), noiseFn);
                            
                        end
                    end

                    % subsample the matrix... 
                    obj.mat(:) = reshape(repmat(reshape(...
                        obj.tmat, [obj.dimensions(1), 1, obj.dimensions(2), 1, obj.nFrames]), [1, obj.spatialSubsample(1), 1, obj.spatialSubsample(2), 1, obj.temporalSubsample]),...
                        [obj.dimensions(1)*obj.spatialSubsample(1), obj.dimensions(2)*obj.spatialSubsample(2), obj.nFrames*obj.temporalSubsample]);
                    
                    if (obj.spatialSubsample(1) ~= 1) && (obj.spatialSubsample(2) ~= 1)
                        offsetStream = RandStream('mt19937ar', 'Seed', obj.epochData(obj.epochCount).offsetSeed);
                        for i = 1:obj.nFrames
                            frame = i - obj.preFrames - 1;
                            p = getPosition(frame, 0, obj.frameDwell, obj.spatialSubsample, offsetStream);
                            %position ranges from -maxOffset to + maxOffset in increments of offsetDelta
                            %but we could make this more convenient if required...

                            obj.mat(:,:,i) = circshift(obj.mat(:,:,i), p(1), 1);
                            obj.mat(:,:,i) = circshift(mobj.at(:,:,i), p(2), 2);

                            if p(1) > 0
                                obj.mat(1:p(1),:,i) = obj.meanLevel(1);
                            else
                                obj.mat(end + p(1): end,:,i) = obj.meanLevel(1);
                            end

                            if p(2) > 0
                                obj.mat(:,1:p(2),i) = obj.meanLevel(1);
                            else
                                obj.mat(:,end + p(2): end,i) = obj.meanLevel(1);
                            end
                        end
                    end
                    
                    for sp = obj.epochData(obj.epochCount).spikeIndices
                        t = floor(sp / obj.sampleRate * obj.frameRate * obj.temporalSubsample);
                        if (t-obj.memory) < 0
                        else
                            obj.STA = obj.STA + obj.mat(:,:,(t - obj.memory):t);
                        end
                    end

                    obj.spikeCount = obj.spikeCount + length(obj.epochData(obj.epochCount).spikeIndices);

                end
            end
            obj.redrawPlots(epoch);
        end
        
        function redrawPlots(obj, epoch)
            if isempty(obj.epochData)
                return
            end
            
            title(obj.topAxis, sprintf('Epoch %d of %d', obj.epochCount, obj.totalNumEpochs));        
            %plot raw responses
            set(obj.topPlot, 'ydata', obj.epochData(obj.epochCount).rawSignal);
            yl = get(obj.topAxis,'ylim');
            
            if strcmp(obj.ampMode, 'Cell attached')
                spikeTimes = obj.rawTimebase(obj.epochData(obj.epochCount).spikeIndices); %1-by-N, (0,35]
                delete(obj.topRaster);

                if size(spikeTimes,1) > 1
                    spikeTimes = spikeTimes'; %TODO: just not sure what shape this is, this shouldn't be necessary
                end
                spikeOnes = ones(size(spikeTimes));                
                obj.topRaster = line(obj.topAxis, [spikeTimes;spikeTimes], [yl(1)*spikeOnes;yl(2)*spikeOnes], color, 'k'); %one line per column
                
                % now, do the RF map
                %possibly also plot the temporal kernel??

                [c,s,l] = pca(reshape(obj.STA,[],obj.memory)');
                    
                rf = reshape(c(:,1), size(obj.STA,1), size(obj.STA,2));
                set(rfmap,'cdata', rf);
                %TODO: set rfmap.cdata to rf
                % tkernel = s(:,1);

                
            end            
        end
    end
end


function p = getPosition(frame, pattern, frameDwell, spatialSubsample, offsetStream)
    persistent position;
    if frame<0 %pre frames. frame 0 starts stimPts
        position = [0,0];
    elseif pattern == 0 %only want to move once per update?
        if mod(frame, frameDwell) == 0 %noise update
            % position = offsetStream.randi(2*spatialSubsample - 1,1,2) - spatialSubsample; %
            position = [offsetStream.randi(2*spatialSubsample(1) - 1) - spatialSubsample(1), offsetStream.randi(2*spatialSubsample(2) - 1) - spatialSubsample(2)]; %
        end
    end
    p = position;
end

% TODO: verify X vs Y in matrix

function i = getImageMatrix(frame, dimensions, frameDwell, meanlevel, contrast, noiseFn)
    persistent intensity;
    if frame < 0 %pre frames. frame 0 starts stimPts
        intensity = meanLevel;
        intensity = clipIntensity(intensity, meanLevel);
    else %in stim frames
        if mod(frame, frameDwell) == 0 %noise update
            intensity = meanLevel + ... 
                contrast * meanLevel * noiseFn(dimensions);
            intensity = clipIntensity(intensity, meanLevel);
        end
    end
%                 intensity = imgaussfilt(intensity, 1);
    i = intensity;
end
           

function i = getImageMatrix2Pattern(frame, pattern, dimensions, frameDwell, meanLevel1, contrast1, meanLevel2, contrast2, noiseFn)
    persistent intensity;
    if isempty(intensity)
        intensity = cell(2,1);
    end
    if pattern == 1
        mn = meanLevel1;
        c = contrast1;
    else
        mn = meanLevel2;
        c = contrast2;
    end
    
    if frame<0 %pre frames. frame 0 starts stimPts
        intensity{pattern} = mn;                    
        intensity{pattern} = clipIntensity(intensity{pattern}, mn);
    else %in stim frames
        if mod(frame, frameDwell) == 0 %noise update
            intensity{pattern} = mn + c * mn * noiseFn(dimensions);                        
            intensity{pattern} = clipIntensity(intensity{pattern}, mn);
        end
    end

    i = intensity{pattern};
end


function intensity = clipIntensity(intensity, mn)
    intensity(intensity < 0) = 0;
    intensity(intensity > mn * 2) = mn * 2;
    intensity(intensity > 1) = 1;
    intensity = uint8(255 * intensity);
end