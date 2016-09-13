classdef LinearFilterFigure < symphonyui.core.FigureHandler
    
    properties (SetAccess = private)
        ampDevice
        frameMonitor
        stageDevice
        recordingType
        preTime
        stimTime
        frameDwell
        noiseStdv
        seedID
        updatePattern
        figureTitle
    end
    
    properties (Access = private)
        axesHandle
        lineHandle
        lnDataHandle
        noiseStream
        allStimuli
        allResponses
        newFilter
        epochCount
    end
    
    methods
        
        function obj = LinearFilterFigure(ampDevice, frameMonitor, stageDevice, varargin)
            obj.ampDevice = ampDevice;
            obj.frameMonitor = frameMonitor;
            obj.stageDevice = stageDevice;
            ip = inputParser();
            ip.addParameter('recordingType', [], @(x)ischar(x));
            ip.addParameter('preTime', [], @(x)isvector(x));
            ip.addParameter('stimTime', [], @(x)isvector(x));
            ip.addParameter('frameDwell', [], @(x)isvector(x));
            ip.addParameter('noiseStdv', 0.3, @(x)isvector(x));
            ip.addParameter('seedID', 'noiseSeed', @(x)ischar(x));
            ip.addParameter('figureTitle','Linear-Nonlinear analysis', @(x)ischar(x));
            %Update pattern [start point, interval]. Default is start at
            %epoch 1 and update every epoch. e.g. [3 3] is start with epoch
            %3 and update every 3rd epoch thereafter
            ip.addParameter('updatePattern',[1, 1], @(x)isvector(x));
            ip.parse(varargin{:});
            
            obj.recordingType = ip.Results.recordingType;
            obj.preTime = ip.Results.preTime;
            obj.stimTime = ip.Results.stimTime;
            obj.frameDwell = ip.Results.frameDwell;
            obj.noiseStdv = ip.Results.noiseStdv;
            obj.seedID = ip.Results.seedID;
            obj.figureTitle = ip.Results.figureTitle;
            obj.updatePattern = ip.Results.updatePattern;

            obj.allStimuli = [];
            obj.allResponses = [];
            obj.epochCount = 0;
            obj.createUi();
        end

        function createUi(obj)
            import appbox.*;
            iconDir = [fileparts(fileparts(mfilename('fullpath'))), '\+utils\+icons\'];
            toolbar = findall(obj.figureHandle, 'Type', 'uitoolbar');
            plotLNButton = uipushtool( ...
                'Parent', toolbar, ...
                'TooltipString', 'Plot nonlinearity', ...
                'Separator', 'on', ...
                'ClickedCallback', @obj.onSelectedFitLN);
            setIconImage(plotLNButton, [iconDir, 'exp.png']);

            obj.axesHandle(1) = subplot(2,1,1,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(1), 'Time (ms)');
            ylabel(obj.axesHandle(1), 'Amp.');
            title(obj.axesHandle(1),'Linear filter');
            
            obj.axesHandle(2) = subplot(2,1,2,...
                'Parent',obj.figureHandle,...
                'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'),...
                'FontSize', get(obj.figureHandle, 'DefaultUicontrolFontSize'), ...
                'XTickMode', 'auto');
            xlabel(obj.axesHandle(2), 'Linear prediction');
            ylabel(obj.axesHandle(2), 'Measured');
            title(obj.axesHandle(2),'Nonlinearity');
            
            obj.figureHandle.Name = obj.figureTitle;
        end

        function handleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            tempPattern = mod(obj.epochCount - obj.updatePattern(1),obj.updatePattern(2));
            if obj.epochCount >= obj.updatePattern(1) && tempPattern == 0
                %load amp data
                response = epoch.getResponse(obj.ampDevice);
                epochResponseTrace = response.getData();
                sampleRate = response.sampleRate.quantityInBaseUnits;
                prePts = sampleRate*obj.preTime/1000;
                if strcmp(obj.recordingType,'extracellular') %spike recording
                    newResponse = zeros(size(epochResponseTrace));
                    %count spikes
                    S = edu.washington.riekelab.turner.utils.spikeDetectorOnline(epochResponseTrace);
                    newResponse(S.sp) = 1;
                else %intracellular - Vclamp
                    epochResponseTrace = epochResponseTrace-mean(epochResponseTrace(1:prePts)); %baseline
                    if strcmp(obj.recordingType,'exc') %measuring exc
                        polarity = -1;
                    elseif strcmp(obj.recordingType,'inh') %measuring inh
                        polarity = 1;
                    end
                    newResponse = polarity * epochResponseTrace;
                end
                %load frame monitor data
                if isa(obj.stageDevice,'edu.washington.riekelab.devices.LightCrafterDevice')
                    lightCrafterFlag = 1;
                else %OLED stage device
                    lightCrafterFlag = 0;
                end
                frameRate = obj.stageDevice.getMonitorRefreshRate();
                FMresponse = epoch.getResponse(obj.frameMonitor);
                FMdata = FMresponse.getData();
                frameTimes = edu.washington.riekelab.turner.utils.getFrameTiming(FMdata,lightCrafterFlag);
                preFrames = frameRate*(obj.preTime/1000);
                firstStimFrameFlip = frameTimes(preFrames+1);
                newResponse = newResponse(firstStimFrameFlip:end); %cut out pre-frames
                %reconstruct noise stimulus
                filterLen = 800; %msec, length of linear filter to compute
                %fraction of noise update rate at which to cut off filter spectrum
                freqCutoffFraction = 1;
                currentNoiseSeed = epoch.parameters(obj.seedID);

                %reconstruct stimulus trajectories...
                stimFrames = round(frameRate * (obj.stimTime/1e3));
                noise = zeros(1,floor(stimFrames/obj.frameDwell));
                response = zeros(1, floor(stimFrames/obj.frameDwell));
                %reset random stream to recover stim trajectories
                obj.noiseStream = RandStream('mt19937ar', 'Seed', currentNoiseSeed);
                % get stim trajectories and response in frame updates
                chunkLen = obj.frameDwell*mean(diff(frameTimes));
                for ii = 1:floor(stimFrames/obj.frameDwell)
                    noise(ii) = obj.noiseStdv * obj.noiseStream.randn;
                    response(ii) = mean(newResponse(round((ii-1)*chunkLen + 1) : round(ii*chunkLen)));
                end
                obj.allStimuli = cat(1,obj.allStimuli,noise);
                obj.allResponses = cat(1,obj.allResponses,response);

                updateRate = (frameRate/obj.frameDwell); %hz
                obj.newFilter = edu.washington.riekelab.turner.utils.getLinearFilterOnline(obj.allStimuli,obj.allResponses,...
                    updateRate, freqCutoffFraction*updateRate);

                filterPts = (filterLen/1000)*updateRate;
                filterTimes = linspace(0,filterLen,filterPts); %msec

                obj.newFilter = obj.newFilter(1:filterPts);
                if isempty(obj.lineHandle)
                    obj.lineHandle = line(filterTimes, obj.newFilter,...
                        'Parent', obj.axesHandle(1),'LineWidth',2);
                    ht = line([filterTimes(1) filterTimes(end)],[0 0],...
                        'Parent', obj.axesHandle(1),'Color','k',...
                        'Marker','none','LineStyle','--');
                else
                    set(obj.lineHandle, 'YData', obj.newFilter);
                end
            end
        end
        
    end
    
    methods (Access = private)
        
        function onSelectedFitLN(obj, ~, ~)
            measuredResponse = reshape(obj.allResponses',1,numel(obj.allResponses));
            stimulusArray = reshape(obj.allStimuli',1,numel(obj.allStimuli));
            linearPrediction = conv(stimulusArray,obj.newFilter);
            linearPrediction = linearPrediction(1:length(stimulusArray));
            [~,edges,bin] = histcounts(linearPrediction,'BinMethod','auto');
            binCtrs = edges(1:end-1) + diff(edges);
            
            binResp = zeros(size(binCtrs));
            for bb = 1:length(binCtrs)
               binResp(bb) = mean(measuredResponse(bin == bb)); 
            end
            if isempty(obj.lnDataHandle)
                obj.lnDataHandle = line(binCtrs, binResp,...
                    'Parent', obj.axesHandle(2),'LineStyle','none','Marker','o');
                limDown = min([linearPrediction measuredResponse]);
                limUp = max([linearPrediction measuredResponse]);
                htx = line([limDown limUp],[0 0],...
                    'Parent', obj.axesHandle(2),'Color','k',...
                    'Marker','none','LineStyle','--');
                hty = line([0 0],[limDown limUp],...
                    'Parent', obj.axesHandle(2),'Color','k',...
                    'Marker','none','LineStyle','--');
            else
                set(obj.lnDataHandle, 'YData', binResp,...
                    'XData', binCtrs);
            end
            
        end
    end

end

