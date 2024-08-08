classdef TextureNoiseFigure < symphonyui.core.FigureHandler
    
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
        
        middleAxis
        middlePlot
        
        bottomAxis
        rfMap
        rfFit
        rfText

        %% spatial noise params
        nFrames
        preFrames
        stimFrames
        tailFrames
        frameRate

        extent
        dimensions
        getStimulus
        
        temporalSubsample
        memory

        spikeCount
        STA

    end

    properties (Hidden)
        mat
        xy
        lastFit
        lb
        ub
    end
    
    methods
        function obj = TextureNoiseFigure(device, ampMode, varargin)
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


            ip.addParameter('extent',[300, 300]);
            ip.addParameter('dimensions',[300, 300]);
            ip.addParameter('temporalSubsample',10);
            ip.addParameter('memory',30);  

            ip.addParameter('getStimulus', @(x) x);

            ip.parse(varargin{:});
            
            
            obj.device = device;
            obj.ampMode = ampMode;

            obj.spikeThreshold = ip.Results.spikeThreshold;
            obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            obj.spikeRateBinLength = ip.Results.spikeRateBinLength;
            obj.totalNumEpochs = ip.Results.totalNumEpochs;
            
            obj.frameRate = ip.Results.frameRate;
            obj.preFrames = ip.Results.preTime / 1000 * obj.frameRate;
            obj.stimFrames = ip.Results.stimTime / 1000 * obj.frameRate;
            obj.tailFrames = ip.Results.tailTime / 1000 * obj.frameRate;
            obj.nFrames = obj.preFrames + obj.stimFrames + obj.tailFrames;

            obj.extent = ip.Results.extent;
            obj.dimensions = ip.Results.dimensions;

            obj.temporalSubsample = double(ip.Results.temporalSubsample);
            obj.memory = double(ip.Results.memory);

            obj.getStimulus = ip.Results.getStimulus;

            obj.createUi();
            
            % obj.epochData = {};
            emp = cell(1, obj.totalNumEpochs);
            obj.epochData = struct(...
                'responseObject', emp, ...
                'rawSignal', emp, ...
                'spikeIndices', emp);%, ...
                
            obj.spikeDetector = sa_labs.util.SpikeDetector(obj.spikeDetectorMode, obj.spikeThreshold);
            
            
            obj.epochCount = 0;
            obj.rawTimebase = [];
            obj.ampUnits = '';

            obj.STA = zeros(obj.dimensions(1), obj.dimensions(2), obj.memory);
            obj.mat = zeros([obj.dimensions(1) , obj.dimensions(2), obj.nFrames*obj.temporalSubsample]);
            obj.spikeCount = 0;
            
            [Y,X] = meshgrid(linspace(obj.extent(2)*-1/2,obj.extent(2)*1/2, obj.dimensions(2)),...
                linspace(obj.extent(1)*-1/2,obj.extent(1)*1/2, obj.dimensions(1)));
            obj.xy = [X(:), Y(:)];
            
            obj.lastFit = [.05, 0.0, 0.0, 100.0, 100.0, 0.0, 0.01]; %initial guess for RF
            obj.lb = [-inf, obj.extent(2)*-1/2, obj.extent(1)*-1/2, 0,0,-pi,-inf];
            obj.ub = [inf, obj.extent(2)*1/2, obj.extent(1)*1/2, obj.extent(2), obj.extent(1), pi, inf];
            %(A, xm, ym, xs, ys, th, C)
        end
        
        function createUi(obj)
            import appbox.*;
            
            set(obj.figureHandle, 'Name', sprintf('Texture Noise Figure: %s', obj.device.name));
            
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            fullBox = uix.VBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
            topBox = uix.HBox('Parent', fullBox, 'Spacing', 10);
            bottomBox = uix.HBox('Parent', fullBox, 'Spacing', 10);
            
            obj.topAxis = axes('Parent', topBox);
            hold(obj.topAxis,'on');
            set(obj.topAxis,'LooseInset',get(obj.topAxis,'TightInset'))
            
            obj.topPlot = plot(obj.topAxis, 0, 0);
            obj.topRaster = plot(obj.topAxis,[]);
            
            obj.middleAxis = axes('Parent', bottomBox);
            obj.bottomAxis = axes('Parent', bottomBox);
            
            set(obj.middleAxis,'LooseInset',get(obj.middleAxis,'TightInset'))
            set(obj.bottomAxis,'LooseInset',get(obj.bottomAxis,'TightInset'))
        
            
            obj.rfMap = imagesc(obj.bottomAxis, obj.extent(1)*[-1/2,1/2], obj.extent(2)*[-1/2,1/2], obj.STA(:,:,1));
            axis(obj.bottomAxis, 'xy');
            hold(obj.bottomAxis, 'on');
            obj.rfFit = plot(obj.bottomAxis, 0,0,'k+');
            obj.rfText = text(obj.bottomAxis, 0, 0, '','verticalalignment','top');
            
            axis(obj.bottomAxis,'tight');
            obj.middlePlot = plot(obj.middleAxis, linspace(-obj.memory/obj.temporalSubsample/obj.frameRate,0,obj.memory), zeros(obj.memory, 1));
            
        end
        
        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            if obj.epochCount > obj.totalNumEpochs
                % we've finished the first epoch block
                obj.totalNumEpochs = obj.epochCount;
            end
            
            if epoch.hasResponse(obj.device) % TODO: this should always happen?    
                obj.epochData(obj.epochCount).responseObject = epoch.getResponse(obj.device);                    
                [obj.epochData(obj.epochCount).rawSignal,~] = obj.epochData(obj.epochCount).responseObject.getData();

                if isempty(obj.ampUnits)
                    obj.sampleRate = obj.epochData(obj.epochCount).responseObject.sampleRate.quantityInBaseUnits;
                    responseLength = length(obj.epochData(obj.epochCount).rawSignal);
                        
                    obj.rawTimebase = (0:responseLength-1) / obj.sampleRate; % in seconds
                    
                    set(obj.topPlot, 'xdata', obj.rawTimebase,'ydata', obj.epochData(obj.epochCount).rawSignal);
                    ylabel(obj.topAxis, obj.ampUnits, 'Interpreter', 'none');
                end
                
                if strcmp(obj.ampMode, 'Whole cell')
                else
                    % Extract spikes from signal
                    result = obj.spikeDetector.detectSpikes(obj.epochData(obj.epochCount).rawSignal);
                    obj.epochData(obj.epochCount).spikeIndices = result.sp;

                    %% Update RF map
                    obj.mat = obj.getStimulus(epoch.parameters('noiseSeed'));

                    for sp = obj.epochData(obj.epochCount).spikeIndices
                        t = floor((sp / obj.sampleRate  * obj.frameRate - obj.preFrames) * obj.temporalSubsample);
                        if (t-obj.memory) < 0
                            %TODO: for now we just skip early spikes...
                        elseif t > size(obj.mat,3)
                            %TODO: for now we just skip late spikes...
                        else
                            obj.STA = obj.STA + obj.mat(:,:,(t - obj.memory + 1):t);
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
            
            title(obj.topAxis, sprintf('Epoch %d of %d: %d spikes (%d total)', obj.epochCount, obj.totalNumEpochs, length(obj.epochData(obj.epochCount).spikeIndices), obj.spikeCount));        
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
                obj.topRaster = line(obj.topAxis, [spikeTimes;spikeTimes], [yl(1)*spikeOnes;yl(2)*spikeOnes], 'color', 'k'); %one line per column
                
                % now, do the RF map and temporal kernel
                [c,s,~] = pca(reshape(obj.STA,[],obj.memory)');
                % only works if numel(obj.STA) > obj.memory??
                
                
                rf = reshape(c(:,1), size(obj.STA,1), size(obj.STA,2));
                set(obj.rfMap,'cdata', flipud(rf));
                
                set(obj.middlePlot,'ydata',s(:,1));

                % fit the RF to a gaussian
                obj.lastFit = lsqcurvefit(@(x0, xdata) gauss2d(x0(1), x0(2), x0(3), x0(4),...
                    x0(5), x0(6), x0(7), xdata(:,1), xdata(:,2)), obj.lastFit, obj.xy, c(:,1), obj.lb, obj.ub);
                
                set(obj.rfFit,'xdata',obj.lastFit(2), 'ydata', -obj.lastFit(3));
                set(obj.rfText,'position',[obj.lastFit(2), -obj.lastFit(3), 0], 'String', sprintf('(%0.0f, %0.0f)', obj.lastFit(2), -obj.lastFit(3)));
                
                %(A, xm, ym, xs, ys, th, C, x, y)
                
            end            
        end
    end
end


function g = gauss2d(A, xm, ym, xs, ys, th, C, x, y)
    a = cos(th)^2/(2*xs^2) + sin(th)^2/(2*ys^2);
    b = -sin(2*th)/(4*xs^2) + sin(2*th)/(4*ys^2);
    c = sin(th)^2/(2*xs^2) + cos(th)^2/(2*ys^2);
    g = C + A * exp(-(a*(x - xm).^2 + 2*b*(x-xm).*(y-ym) + c*(y-ym).^2));                
end