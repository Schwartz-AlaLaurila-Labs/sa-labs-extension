classdef SpotsMultiLocationFigure < symphonyui.core.FigureHandler

properties
    devices
    ampModes
    numChannels
    spikeThreshold
    spikeDetectorMode
    spikeRateBinLength
    totalNumEpochs
    spotsPerEpoch
    epochData
    spikeDetector
    epochCount

    preTime
    stimTime
    tailTime
    spotDuration % in samples
    preDuration % in samples

    timebase
    rawTimebase
    ampUnits
    responseAxis
    channelNames
    colorOrder

    topPlots
    topRasters

    middleAxes
    scatters

    bottomAxes
    rfmaps

end

methods
    function obj = SpotsMultiLocationFigure(devices, ampModes, varargin)
        obj = obj@symphonyui.core.FigureHandler();
       
        ip = inputParser();
        ip.addParameter('spikeDetectorMode',@(x)ischar(x));
        ip.addParameter('spikeThreshold', 0, @(x)isnumeric(x));
        ip.addParameter('spikeRateBinLength', 0.05, @(x)isnumeric(x));
        ip.addParameter('totalNumEpochs',1,@(x)isnumeric(x));
        ip.addParameter('preTime',1.0,@(x)isnumeric(x));
        ip.addParameter('stimTime',1.0,@(x)isnumeric(x));
        ip.addParameter('tailTime',1.0,@(x)isnumeric(x));
        ip.addParameter('spotsPerEpoch',1,@(x)isnumeric(x));
        ip.parse(varargin{:});


        obj.devices = devices;
        obj.ampModes = ampModes;
        obj.numChannels = length(obj.devices);
        obj.spikeThreshold = ip.Results.spikeThreshold;
        obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
        obj.spikeRateBinLength = ip.Results.spikeRateBinLength;
        obj.totalNumEpochs = ip.Results.totalNumEpochs;
        
        obj.preTime = ip.Results.preTime;
        obj.stimTime = ip.Results.stimTime;
        obj.tailTime = ip.Results.tailTime;
        
        obj.spotsPerEpoch = ip.Results.spotsPerEpoch;

        obj.createUi();
        
        % obj.epochData = {};
        emp = cell(obj.numChannels, obj.totalNumEpochs);
        obj.epochData = struct(...
            'responseObject', emp, ...
            'rawSignal', emp, ...
            ...% 'units', emp, ...
            ...% 'sampleRate', emp, ...
            'spikeIndices', emp);%, ...
            % 'spikeTimes', emp);
        
        obj.spikeDetector = sa_labs.util.SpikeDetector(obj.spikeDetectorMode, obj.spikeThreshold);
     
        obj.channelNames = cellfun(@(x) x.name, obj.devices, 'uniformoutput', false);

        obj.epochCount = 0;
        obj.timebase = [];
        obj.rawTimebase = [];
        obj.ampUnits = {};
    end

    function createUi(obj)
        import appbox.*;

        set(obj.figureHandle, 'Name', 'Spots Multi-Location Figure');
        set(obj.figureHandle, 'MenuBar', 'none');
        set(obj.figureHandle, 'GraphicsSmoothing', 'on');
        set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);

        fullBox = uix.VBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
        topBox = uix.HBox('Parent', fullBox, 'Spacing', 10);
        restBox = uix.VBoxFlex('Parent', fullBox, 'Spacing', 10);

        middleBox = uix.HBox('Parent', restBox, 'Spacing', 10);
        % bottomBox = uix.HBox('Parent', restBox, 'Spacing', 10);
        
            

        obj.responseAxis = axes('Parent', topBox);
        hold(obj.responseAxis,'on');
        set(obj.responseAxis,'LooseInset',get(obj.responseAxis,'TightInset'))

        obj.colorOrder = get(groot, 'defaultAxesColorOrder');

        obj.topPlots = cell(obj.numChannels,1);
        obj.topRasters = cell(obj.numChannels,1);
        obj.middleAxes = cell(obj.numChannels,1);
        % obj.bottomAxes = cell(obj.numChannels,1);
        % obj.rfmaps = cell(obj.numChannels,1);
        obj.scatters = cell(obj.numChannels,1);
        for ci = 1:obj.numChannels
            color = obj.colorOrder(mod(ci - 1, size(obj.colorOrder, 1)) + 1, :);
            obj.topPlots{ci} = plot(obj.responseAxis, 0, 0, 'color', color);
            obj.topRasters{ci} = plot([]); %line(0,0, 'color',color);

            obj.middleAxes{ci} = axes('Parent', middleBox);
            obj.scatters{ci} = scatter(0,0,200,0,'filled'); %TODO: check size
            axis(obj.middleAxes{ci}, 'equal');

            % obj.bottomAxes{ci} = axes('Parent', bottomBox);
            % obj.rfmaps{ci} = imagesc(obj.bottomAxes{ci},0);
            % axis(obj.bottomAxes{ci}, 'equal');
        end

    end

    function handleEpoch(obj, epoch)
        obj.epochCount = obj.epochCount + 1;
        if obj.epochCount > obj.totalNumEpochs
            % we've finished the first epoch block
            obj.totalNumEpochs = obj.epochCount;
        end


        % some slower code for the first epoch
        if any(cellfun(@isempty, obj.ampUnits))
            for ci = 1:obj.numChannels
                if ~epoch.hasResponse(obj.devices{ci})
                    continue
                end
                    
                obj.epochData(ci, obj.epochCount).responseObject = epoch.getResponse(obj.devices{ci});
                [obj.epochData(ci, obj.epochCount).rawSignal, obj.ampUnits{ci}] = obj.epochData(ci, obj.epochCount).responseObject.getData();
                %TODO: the units will probably be weird...

                if isempty(obj.timebase)
                    sampleRate = obj.epochData(ci, obj.epochCount).responseObject.sampleRate.quantityInBaseUnits;
                    
                    spotDuration = obj.preTime + obj.stimTime + obj.tailTime;
                    responseLength = obj.epochData(ci, obj.epochCount).responseObject.duration;
                    %TODO: get the duration properly

                    rawTimebase = (0:length(responseLength)-1) / sampleRate;
                    timebase = mod(rawTimebase, spotDuration);
                    timebase = timebase - obj.preTime;

                    obj.spotDuration = (obj.preTime + obj.stimTime + obj.tailTime) * sampleRate;
                    obj.preDuration = obj.preTime * sampleRate;
                    
                end

                set(obj.topPlots{ci}, 'xdata', timebase,'ydata', obj.epochData(ci, obj.epochCount).rawSignal);
                ylabel(obj.responseAxis, obj.ampUnits{ci}, 'Interpreter', 'none'); 
                %TODO: whatever the last channel is will overwrite

                if strcmp(obj.ampModes{ci}, 'Whole cell')
                else
                    % Extract spikes from signal
                    result = obj.spikeDetector.detectSpikes(obj.epochData(ci, obj.epochCount).rawSignal);
                    obj.epochData(ci, obj.epochCount).spikeIndices = result.sp;
                    % obj.epochData(ci, obj.epochCount).spikeTimes = obj.epochData(ci, obj.epochCount).t(spikeIndices);
    
                    % % Generate spike rate signals
                    % spikeBins = [0:obj.spikeRateBinLength:max(e.t), inf];
                    % spikeRate_binned = histcounts(e.spikeTimes, spikeBins);
                    % spikeRate_smoothed = interp1(spikeBins(1:end-1), spikeRate_binned, e.t, 'pchip');
                    % spikeRate_smoothed = spikeRate_smoothed / obj.spikeRateBinLength;
                    % e.signal = spikeRate_smoothed';
    
                end
            end
        else

         for ci = 1:obj.numChannels
            if ~epoch.hasResponse(obj.devices{ci})
                continue
            end

            obj.epochData(ci, obj.epochCount).responseObject = epoch.getResponse(obj.devices{ci});
            
            [obj.epochData(ci, obj.epochCount).rawSignal,~] = obj.epochData(ci, obj.epochCount).responseObject.getData();
            
            if strcmp(obj.ampModes{ci}, 'Whole cell')
            else
                % Extract spikes from signal
                result = obj.spikeDetector.detectSpikes(obj.epochData(ci, obj.epochCount).rawSignal);
                obj.epochData(ci, obj.epochCount).spikeIndices = result.sp;
                % obj.epochData(ci, obj.epochCount).spikeTimes = obj.epochData(ci, obj.epochCount).t(spikeIndices);

                % % Generate spike rate signals
                % spikeBins = [0:obj.spikeRateBinLength:max(e.t), inf];
                % spikeRate_binned = histcounts(e.spikeTimes, spikeBins);
                % spikeRate_smoothed = interp1(spikeBins(1:end-1), spikeRate_binned, e.t, 'pchip');
                % spikeRate_smoothed = spikeRate_smoothed / obj.spikeRateBinLength;
                % e.signal = spikeRate_smoothed';

            end

        end
        obj.redrawPlots(epoch);
    end

    function redrawPlots(obj, epoch)
        if isempty(obj.epochData)
            return
        end        
        cx = epoch.parameters('cx');
        cy = epoch.parameters('cy');


        title(obj.responseAxis, sprintf('Epoch %d of %d', length(obj.epochData), obj.totalNumEpochs));
        
        for ci = 1:obj.numChannels
            %plot raw responses
            set(obj.topPlots{ci}, 'ydata', obj.epochData(ci, obj.epochCount).rawSignal);
                
            if strcmp(obj.responseMode, 'Cell attached')
               delete(obj.topRasters{ci});
            end
        end

        yl = get(obj.responseAxis,'ylim');

        for ci = 1:obj.numChannels
            color = obj.colorOrder(mod(ci - 1, size(obj.colorOrder, 1)) + 1, :);
            
            if strcmp(obj.responseMode, 'Cell attached')
                %plot detected spikes
                spikeTimes = obj.rawTimebase(obj.epochData(ci, obj.epochCount).spikeIndices);
                spikeOnes = ones(size(spikeTimes));

                obj.topRasters{ci} = line([spikeTimes;spikeTimes], [yl(1)*spikeOnes,yl(2)*spikeOnes], 'color', color); %one line per column
                %TODO: check orientation of spikeIndices
                %NOTE: this would be faster if we preallocated the lines, then set any lines above the spike count to be invisible


                % plot spike heatmaps
                %floor divide the spike indices by the spot duration
                spikeSpots = floor(spikeTimes / obj.spotDuration);
                spikeSpotTime = mod(spikeTimes, obj.spotDuration);

                resp = accumarray(spikeSpots(spikeSpotTime>obj.preDuration), 1, obj.spotsPerEpoch, 0);
                bl = accumarray(spikeSpots(spikeSpotTime<=obj.preDuration), 1, obj.spotsPerEpoch, 0);
                set(obj.scatters{ci}, 'xdata', cx, 'ydata', cy, 'cdata', resp - bl);


                %TODO: plotting the heatmap is a bit more complicated
                % im = get(obj.rfmaps{ci},'cdata'); %the previous heatmap
            end
        end

    end
    end
end
end