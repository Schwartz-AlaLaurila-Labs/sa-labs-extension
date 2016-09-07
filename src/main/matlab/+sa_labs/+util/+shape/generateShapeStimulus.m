function runConfig = generateShapeStimulus(p, analysisData)

    runConfig = struct();
    runConfig.autoContinueRun = false;
    
    % select the type of epoch to run based on params & results

    if strcmp(p.mode, 'temporalAlignment')
        runConfig = generateTemporalAlignment(p, runConfig);
        
    elseif strcmp(p.mode, 'receptiveField')
%             if parameters.refineEdges && analysisData.validSearchResult
%                 runConfig = generateSpatialRefineEdges(parameters, analysisData, runConfig);
%             else
        runConfig = generateStandardSearch(p, analysisData, runConfig);
%             end

    elseif strcmp(p.mode, 'temporalAlignment')
        runConfig = generateTemporalAlignment(p, runConfig);
        
    elseif strcmp(p.mode, 'isoResponse')
        if ~analysisData.validSearchResult
            runConfig = generateStandardSearch(p, analysisData, runConfig);
        else
            runConfig = generateIsoResponse(p, analysisData, runConfig);
        end
        
    elseif strcmp(p.mode, 'refineVariance')
        runConfig = generateRefineVariance(p, analysisData, runConfig);
        
    elseif strcmp(p.mode, 'adaptationRegion')
        runConfig = generateAdaptationRegionStimulus(p, analysisData, runConfig);
        
    elseif strcmp(p.mode, 'null')
        runConfig = generateNullStimulus(p, analysisData, runConfig);
        
    else
        fprintf('error no usable mode %s', p.mode);
    end
    
    % set the auto continue bit for after this epoch finishes
%     if p.timeRemainingSeconds - (runConfig.stimTime / 1000) < 0
%         runConfig.autoContinueRun = false;
%     end
    
end

function runConfig = generateNullStimulus(parameters, analysisData, runConfig)

    runConfig.shapeDataMatrix = [];
    runConfig.shapeDataColumns = {};
    runConfig.stimTime = 0;
    runConfig.numShapes = 1;
end

function runConfig = generateTemporalAlignment(parameters, runConfig)

    runConfig.epochMode = 'temporalAlignment';
    runConfig.numShapes = 1;
    durations = [1, 0.6, 0.4]; % full durations, and the spot is on for 1/3 of that time
    runConfig.shapeDataMatrix = [];

    curtime = 0;
    for dur = durations
        shape = [0, 0, parameters.valueMax, curtime, curtime + dur / 3, parameters.alignmentSpotDiameter, 0];
        runConfig.shapeDataMatrix = vertcat(runConfig.shapeDataMatrix, shape);
        curtime = curtime + dur;
    end
    
    % then add smaller spot, long ON, long OFF
    temporalFilterSpotDiam = 100;
    temporalFilterSpotOnTime = 1.5;
    temporalFilterSpotOffTime = 1.5;
    shape = [0, 0, parameters.valueMax, curtime, curtime + temporalFilterSpotOnTime, temporalFilterSpotDiam, 0];
    runConfig.shapeDataMatrix = vertcat(runConfig.shapeDataMatrix, shape);
    curtime = curtime + temporalFilterSpotOnTime + temporalFilterSpotOffTime;
    
    runConfig.shapeDataColumns = {'X','Y','intensity','startTime','endTime','diameter', 'flickerFrequency'};
    runConfig.stimTime = round(1e3 * (0.5 + curtime)); % add a half second on for fun
    
end

function runConfig = generateStandardSearch(parameters, analysisData, runConfig)
    

    % choose center position and search width
    center = [0,0];
    searchDiameterUpdated = parameters.searchDiameter;

%     if parameters.refineCenter && analysisData.validSearchResult == 1
%         gfp = analysisData.gaussianFitParams_ooi{3};
% 
%         center = [gfp('centerX'), gfp('centerY')];
%         refineSizeMultiplier = 2;
%         searchDiameterUpdated = refineSizeMultiplier * max([gfp('sigma2X'), gfp('sigma2Y')]) + 1;
%     end

    % select positions
    if parameters.generatePositions
        si = parameters.pointSetIndex;
        if si == 1
            center = [0,0];
        elseif si == 2
            center = [-.5, .4330] * parameters.mapResolution;
        elseif si == 3
            center = [0, .649] * parameters.mapResolution;
        elseif si == 4
            center = [0, .325] * parameters.mapResolution;
        elseif si == 5
            center = [.5, .1] * parameters.mapResolution;
        elseif si > 5
            center = rand(1,2) * parameters.mapResolution;
        end
        
        
%         center = mod(parameters.epochNum * 2 * [1,1], 10); % a bit of jitter makes the graph look nicer
%         rotAngle = parameters.epochNum * 0.3; % sure, why not, doesn't matter the real value
        rotAngle = 0;
%         positions = generatePositions('random', [parameters.numSpots, parameters.spotDiameter, searchDiameterUpdated / 2]);
        %             positions = generatePositions('grid', [obj.searchDiameter, round(sqrt(obj.numSpots))]);
        positions = generatePositions('triangular', [searchDiameterUpdated / 2, parameters.mapResolution, rotAngle]);
        
        % add center offset
        positions = bsxfun(@plus, positions, center);
%         parameters.numSpots = size(positions, 1);
    else
        positions = analysisData.positions;
    end

    % generate intensity values and repeats
    parameters.numPositions = size(positions,1);
    runConfig = makeFlashedSpotsMatrix(parameters, runConfig, positions);
end


function runConfig = generateIsoResponse(parameters, analysisData, runConfig)
    
    runConfig.epochMode = 'flashingSpots';
    
    % find active spots
    num_positions = size(analysisData.responseData,1);
    validPositionIndices = [];
    values = [];
    for p = 1:num_positions
        responses = analysisData.responseData{p,3};
        valid = any(responses(:,2) > 0);
        if valid
            validPositionIndices = vertcat(validPositionIndices, p);
            values = vertcat(values, responses(:,2));
        end
    end
    
    num_positions = length(validPositionIndices)
    positions = analysisData.positions(validPositionIndices, :);

%         histogram(values, 20);
        
        % find target response value from distribution of response values
    if isfield(analysisData, 'targetIsoValue')
        runConfig.targetIsoValue = analysisData.targetIsoValue;
    else        
        runConfig.targetIsoValue = median(values);
    end
    
    targetValue = runConfig.targetIsoValue
    
    % fit lines to response curves at each spot,
    % find target light intensity
    intensities = zeros(num_positions, 1);
    warning('off','MATLAB:polyfit:PolyNotUnique');
    for p = 1:num_positions
        responses = analysisData.responseData{validPositionIndices(p),3};
        responses = sortrows(responses, 1); % order by intensity values for plot
        intensity = responses(:,1);
        value = responses(:,2);
        pfit = polyfit(intensity, value, 1);
        
        targetIntensity = (runConfig.targetIsoValue - pfit(2)) / pfit(1)
        realIntensity = min(max(targetIntensity, .00001), 1.0);
        intensities(p,1) = realIntensity;
    end
    % create shapeMatrix for those intensities
    
    starts = (0:(num_positions-1))' * parameters.spotTotalTime;
    ends = starts + parameters.spotOnTime;
    diams = parameters.spotDiameter * ones(length(starts), 1);
    frequencies = zeros(size(starts));
    
    sdm = horzcat(positions, intensities, starts, ends, diams, frequencies);
    
    runConfig.shapeDataMatrix = [];
    numRepeatsIso = 2; % use averaging in isoresponse 
    for i = 1:numRepeatsIso
        runConfig.shapeDataMatrix = vertcat(runConfig.shapeDataMatrix, sdm);
    end
    
    % shuffle ordering
    ordering = [0;0];
    while any(diff(ordering) == 0) % make sure no repeats
        ordering = randperm(size(runConfig.shapeDataMatrix,1))';
    end
    runConfig.shapeDataMatrix = runConfig.shapeDataMatrix(ordering,:);
    runConfig.shapeDataColumns = {'X','Y','intensity','startTime','endTime','diameter','flickerFrequency'};
    runConfig.stimTime = round(1e3 * (1 + ends(end)));
    runConfig.numShapes = 1;
end

function runConfig = generateRefineVariance(parameters, analysisData, runConfig)
    runConfig.epochMode = 'flashingSpots';
    obs = analysisData.observations;
    % get a list of all of the option sets: position, intensity, voltage
    settings = unique(obs(:,1:4), 'rows');
    stds = zeros(size(settings,1), 1);
       
    % get the variance for each option set
    for si = 1:size(settings,1)
        sett = settings(si,:);
        obs_sel = ismember(obs(:,1:4), sett, 'rows');
        stds(si,1) = std(obs(obs_sel,5),1);
    end

    % select those to be repeated (remove voltage, assume alternateVoltage
    % is enabled in the stimulus)
    s = sortrows(horzcat(stds, settings), 1);
    settings = s(:,2:end);
    
    numSettings = floor(length(settings,1) * parameters.variancePercentile);
    settings_select = settings(1:numSettings,:);
    
    positions = settings_select(:,1:2);
    
    
    % generate the flashing spots
    runConfig = makeFlashedSpotsMatrix(parameters, runConfig, positions);
end



function runConfig = generateAdaptationRegionStimulus(p, analysisData, runConfig)
    runConfig.epochMode = 'adaptationRegion';
    
    numAdaptationPositions = size(p.adaptationSpotPositions,1);
    runConfig.numShapes = numAdaptationPositions + 1;

    % first time setup / all for now
%     for ai = 1:numAdaptationPositions
    % make array of spot positions around 
    probePositions = generatePositions('triangular', [p.probeSpotPositionRadius, p.probeSpotSpacing, 0]);
    numProbeSpots = size(probePositions, 1);
    probePositions = probePositions(randperm(numProbeSpots), :); % randomly reorder, but I suppose use the same for each adapt spot
    probePositions_by_adapt = cell(numAdaptationPositions,1);
    for ai = 1:numAdaptationPositions
        probePositions_by_adapt{ai,1} = bsxfun(@plus, probePositions, p.adaptationSpotPositions(ai,:));
    end        
    
    positions = [];
    starts = [];
    intensities = [];
    
    % get curves before & after adaptation
    si = 1;
    delay = 0.5; % add a little delay to start to ensure a baseline
    for prePostAdapt = 1:2
        for repeat = 1:p.probeSpotRepeats
            for val = p.probeSpotValues
                for pri = 1:numProbeSpots
                    for adapti = 1:numAdaptationPositions
                        positions(si,1:2) = probePositions_by_adapt{adapti}(pri,:);
                        starts(si,1) = (si - 1) * (p.probeSpotDuration * 1.5) + delay;
                        intensities(si,1) = val;
                        si = si + 1;
                    end
                end
            end
        end
        if prePostAdapt == 1
            flickerStartTime = starts(end) + 1;
            delay = p.adaptSpotWarmupTime + delay;
        end
    end

    ends = starts + p.probeSpotDuration;
    diams = p.probeSpotDiameter * ones(length(starts), 1);
    frequencies = zeros(size(starts));
    
    % then add the adapting points to end
    col = ones(numAdaptationPositions, 1);
    adaptPoints = [p.adaptationSpotPositions, p.adaptationSpotIntensity * col, flickerStartTime * col, (ends(end) + 1) * col, p.adaptationSpotDiameter * col, p.adaptationSpotFrequency * col];
        
    runConfig.shapeDataMatrix = horzcat(positions, intensities, starts, ends, diams, frequencies);
    runConfig.shapeDataMatrix = vertcat(runConfig.shapeDataMatrix, adaptPoints);
    runConfig.shapeDataColumns = {'X','Y','intensity','startTime','endTime','diameter','flickerFrequency'};
    runConfig.stimTime = round(1e3 * (1 + ends(end)));
    
end




function runConfig = generateSpatialRefineEdges(parameters, analysisData, runConfig)

    % TODO: this should really repeat the points used as slope endpoints to
    % improve the stability of the refinement, so we don't end up with
    % compacting noise patterns

    runConfig.shapeDataMatrix = [];
    rData = analysisData.maxIntensityResponses(:,3);
    num_positions = size(rData,1);
    
    % distances between points
    distances = squareform(pdist(analysisData.positions, 'euclidean'));

    slopes = zeros(num_positions .^ 2, 3); % p1, p2, slope
    
    % find points pairs with highest slope TODO: find points with high variance in response
    for p1 = 1:num_positions
        r1 = rData(p1);
        for p2 = 1:(p1-1)
            r2 = rData(p2);
            d = distances(p1, p2);
            slope = abs(r2 - r1) / d;
            slopes((p1 - 1) * num_positions + p2, :) = [p1, p2, slope];
        end
    end
    slopes(slopes(:,1) == 0, :) = [];
    
    % using slopes, find points between
    slopes = sortrows(slopes, 3);
    positions = zeros(parameters.numSpots, 2);
    for p = 1:parameters.numSpots
        pos1 = analysisData.positions(slopes(p,1), :);
        pos2 = analysisData.positions(slopes(p,2), :);
        midpos = mean([pos1;pos2], 2);
        positions(p,:) = midpos;
    end
    parameters.numPositions = num_positions;
    runConfig = makeFlashedSpotsMatrix(parameters, runConfig, positions);
end


function runConfig = makeFlashedSpotsMatrix(parameters, runConfig, positions)
    runConfig.epochMode = 'flashingSpots';
    runConfig.numShapes = 1;
    
    if isfield(parameters, 'useGivenValues') && parameters.useGivenValues
        values = parameters.values;
    else
        values = linspace(parameters.valueMin, parameters.valueMax, parameters.numValues);
    end
    positionList = [];
    starts = [];
    stream = RandStream('mt19937ar');

    si = 1; %spot index
    for repeat = 1:parameters.numValueRepeats
        usedValues = zeros(parameters.numPositions, parameters.numValues);
%         usedValues = [];
        for l = 1:parameters.numValues
            positionIndexList = randperm(stream, parameters.numPositions);
            for i = 1:parameters.numPositions
                curPosition = positionIndexList(i);
%                 curPosition = i;
                possibleNextValueIndices = find(usedValues(curPosition,:) == 0);
                nextValueIndex = possibleNextValueIndices(randi(stream, length(possibleNextValueIndices)));

                positionList(si,:) = [positions(curPosition,:), values(nextValueIndex)]; %#ok<*AGROW>
                usedValues(curPosition, nextValueIndex) = 1;

                starts(si,1) = (si - 1) * parameters.spotTotalTime;

                si = si + 1;
            end
        end
    end
    diams = parameters.spotDiameter * ones(length(starts), 1);
    ends = starts + parameters.spotOnTime;
    frequencies = zeros(size(starts));

    %                 obj.stimTimeSaved = round(1000 * (ends(end) + 1.0));

    runConfig.shapeDataMatrix = horzcat(positionList, starts, ends, diams, frequencies);
    runConfig.shapeDataColumns = {'X','Y','intensity','startTime','endTime','diameter','flickerFrequency'};
    runConfig.stimTime = round(1e3 * (1 + ends(end)));
end


