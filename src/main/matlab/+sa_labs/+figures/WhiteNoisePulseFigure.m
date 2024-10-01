classdef WhiteNoisePulseFigure < symphonyui.core.FigureHandler

    properties
        devices
        responseMode
        spikeThreshold
        spikeDetectorMode
        spikeRateBinLength
        totalNumEpochs
        analysisRegion        
        spikeDetector
        epochData

        epochCount

        responseAxis
    end

    methods

        function obj = WhiteNoisePulseFigure(devices, varargin)
            obj = obj@symphonyui.core.FigureHandler();
           
            ip = inputParser();
            ip.addParameter('responseMode','Whole cell', @(x)ischar(x));
            ip.addParameter('spikeDetectorMode',@(x)ischar(x));
            ip.addParameter('spikeThreshold', 0, @(x)isnumeric(x));
            ip.addParameter('spikeRateBinLength', 0.05, @(x)isnumeric(x));
            ip.addParameter('totalNumEpochs',1,@(x)isnumeric(x));
            ip.addParameter('analysisRegion',[0,inf]);
            ip.addParameter('slope',1);
            
            ip.parse(varargin{:});
            
            obj.devices = devices;
            obj.responseMode = ip.Results.responseMode;
            obj.spikeThreshold = ip.Results.spikeThreshold;
            obj.spikeDetectorMode = ip.Results.spikeDetectorMode;
            obj.spikeRateBinLength = ip.Results.spikeRateBinLength;
            obj.totalNumEpochs = ip.Results.totalNumEpochs;
            obj.analysisRegion = ip.Results.analysisRegion;
            obj.slope = ip.Results.slope;
            
            obj.createUi();
            


            obj.epochData = struct('firstSpikeCurrent',cell(obj.totalNumEpochs,1));
            obj.epochCount = 0;
            
            obj.spikeDetector = sa_labs.util.SpikeDetector(obj.spikeDetectorMode, obj.spikeThreshold);
        end
        
        function createUi(obj)
            import appbox.*;
            
            set(obj.figureHandle, 'Name', 'Ramp Figure');
            set(obj.figureHandle, 'MenuBar', 'none');
            set(obj.figureHandle, 'GraphicsSmoothing', 'on');
            set(obj.figureHandle, 'DefaultAxesFontSize',8, 'DefaultTextFontSize',8);
            
            fullBox = uix.HBoxFlex('Parent', obj.figureHandle, 'Spacing',10);
            obj.responseAxis = axes('Parent', fullBox);%, 'Units', 'normalized','Position',[.1 .1 .5 .5]);
            

        end
        
        function refreshUi(obj)
            % split out the parts needed to add an analysis graph from the rest, so they don't get deleted so much
        end
        
        function handleEpoch(obj, epoch)
            try
                obj.doHandleEpoch(epoch);
                
            catch e
                disp(getReport(e));
                
                rethrow(e);
            end
        end
        
        function doHandleEpoch(obj, epoch)
            obj.epochCount = obj.epochCount + 1;
            % channels = cell(obj.numChannels, 1);
            % obj.channelNames = cell(obj.numChannels,1);
            
              
            % for ci = 1:obj.numChannels
                % obj.channelNames{ci} = obj.devices{ci}.name;
%                     fprintf('processing input from channel %d: %s\n',ci,obj.devices{ci}.name)
                % process this epoch and add to epochData array
            if ~epoch.hasResponse(obj.devices{1})
                disp(['Epoch does not contain a response for ' obj.devices{1}.name]);
                return
            end
            ci = 1;

            % e = struct();
            responseObject = epoch.getResponse(obj.devices{ci});
            [rawSignal, units] = responseObject.getData();

            sampleRate = responseObject.sampleRate.quantityInBaseUnits;
            t = (0:length(rawSignal)-1) / sampleRate;


            result = obj.spikeDetector.detectSpikes(rawSignal);
            spikeFrames = result.sp;
            spikeTimes = t(spikeFrames);

            spikeTimes(spikeTimes < obj.analysisRegion(1)) = [];
            spikeTimes(spikeTimes > obj.analysisRegion(2)) = [];

            %if spikeTimes is 0 -> preTime
            % if spikes Times is preTime -> current = 0
            spikeCurrents = (spikeTimes - obj.analysisRegion(1)) * obj.slope;
            
            
            if ~isempty(spikeCurrents)
                e = struct('firstSpikeCurrent',spikeCurrents(1));
            else
                e = struct('firstSpikeCurrent',NaN);
            end


            obj.epochData(obj.epochCount) = e;
            
            obj.redrawPlots();
        end
        
        function redrawPlots(obj)
            firstSpikeCurrents =  [obj.epochData(:).firstSpikeCurrent];
            histogram(obj.responseAxis, firstSpikeCurrents,'numbins',20);

            
            xlim(obj.responseAxis, [0, (obj.analysisRegion(2) - obj.analysisRegion(1))*obj.slope]);

            titleStr = sprintf('Mean: %0.02f, Median: %0.02f, Mode: %0.02f', nanmean(firstSpikeCurrents), nanmedian(firstSpikeCurrents), mode(firstSpikeCurrents));
            title(obj.responseAxis, titleStr);

            xlabel(obj.responseAxis, 'Current (pA)'); % TODO: should be voltage for vc... etc
            ylabel(obj.responseAxis, 'Count')
        end
    end
end


