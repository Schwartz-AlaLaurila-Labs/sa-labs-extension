classdef OneDimensionalResponseFigureHandler < symphonyui.core.FigureHandler
    
    properties (Hidden)
        figureType = '1D Response'
        version = 2
    end
    
    properties
        deviceName
        lineColor
        lineStyle
        stimStart %data point
        stimEnd %data point
        paramVals = []
        responseMean = []
        responseVals = {}
        responseVals_unNorm = {};
        responseN = []
        responseSEM = []
        responseType %only for whole-cell for now, spikes are always just counted minus baseline
        responseUnits
        mode
        epochParam
        plotType
        plotHandle
        
        %analysis params
        lowPassFreq
        spikeThreshold
        spikeDetectorMode
    end
    
    properties (Hidden)
        baselineRate = 0;
        Ntrials = 0 ;%for baseline rate calculation
    end
    
    
    methods
        
        function obj = OneDimensionalResponseFigureHandler(protocolPlugin, deviceName, varargin)
            ip = inputParser;
            ip.KeepUnmatched = true;
            ip.addParameter('startTime', 0, @(x)isnumeric(x));
            ip.addParameter('endTime', 0, @(x)isnumeric(x));
            ip.addParameter('ampMode', 'Cell attached', @(x)ischar(x));
            ip.addParameter('epochParam', '', @(x)ischar(x));
            ip.addParameter('responseType', '', @(x)ischar(x));
            ip.addParameter('plotType', 'Linear', @(x)ischar(x));
%             ip.addParameter('lineColor', 'b', @(x)ischar(x) || isvector(x));
%             ip.addParameter('LineStyle', 'none', @(x)ischar(x));
%             ip.addParameter('LowPassFreq', 100, @(x)isnumeric(x));
%             ip.addParameter('SpikeThreshold', 10, @(x)isnumeric(x));
%             ip.addParameter('SpikeDetectorMode', 'Stdev', @(x)ischar(x));
            
            % Allow deviceName to be an optional parameter.
            % inputParser.addOptional does not fully work with string variables.
%             if nargin > 1 && any(strcmp(deviceName, ip.Parameters))
%                 varargin = [deviceName varargin];
%                 deviceName = [];
%             end
%             if nargin == 1
%                 deviceName = [];
%             end
            
            ip.parse(varargin{:});
            
            obj = obj@FigureHandler(protocolPlugin, ip.Unmatched);
            obj.deviceName = deviceName;
%             obj.lineColor = ip.Results.lineColor;
%             obj.lineStyle = ip.Results.lineStyle;
            obj.startTime = round(ip.Results.startTime);
            obj.endTime = round(ip.Results.endTime);
            obj.ampMode = ip.Results.ampMode;
            obj.epochParam = ip.Results.epochParam;
%             obj.responseType = ip.Results.responseType;
            obj.plotType = ip.Results.PlotType;
%             obj.lowPassFreq = ip.Results.lowPassFreq;
%             obj.spikeThreshold = ip.Results.spikeThreshold;
%             obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            
            %set default response type
            if strcmp(obj.mode, 'Cell attached') && isempty(obj.responseType)
                obj.responseType = 'Spike count';
            elseif strcmp(obj.mode, 'Whole cell') && isempty(obj.responseType)
                obj.responseType = 'Charge';
            end
            
            if ~isempty(obj.deviceName)
                set(obj.figureHandle, 'Name', [obj.protocolPlugin.displayName ': ' obj.deviceName ' ' obj.figureType ': ' obj.responseType]);
            end
            
            xlabel(obj.axesHandle(), 'sec');
            set(obj.axesHandle(), 'XTickMode', 'auto');
            
            %remove menubar
            set(obj.figureHandle, 'MenuBar', 'none');
            %make room for labels
            set(obj.axesHandle(), 'Position',[0.14 0.18 0.72 0.72])
            
            obj.resetPlots();
        end
        
        
        function handleEpoch(obj, epoch)
            %focus on correct figure
            set(0, 'CurrentFigure', obj.figureHandle);
            
            if isempty(obj.deviceName)
                % Use the first device response found if no device name is specified.
                [responseData, sampleRate, ~] = epoch.response();
            else
                [responseData, sampleRate, ~] = epoch.response(obj.deviceName);
            end
            
            if strcmp(obj.mode, 'Cell attached')
                %getSpikes
                if strcmp(obj.spikeDetectorMode, 'Simple threshold')
                    responseData = responseData - mean(responseData);
                    sp = getThresCross(responseData,obj.spikeThreshold,sign(obj.spikeThreshold));
                else
                    spikeResults = SpikeDetector_simple(responseData,1./sampleRate, obj.spikeThreshold);
                    sp = spikeResults.sp;
                end
                switch obj.responseType
                    case 'Spike count'
                        %count spikes in stimulus interval
                        spikeCount = length(find(sp>=obj.stimStart & sp<obj.stimEnd));
                        %subtract baseline
                        baselineSpikes = length(find(sp<obj.stimStart));
                        stimIntervalLen = obj.stimEnd - obj.stimStart;
                        curBaseline =  baselineSpikes / (obj.stimStart / sampleRate); %Hz
                        stimSpikeRate = spikeCount / (stimIntervalLen / sampleRate); %Hz
                        if obj.Ntrials == 0
                            obj.baselineRate = curBaseline;
                        else
                            obj.baselineRate = (obj.baselineRate * (obj.Ntrials) + curBaseline) / (obj.Ntrials+1);
                        end
                        obj.Ntrials = obj.Ntrials + 1;
                        stimRate = stimSpikeRate;
                        responseVal = stimRate; %recalculated below
                        obj.responseUnits = 'spikes (norm)';
                        
%                         ang = epoch.getParameter(obj.epochParam);
%                         responseVal = 1.0 + 1.0 * cos(ang*pi/180);
                        
                    case 'Spike mean time'
                        %count spikes in stimulus interval
                        validSpikeTimes = sp(sp>=obj.stimStart & sp<obj.stimEnd) - obj.stimStart;
                        
                        obj.Ntrials = obj.Ntrials + 1;
                        responseVal = mean(validSpikeTimes);
                        obj.responseUnits = 'time (s)';

%                         ang = epoch.getParameter(obj.epochParam);
%                         responseVal = 1.0 + rand() * 0.3 * cos(ang*pi/180);
                        
                        
                    case 'Spike start time'
                        %count spikes in stimulus interval
                        validSpikeTimes = sp(sp>=obj.stimStart & sp<obj.stimEnd) - obj.stimStart;
                        if ~isempty(validSpikeTimes)
                            firstSpikeTime = validSpikeTimes(1);
                        else
                            firstSpikeTime = 0;
                        end

                        obj.Ntrials = obj.Ntrials + 1;
                        responseVal = firstSpikeTime;
                        obj.responseUnits = 'time (s)';
                        
                    case 'CycleAvgF1'
                        stimLen = obj.stimEnd - obj.stimStart; %samples
                        stimSpikes = sp(sp>=obj.stimStart & sp<obj.stimEnd) - obj.stimStart; %offset to start of stim
                        binWidth = 10; %ms
                        %get bins
                        samplesPerMS = sampleRate/1E3;
                        samplesPerBin = binWidth*samplesPerMS;
                        bins = 0:samplesPerBin:stimLen;
                        
                        %compute PSTH for this epoch
                        spCount = histc(stimSpikes,bins);
                        if isempty(spCount)
                            spCount = zeros(1,length(bins));
                        end
                        
                        %convert to Hz
                        spCount = spCount / (binWidth*1E-3);
                        
                        freq = epoch.getParameter('frequency');
                        cyclePts = floor(sampleRate/samplesPerBin/freq);
                        numCycles = floor(length(spCount) / cyclePts);
                        
                        % Get the average cycle.
                        cycles = zeros(numCycles, cyclePts);
                        for j = 1 : numCycles
                            index = round(((j-1)*cyclePts + (1 : floor(cyclePts))));
                            cycles(j,:) =  spCount(index);
                        end
                        % Take the mean.
                        avgCycle = mean(cycles,1);
                        
                        % Do the FFT.
                        ft = fft(avgCycle);
                        
                        % Pull out the F1 amplitude.
                        responseVal = abs(ft(2))/length(ft)*2;
                        obj.responseUnits = 'Spike rate^2/Hz'; %???
                end
                
            else
                stimData = responseData(obj.stimStart:obj.stimEnd);
                baselineData = responseData(1:obj.stimStart-1);
                stimIntervalLen = obj.stimEnd - obj.stimStart;
                switch obj.responseType
                    case 'Peak current'
                        stimData = stimData - mean(baselineData);
                        stimData = LowPassFilter(stimData,obj.lowPassFreq,1/sampleRate);
                        responseVal = max(abs(max(stimData)), abs(min(stimData)));
                        obj.responseUnits = 'pA';
                    case 'Charge'
                        responseVal = sum(stimData - mean(baselineData)) * stimIntervalLen / sampleRate;
                        obj.responseUnits = 'pC';
                    case 'CycleAvgF1'
                        stimData = stimData - mean(baselineData);
                        freq = epoch.getParameter('frequency');
                        cyclePts = floor(sampleRate/freq);
                        numCycles = floor(length(stimData) / cyclePts);
                        
                        % Get the average cycle.
                        cycles = zeros(numCycles, cyclePts);
                        for j = 1 : numCycles
                            index = round(((j-1)*cyclePts + (1 : floor(cyclePts))));
                            cycles(j,:) =  stimData(index);
                        end
                        % Take the mean.
                        avgCycle = mean(cycles,1);
                        
                        % Do the FFT.
                        ft = fft(avgCycle);
                        
                        % Pull out the F1 amplitude.
                        responseVal = abs(ft(2))/length(ft)*2;
                        obj.responseUnits = 'pA^2/Hz'; %? I'm not sure this is scaled correctly for these units
                end
            end
            
            %add data to the appropriate mean structure
            paramVal = epoch.getParameter(obj.epochParam);
            ind = find(obj.paramVals == paramVal);
            if isempty(ind) %first epoch of this value
                ind = length(obj.paramVals)+1;
                obj.paramVals(ind) = paramVal;
                obj.responseMean(ind) = responseVal;
                obj.responseN(ind) = 1;
                obj.responseVals{ind} = responseVal;
                if strcmp(obj.responseType, 'Spike count')
                    obj.responseVals_unNorm{ind} = stimRate;
                end
                obj.responseSEM(ind) = 0;
            else
                obj.responseN(ind) = obj.responseN(ind) + 1;
                %cumulative baseline normalization for spike counts
                if strcmp(obj.responseType, 'Spike count')
                    obj.responseVals_unNorm{ind} = [obj.responseVals_unNorm{ind}, stimRate];
                    for i=1:length(obj.responseVals_unNorm)
                        obj.responseVals{i} = obj.responseVals_unNorm{i} - obj.baselineRate;
                        obj.responseMean(i) = mean(obj.responseVals{i});
                        obj.responseSEM(i) = std(obj.responseVals{i})./sqrt(obj.responseN(i));
                    end
                else
                    obj.responseVals{ind} = [obj.responseVals{ind}, responseVal];
                    obj.responseMean(ind) = mean(obj.responseVals{ind});
                    obj.responseSEM(ind) = std(obj.responseVals{ind})./sqrt(obj.responseN(ind));
                end
            end
            
            %make plots
            
            % sort values by the param values
            sortMatrix = horzcat(obj.paramVals', obj.responseMean', obj.responseSEM');
            sortMatrix = sortrows(sortMatrix, 1);
            paramVals_plot = sortMatrix(:,1)';
            responseMean_plot = sortMatrix(:,2)';
            responseSEM_plot = sortMatrix(:,3)';
            
            switch obj.plotType
                case 'Linear'
                    obj.plotHandle = errorbar(obj.axesHandle(), paramVals_plot, responseMean_plot, responseSEM_plot, ...
                        'Color', obj.lineColor, 'Marker', 'o', 'LineStyle', obj.lineStyle);
                case 'Polar'
                    %degrees to radians
                    responseMean_plot = max(responseMean_plot, 0); % fix polar display when rate is below baseline (negative)
                    obj.plotHandle = polarerror(paramVals_plot.*pi/180, responseMean_plot, responseSEM_plot);
                    set(obj.plotHandle(1),'Color', obj.lineColor);
                    set(obj.plotHandle(2),'Color', obj.lineColor);
                    set(obj.plotHandle(1),'Parent',obj.axesHandle());
                    set(obj.plotHandle(2),'Parent',obj.axesHandle());
                case 'LogX'
                    obj.plotHandle = errorbar(obj.axesHandle(), paramVals_plot, responseMean_plot, responseSEM_plot, 'Color', obj.lineColor);
                    set(obj.axesHandle,'xscale','log');
                case 'LogY'
                    obj.plotHandle = errorbar(obj.axesHandle(), paramVals_plot, responseMean_plot, responseSEM_plot, 'Color', obj.lineColor);
                    set(obj.axesHandle,'yscale','log');
                case 'LogLog'
                    obj.plotHandle = errorbar(obj.axesHandle(), paramVals_plot, responseMean_plot, responseSEM_plot, 'Color', obj.lineColor);
                    set(obj.axesHandle,'xscale','log');
                    set(obj.axesHandle,'yscale','log');
            end
            
            title(obj.axesHandle, [obj.epochParam ' vs. response']);
            if ~strcmp(obj.plotType, 'Polar')
                xlabel(obj.axesHandle, obj.epochParam);
                ylabel(obj.axesHandle, obj.responseUnits);
            end
        end
        
        function saveFigureData(obj,fname)
            data.paramVals = obj.paramVals;
            data.responseMean = obj.responseMean;
            data.responseVals = obj.responseVals;
            data.responseN = obj.responseN;
            data.responseSEM = obj.responseSEM;
            data.mode = obj.mode;
            data.epochParam = obj.epochParam;
            data.responseUnits = obj.responseUnits;
            data.responseType = obj.responseType;
            data.plotType = obj.plotType;
            data.lowPassFreq = obj.lowPassFreq;
            data.spikeThreshold = obj.spikeThreshold;
            data.spikeDetectorMode = obj.spikeDetectorMode;
            data.startTime = obj.stimStart;
            data.endTime = obj.stimEnd;
            save(fname,'data');
        end
        
        function clearFigure(obj)
            obj.resetPlots();
            
            clearFigure@FigureHandler(obj);
        end
        
        function resetPlots(obj)
            obj.plotHandle = [];
            obj.paramVals = [];
            obj.responseMean = [];
            obj.responseVals = {};
            obj.responseN = [];
            obj.responseSEM = [];
        end
        
    end
    
end