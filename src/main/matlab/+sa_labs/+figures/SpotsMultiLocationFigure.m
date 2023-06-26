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
        spotDuration
        
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
        alignedResp
        
        exampleAxes
        examplePlot
        
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
            obj.ampUnits = cell(obj.numChannels,1);
        end
        
        function createUi(obj)
            import appbox.*;
            
            if length(obj.devices) == 1
                set(obj.figureHandle, 'Name', sprintf('Spots Multi-Location Figure: %s', obj.devices{1}.name));
            else
                set(obj.figureHandle, 'Name', sprintf('Spots Multi-Location Figure', obj.devices{1}.name));
            end
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            fullBox = uix.VBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
            topBox = uix.HBox('Parent', fullBox, 'Spacing', 10);
            restBox = uix.VBoxFlex('Parent', fullBox, 'Spacing', 10);
            
            middleBox = uix.HBox('Parent', restBox, 'Spacing', 10);
            bottomBox = uix.HBox('Parent', restBox, 'Spacing', 10);
            
            
            
            obj.responseAxis = axes('Parent', topBox);
            hold(obj.responseAxis,'on');
            set(obj.responseAxis,'LooseInset',get(obj.responseAxis,'TightInset'))
            
            obj.colorOrder = get(groot, 'defaultAxesColorOrder');
            
            obj.topPlots = cell(obj.numChannels,1);
            obj.topRasters = cell(obj.numChannels,1);
            obj.middleAxes = cell(obj.numChannels,1);
            obj.bottomAxes = cell(obj.numChannels,1);
            obj.alignedResp = cell(obj.numChannels,1);
            
            % obj.rfmaps = cell(obj.numChannels,1);
            obj.scatters = cell(obj.numChannels,1);
            for ci = 1:obj.numChannels
                color = obj.colorOrder(mod(ci - 1, size(obj.colorOrder, 1)) + 1, :);
                obj.topPlots{ci} = plot(obj.responseAxis, 0, 0, 'color', color);
                obj.topRasters{ci} = plot(obj.responseAxis,[]); %line(0,0, 'color',color);
                
                obj.middleAxes{ci} = axes('Parent', middleBox);
                obj.scatters{ci} = scatter(obj.middleAxes{ci},0,0,200,0,'filled'); %TODO: check size
                axis(obj.middleAxes{ci}, 'equal');
                
                obj.bottomAxes{ci} = axes('Parent', bottomBox);
                set(obj.bottomAxes{ci},'LooseInset',get(obj.bottomAxes{ci},'TightInset'))
            
                % obj.rfmaps{ci} = imagesc(obj.bottomAxes{ci},0);
%                 axis(obj.bottomAxes{ci}, 'equal');
                obj.alignedResp{ci} = plot(obj.bottomAxes{ci},[]);

                ylim(obj.bottomAxes{ci}, [0, obj.spotsPerEpoch + 1]);
                xlim(obj.bottomAxes{ci}, [-obj.preTime, obj.stimTime + obj.tailTime]);
                line(obj.bottomAxes{ci}, [0;0], [0;obj.spotsPerEpoch + 1], 'color', 'g');
                line(obj.bottomAxes{ci}, [obj.stimTime;obj.stimTime], [0;obj.spotsPerEpoch + 1], 'color', 'r');
                xlim(obj.bottomAxes{ci}, 'manual');
                ylim(obj.bottomAxes{ci}, 'manual');
                                
            end
            
            obj.exampleAxes = axes('Parent', middleBox);
            obj.examplePlot = plot(obj.exampleAxes, [0,0], [0,0]);
            xlabel(obj.exampleAxes, 'Time (ms)');
            
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
                        
                        obj.spotDuration = obj.preTime + obj.stimTime + obj.tailTime; %in seconds
                        responseLength = length(obj.epochData(ci, obj.epochCount).rawSignal);
                        %TODO: get the duration properly
                        
                        obj.rawTimebase = (0:responseLength-1) / sampleRate; % in seconds
                        obj.timebase = mod(obj.rawTimebase, obj.spotDuration); % in seconds
                        obj.timebase = obj.timebase - obj.preTime;
                        
                        nSpots = round((responseLength / sampleRate) / obj.spotDuration);
                        obj.timebase = reshape(obj.timebase,[],nSpots);                        
                    end
                    
                    set(obj.topPlots{ci}, 'xdata', obj.rawTimebase,'ydata', obj.epochData(ci, obj.epochCount).rawSignal);
                    ylabel(obj.responseAxis, obj.ampUnits{ci}, 'Interpreter', 'none');
                    ylabel(obj.exampleAxes, obj.ampUnits{ci}, 'Interpreter', 'none');
                    
                    
                    %TODO: whatever the last channel is will overwrite
                    %instead we should just yyplot if we have both modes,
                    %though not even sure that's possible
                    
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
            end
            obj.redrawPlots(epoch);
        end
        
        function redrawPlots(obj, epoch)
            if isempty(obj.epochData)
                return
            end
            grid = [epoch.parameters('cx'); epoch.parameters('cy')]';
            
            
            title(obj.responseAxis, sprintf('Epoch %d of %d', obj.epochCount, obj.totalNumEpochs));
            
            
            
            for ci = 1:obj.numChannels
                %plot raw responses
                set(obj.topPlots{ci}, 'ydata', obj.epochData(ci, obj.epochCount).rawSignal);
                
                % if numel(get(obj.alignedResp{ci},'xdata')) ~= numel(obj.timebase)
                %     delete(obj.alignedResp{ci});
                %     obj.alignedResp{ci} = plot(obj.bottomAxes{ci}, obj.timebase, reshape(obj.epochData(ci, obj.epochCount).rawSignal, size(obj.timebase)));
                %     set(obj.bottomAxes{ci},'xlim',[obj.timebase(1,1), obj.timebase(end,end)]);
                % else
                %     set(obj.alignedResp{ci}, 'ydata', reshape(obj.epochData(ci, obj.epochCount).rawSignal, size(obj.timebase)));
                % end
                
                if strcmp(obj.ampModes{ci}, 'Cell attached')
                    delete(obj.topRasters{ci});
                    delete(obj.alignedResp{ci});
                end
            end
            
            yl = get(obj.responseAxis,'ylim');
            
            for ci = 1:obj.numChannels
                color = obj.colorOrder(mod(ci - 1, size(obj.colorOrder, 1)) + 1, :);
                
                if strcmp(obj.ampModes{ci}, 'Cell attached')
                    %plot detected spikes
                    spikeTimes = obj.rawTimebase(obj.epochData(ci, obj.epochCount).spikeIndices); %1-by-N, (0,35]
                    if size(spikeTimes,1) > 1
                        spikeTimes = spikeTimes'; %TODO: just not sure what shape this is, this shouldn't be necessary
                    end
                    spikeOnes = ones(size(spikeTimes));
                    
                    obj.topRasters{ci} = line(obj.responseAxis, [spikeTimes;spikeTimes], [yl(1)*spikeOnes;yl(2)*spikeOnes], 'color', color/2); %one line per column
                    %TODO: check orientation of spikeIndices
                    %NOTE: this would be faster if we preallocated the lines, then set any lines above the spike count to be invisible
                    
                    
                    % plot spike heatmaps
                    %floor divide the spike indices by the spot duration
                    
                    spikeSpots = floor(spikeTimes / obj.spotDuration) + 1;
                    spikeSpotTime = mod(spikeTimes, obj.spotDuration);
%                     set(obj.topPlots{ci}, 'xdata', obj.rawTimebase,'ydata', obj.epochData(ci, obj.epochCount).rawSignal);
                    exampleTrial = mode(spikeSpots);
                    if ci == 1 && ~isnan(exampleTrial)   
                        sl = obj.epochData(ci, obj.epochCount).responseObject.sampleRate.quantity * obj.spotDuration;
                        set(obj.examplePlot, 'xdata', obj.timebase(:,exampleTrial)', 'ydata', obj.epochData(ci, obj.epochCount).rawSignal(sl*(exampleTrial-1)+1 : sl*exampleTrial));
                        axis(obj.exampleAxes, 'tight');
                    end
                    
                    if isempty(spikeSpots(spikeSpotTime>obj.preTime))
                        resp = zeros([obj.spotsPerEpoch,1]);
                    else
                        resp = accumarray(spikeSpots(spikeSpotTime>obj.preTime)', 1, [obj.spotsPerEpoch,1], @sum, 0);
                    end
                    
                    if isempty(spikeSpots(spikeSpotTime<=obj.preTime))
                        bl = zeros([obj.spotsPerEpoch,1]);
                    else
                        bl = accumarray(spikeSpots(spikeSpotTime<=obj.preTime)', 1, [obj.spotsPerEpoch,1], @sum, 0);
                    end
                    
                    [u,~,ui] = unique(grid,'rows');
                    
                    set(obj.scatters{ci}, 'xdata', u(:,1), 'ydata', u(:,2), 'cdata', splitapply(@mean,resp - bl,ui));
                    axis(obj.middleAxes{ci}, 'equal');
                    
                    %TODO: plotting the heatmap is a bit more complicated
                    % im = get(obj.rfmaps{ci},'cdata'); %the previous heatmap

                    obj.alignedResp{ci} = line(obj.bottomAxes{ci}, [spikeSpotTime - obj.preTime;spikeSpotTime - obj.preTime],...
                        [spikeSpots - 0.5; spikeSpots + 0.5], 'color', color/2); %one line per column

                    
                end
            end
            
        end
    end
end