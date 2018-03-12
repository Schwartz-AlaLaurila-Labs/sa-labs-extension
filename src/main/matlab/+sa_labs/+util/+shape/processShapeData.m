function ad = processShapeData(epochData, processOptions)
% epochData: cell array of ShapeData, one for each epoch

if nargin < 2
    processOptions = struct();
end

ad = struct();

num_epochs = length(epochData);
ad.numEpochs = num_epochs;
alignmentTemporalOffset_by_v = containers.Map('KeyType','int32','ValueType','double');

% Reorder epochs by presentationId, just in case
pId = [];
for p = 1:num_epochs
    pId(p) = epochData{p}.presentationId;
end

[~,epochOrder] = sort(pId);
epochData = epochData(epochOrder);
ad.epochData = epochData;
ad.positionOffset = epochData{1}.positionOffset;
observationColumns = {};


% create full positions list
all_positions = [];
for p = 1:num_epochs
    e = epochData{p};
    col_x = e.shapeDataColumns('X');
    col_y = e.shapeDataColumns('Y');
    all_positions = vertcat(all_positions, e.shapeDataMatrix(:,[col_x col_y])); %#ok<AGROW>
    
    % grab the time offset while we're here
    if ~isnan(e.timeOffset) % use the value set in an epoch if it's available
        t_offset = e.timeOffset;
        alignmentTemporalOffset_by_v(e.ampVoltage) = e.timeOffset;
    end
end
all_positions = unique(all_positions, 'rows');
num_positions = length(all_positions);
observations = [];
oi = 0;

for p = 1:num_epochs
    ei = epochOrder(p);
    e = epochData{ei};
    ad.spotTotalTime = e.spotTotalTime;
    ad.spotOnTime = e.spotOnTime;
%     ad.numSpots = e.numSpots;
    ad.sampleRate = e.sampleRate;
        
    col_x = e.shapeDataColumns('X');
    col_y = e.shapeDataColumns('Y');
    col_intensity = e.shapeDataColumns('intensity');
    col_startTime = e.shapeDataColumns('startTime');
    col_endTime = e.shapeDataColumns('endTime');
    col_flickerFrequency = e.shapeDataColumns('flickerFrequency');

    positions = e.shapeDataMatrix(:,[col_x col_y]);
    intensities = e.shapeDataMatrix(:,col_intensity);
    startTime = e.shapeDataMatrix(:,col_startTime);
    endTime = e.shapeDataMatrix(:,col_endTime);
    flickerFreq = e.shapeDataMatrix(:,col_flickerFrequency);

    % find the time offset from light to spikes, assuming On semi-transient cell
%     lightOnValue = 1.0 * (mod(e.t - e.preTime, e.spotTotalTime) < e.spotOnTime * 1.2);
%     lightOnTime = zeros(size(e.t));
% 
%     for si = 1:e.totalNumSpots
%         lightOnTime(e.t > startTime(si) & e.t < endTime(si)) = epoch_intensities(si);
%     end
% %     lightOffTime = ~lightOnTime * 1.0;
%     % 
%     [c_on,lags_on] = xcorr(e.response, lightOnTime);
%     [~,I] = max(c_on);
%     t_offset = lags_on(I) ./ e.sampleRate;
    
%     if strcmp(e.epochMode, 'temporalAlignment')
%         figure(67)
%         clf;
%         subplot(2,1,1)
%         hold on
%         plot(lags_on, c_on)
%         plot(lags_on(I), c_on(I), 'o')
%         title('lags')
%         
%         subplot(2,1,2)
%         plot(e.t, lightOnTime)
%         hold on
%         plot(e.t, e.response./max(e.response))
%         plot(e.t-t_offset_on, e.response./max(e.response))
%     end
    
%     [c_off,lags_off] = xcorr(e.response, lightOffTime);
%     [~,I] = max(c_off);
%     t_offset_off = lags_off(I) ./ e.sampleRate;
    
%     if t_offset_on < t_offset_off
%         disp('On cell')
%     else
%         disp('Off cell')
% %         t_offset = t_offset_off;
%     end
    
%     t_offset = [t_offset_on, t_offset_off];  
    
%     if strcmp(e.epochMode, 'flashingSpots')
%         t_offset = mod(t_offset, e.spotTotalTime);
%         
%         % might go too low if the responses are actually more than one time
%         % unit late:
%         t_offset(t_offset < 0.1) = t_offset(t_offset < 0.1) + e.spotTotalTime; 
%     end

    skipResponses = 0;   
    
    % make a light onset signal (simulating a zero-lag ON semi transient cell, for alignment)
    e.signalLightOn = zeros(size(e.t));
    for si = 1:e.totalNumSpots

        if flickerFreq(si) > 0 % ignore the adaptation spots
            continue
        end
        
        % get region of light spot on
        tRegion = e.t > startTime(si) & e.t < endTime(si);
        riseLen = 20; % msec

        totalLen = sum(tRegion);
        if totalLen > riseLen

            responseShape = linspace(1, 0, totalLen);
            responseShape(1:riseLen) = linspace(0,responseShape(riseLen),riseLen);

            e.signalLightOn(tRegion) = responseShape';
        end
%         e.signalLightOn(tRegion) = intensities(si); % square wave for plotting
    end
    
    if ~isnan(e.timeOffset) && abs(e.timeOffset) > 0
        % just use the builtin one if it's stored in the epoch
        t_offset = e.timeOffset;
        
    elseif isKey(alignmentTemporalOffset_by_v, e.ampVoltage)
        
        t_offset = alignmentTemporalOffset_by_v(e.ampVoltage);
%         fprintf('using premade alignment %1.3f for v = %d\n',t_offset,e.ampVoltage)

    elseif strcmp(e.epochMode, 'temporalAlignment')

        % read the value set in the alignment epoch in the curator
        if ~isnan(e.timeOffset) && abs(e.timeOffset) > 0
            alignmentTemporalOffset_by_v(e.ampVoltage) = e.timeOffset;
        else
            % extract the alignment from the epoch
            corrResponse = e.response;
            if e.ampVoltage < 0
                corrResponse = -1 * corrResponse;
            end
            [c_on,lags_on] = xcorr(corrResponse, e.signalLightOn);
            [~,I] = max(c_on);
            t_offset = lags_on(I) ./ e.sampleRate;

    %         this is to give it a bit of slack early in case some strong
    %         responses are making it delay too much
            t_offset = t_offset - .05;

            alignmentTemporalOffset_by_v(e.ampVoltage) = t_offset;
    %         fprintf('temporal alignment gave offset of %1.3f for v = %d\n',t_offset,e.ampVoltage)
            skipResponses = 1;
        end
        

    else
        % look in the offset list to find the closest voltage one
        if ~isempty(alignmentTemporalOffset_by_v)
            voltages = cell2mat(alignmentTemporalOffset_by_v.keys);
            [~, idx] = sort(abs(voltages - e.ampVoltage));
            bestVoltage = voltages(idx(1));
            t_offset = alignmentTemporalOffset_by_v(bestVoltage);
%             fprintf('voltage is %d; using nearby offset of %1.3f for v = %d\n',e.ampVoltage, t_offset, bestVoltage)
        else
            t_offset = 0.05;
            disp('no temporal alignment epoch found; using default temporal offset of 0.05');
        end
    end
    
    e.timeOffset = t_offset; % store it in the epoch for display

    % change which data is considered the response (from On time to total time)
    sampleCount_total = round(e.spotTotalTime * e.sampleRate);
    sampleCount_on    = round(e.spotOnTime * e.sampleRate);

%     sampleSet = (0:(sampleCount_total-1))'; % (1) total
%     sampleSet = (0:(sampleCount_on-1))'; % (2) just during spot
    
    if isfield(processOptions, 'temporalBufferSize') % the amount of time to leave off the start and end of the Spot On Period
        temporalBufferSize = processOptions.temporalBufferSize;
    else
        temporalBufferSize = [.1, .2];
    end
    if length(temporalBufferSize) > 1
        buffer = round(sampleCount_on * temporalBufferSize);
        sampleSet = ((0+buffer(1)):(sampleCount_on - 1 - buffer(2)))'; % (2) just during spot
    else
        buffer = round(sampleCount_on * temporalBufferSize);
        sampleSet = ((0+buffer):(sampleCount_on - 1 - buffer))'; % (2) just during spot
    end
    %     sampleSet = (sampleCount_on:(sampleCount_total-1))'; % (3) just during post-spot
    
    if skipResponses == 1
        continue
    end
    
    if max(e.response) == 0
        continue
    end
    
    if strcmp(e.epochMode, 'flashingSpots')
        
        prevPosition = nan;
        for si = 1:e.totalNumSpots
            spot_position = positions(si,:);
            spot_intensity = intensities(si);

            segmentStartTime = e.spotTotalTime * (si - 1) + t_offset;
            segmentStartIndex = find(e.t > segmentStartTime, 1);
            if isempty(segmentStartIndex)
                continue
            end
    %         t_range = (t - t_offset) > spotTotalTime * (si - 1) & (t - t_offset) < spotTotalTime * si;

            segmentIndices = segmentStartIndex + sampleSet;

            if size(e.response, 1) < segmentStartIndex + sampleCount_total % off the end of the recording
                continue
            end

            % add distance from previous spot to check for overlap effects
            %                      1   2   3           4         5          6          7          8             9              10                11               12           13           14
            observationColumns = {'X','Y','intensity','voltage','respMean','respPeak','tHalfMax','distFromPrev','sourceEpoch','signalStartIndex','signalEndIndex','adaptSpotX','adaptSpotY','adaptSpotEnabled'};
            oi = oi + 1;
            resp = e.response(segmentIndices);

    %         if abs(e.ampVoltage) > 0 % a nice alignment for the whole cell data
    %             resp = resp - mean(resp(1:10));
    %         end
    
            mn = mean(resp);
            pk = max(resp);
            if e.ampVoltage < 0
                pk = min(resp);
            end
            if pk > 0
                del = find(resp > pk / 2.0, 1, 'first') / e.sampleRate;
            else
                del = nan;
            end
            dist = sqrt(sum((spot_position - prevPosition).^2));
            obs = [spot_position, spot_intensity, e.ampVoltage, mn, pk, del, dist, ei, segmentStartIndex, segmentStartIndex + sampleCount_total, nan, nan, 0];
            observations(oi,1:length(obs)) = obs;
            prevPosition = spot_position;

    %         responseData{all_position_index, :}


    %         title(si)
    %         if max(spikeRate_by_spot(si,:)) > 0
    %             plot(e.t(segmentIndices), spikeRate_by_spot(si,:))
    %             drawnow
    %             pause
    %         end


    %         spikes = spikeTimes > t_range(1) & spikeTimes < t_range(2);
    %         spikeRate_by_spot(end+1,:) = spikeRateSegment;
    %         responseValues(end+1,1) = sum(spikes);
        end
    end
    
    if strcmp(e.epochMode, 'adaptationRegion')

        
        % find adaptation regions and make indices
        adapters = flickerFreq > 0;
        adaptMatrix = e.shapeDataMatrix(adapters,:);
        num_adapters = sum(adapters);
        
        % get adaptation start time
        adaptStartTime = adaptMatrix(1, col_startTime); % just use one, assuming they come on simultaneously and only once
        
        % remove them from the data
        probeMatrix = e.shapeDataMatrix;
        probeMatrix(adapters, :) = [];
        
        % loop through probe spots
        num_probes = size(probeMatrix, 1);
        for ri = 1:num_probes
            spot = probeMatrix(ri,:);
                    
            spot_start = spot(1, col_startTime);
            spot_position = spot(1, [col_x, col_y]);
            spot_intensity = spot(1, col_intensity);
            
            % select nearest adaptation region index
            minDist = inf;
            adaptSpotindex = nan;
            for ai = 1:num_adapters
                adaptPos = adaptMatrix(ai, [col_x, col_y]);
                d = sum((adaptPos - spot_position).^2);
                if d < minDist
                    adaptSpotindex = ai;
                    minDist = d;
                end
            end
            adaptSpotPosition = adaptMatrix(adaptSpotindex, [col_x, col_y]);
           
            % make observation & add to data

            segmentStartTime = spot(1, col_startTime) + t_offset;
            segmentStartIndex = find(e.t > segmentStartTime, 1);
            segmentEndIndex = find(e.t > spot(1, col_endTime) + t_offset, 1);
            
            if isempty(segmentStartIndex) || isempty(segmentEndIndex)
                continue
            end            
            
            segmentIndices = segmentStartIndex:segmentEndIndex;
            %                      1   2   3           4         5          6          7          8             9              10                11               12           13           14
            observationColumns = {'X','Y','intensity','voltage','respMean','respPeak','tHalfMax','distFromPrev','sourceEpoch','signalStartIndex','signalEndIndex','adaptSpotX','adaptSpotY','adaptSpotEnabled'};
            oi = oi + 1;
            resp = e.response(segmentIndices);

            mn = mean(resp);
            pk = max(resp);
            if pk > 0
                del = find(resp > pk / 2.0, 1, 'first') / e.sampleRate;
            else
                del = nan;
            end
            dist = 0;
            obs = [spot_position, spot_intensity, e.ampVoltage, mn, pk, del, dist, ei, segmentStartIndex, segmentEndIndex, adaptSpotPosition, spot_start > adaptStartTime];
            observations(oi,1:length(obs)) = obs;
            
            % use object to hold observation
%             obObject = ShapeObservation();
%             obObject.extractResults(resp);
%             obObject.signalStartIndex = segmentStartIndex;
%             obObject.signalEndIndex = segmentEndIndex;
            
            
        end
    end

end


% overall analysis


validSearchResult = num_positions > 3;


% store data for the next stages of processing/output
ad.positions = all_positions;
ad.observations = observations;
ad.observationColumns = observationColumns;
ad.timeOffset = t_offset;
ad.validSearchResult = validSearchResult;
ad.sampleSet = sampleSet;

end