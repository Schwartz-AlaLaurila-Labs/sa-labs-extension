function [] = plotShapeData(ad, mode, options)
% display the shape data in ad (analysisData), using the string mode, with struct options

if ~isfield(ad,'observations')
    disp('no observations');
    return 
end
obs = ad.observations;

if nargin < 3
    options = struct();
end

if strcmp(mode, 'printParameters')
    % display of epoch parameters
    firstEpoch = ad.epochData{1};
    fprintf('num positions: %d\n', length(ad.positions));
    fprintf('num values: %d\n', firstEpoch.numValues);
    fprintf('num repeats: %d\n',firstEpoch.numValueRepeats);
    voltages = [];
    for i = 1:length(ad.epochData)
        voltages(i) = ad.epochData{i}.ampVoltage; %#ok<*AGROW>
    end
    fprintf('holding voltages: %d\n', voltages');

    disp(ad);
    
    disp(ad.epochData{end})
   
    
elseif strncmp(mode, 'plotSpatial', 11)
    
    % general purpose spatial display function, shows all observations by voltage and intensity

    if isempty(obs)
        disp('empty observations')
        return
    end

    combinationMode = 'mean';
    if contains(mode, 'mean')
        mode_col = 5;
        modeLabel = 'mean';
    elseif contains(mode, 'peak')
        mode_col = 6;
        modeLabel = 'peak';
    elseif contains(mode, 'median')
        mode_col = 5;
        modeLabel = 'median of means';
        combinationMode = 'median';
    elseif contains(mode, 'first')
        mode_col = 5;
        modeLabel = 'first';
        combinationMode = 'first';        
    elseif contains(mode, 'last')
        mode_col = 5;
        modeLabel = 'last';
        combinationMode = 'last';            
    elseif contains(mode, 'tHalfMax')
        mode_col = 7;
        modeLabel = 't half max';
    elseif contains(mode, 'saveMaps')
        mode_col = 5;
        modeLabel = 'saveMaps';        
    end
   
    
    voltages = sort(unique(obs(:,4)));
    num_voltages = length(voltages);
        
    intensities = sort(unique(obs(:,3)));
    num_intensities = length(intensities);
    
    dataByVoltageIntensity = cell(num_voltages, num_intensities, 2);
    gfits = {};
    
    ha = tight_subplot(num_intensities, num_voltages+1);
    for vi = 1:num_voltages
        for ii = 1:num_intensities
            intensity = intensities(ii);
            voltage = voltages(vi);
            
%             vals = zeros(length(ad.positions),1);
            vals = [];
            posIndex = 0;
            goodPositions = [];
            for poi = 1:length(ad.positions)
                pos = ad.positions(poi,:);
                obs_sel = ismember(obs(:,1:2), pos, 'rows');
                obs_sel = obs_sel & obs(:,3) == intensity;
                obs_sel = obs_sel & obs(:,4) == voltage;
                if strcmp(combinationMode, 'mean')
                    val = nanmean(obs(obs_sel, mode_col),1);
                elseif strcmp(combinationMode, 'median')
                    val = nanmedian(obs(obs_sel, mode_col),1);
                elseif strcmp(combinationMode, 'first')
                    val = obs(obs_sel, mode_col);
                    try
                        val = val(1);
                    catch
                    end
                elseif strcmp(combinationMode, 'last')
                    val = obs(obs_sel, mode_col);
                    try
                        val = val(end);
                    catch
                    end
                end
                if any(obs_sel) && ~isnan(val)
                    posIndex = posIndex + 1;
                    vals(posIndex,1) = val;
                    goodPositions(posIndex,:) = pos;
                end
            end
            
            a = vi + (ii-1) * (num_voltages+1);
            
            axes(ha(a));

            if posIndex >= 3
                gfits{a,1} = plotSpatial(goodPositions, vals, sprintf('%s at V = %d mV, intensity = %f', modeLabel, voltage, intensity), 1, sign(voltage) + .001);
                gfits(a, 2:3) = {voltage, intensity};
%                 if ~isnan(gfit)
%     %             caxis([0, max(vals)]);
%     %             colormap(flipud(colormap))
%                     disp(gfit.keys)
%                     disp(cell2mat(gfit.values))
%                 else
%                     disp('NaN fit');
%                 end
            end

            dataByVoltageIntensity(vi, ii, 1:2) = {goodPositions, vals};
        end
    end
    
    % plot all the pathway gaussian fits on one graph
    axes(ha(num_voltages+1))
    for a = 1:size(gfits,1)
        gfit = gfits{a,1};
        if isempty(gfit)
            continue
        end
        
        voltage = gfits{a,2};
        intensity = gfits{a,3};
        if voltage < 0
            % excitation
            if intensity > 0.5
                % ON (blue)
                num_columns = [0,0,1];
            else
                % OFF (green)
                num_columns = [0,1,0];
            end
        else
            % inhibition
            if intensity > 0.5
                % ON (red)
                num_columns = [1 0 0];
            else
                % OFF (yellow)
                num_columns = [.6 .6 0];
            end
        end
        
        e = ellipse(gfit('sigma2X'), gfit('sigma2Y'), -gfit('angle'), gfit('centerX'), gfit('centerY'), num_columns);
        set(e, 'LineWidth', 2);
        line(gfit('centerX') + [-l, l]/2, gfit('centerY') * [1,1], 'LineWidth', 1.5, 'Color', num_columns);
        line(gfit('centerX') * [1,1], gfit('centerY') + [-l, l]/2, 'LineWidth', 1.5, 'Color', num_columns);
        
    end
%     axis square
    axis equal
    
    if strcmp(modeLabel, 'saveMaps')
        save('savedMaps.mat', 'data','voltages','intensities');
        disp('saved maps to savedMaps.mat');
    end
    
    
elseif strcmp(mode, 'overlap')
    % pretty print of thresholded spatial RFs, overlaid by On Off and Ex In pathways.
    % default: options.overlapThresoldPercentile = 80

    if isempty(obs)
        disp('empty observations')
        return
    end
    
    mode_col = 5; % mean
    
    voltages = sort(unique(obs(:,4)));
    voltages = [voltages(1), voltages(end)];
    num_voltages = length(voltages);
        
    intensities = sort(unique(obs(:,3)));
    num_intensities = length(intensities);
        
    paramsByPlot = {[1 1; 0 0], [0 0; 1 1], [0 1; 0 1], [1 0; 1 0]};
    titlesByPlot = {'Excitation','Inhibition','On','Off'};
    
    hh = {};
    for i = 1:4
        hh{i} = tight_subplot(num_intensities, num_voltages, 0);
    end
    
    for pp = 1:length(paramsByPlot)
        for vi = 1:num_voltages
            for ii = 1:num_intensities
                a = vi + (ii-1) * num_voltages;
                ax = hh{a};
                axes(ax(pp))
                axis(ax(pp), 'off');
                
                if ~paramsByPlot{pp}(vi, ii)
                    continue
                end
                
                intensity = intensities(ii);
                voltage = voltages(vi);

    %             vals = zeros(length(ad.positions),1);
                vals = [];
                posIndex = 0;
                goodPositions = [];
                for poi = 1:length(ad.positions)
                    pos = ad.positions(poi,:);
                    obs_sel = ismember(obs(:,1:2), pos, 'rows');
                    obs_sel = obs_sel & obs(:,3) == intensity;
                    obs_sel = obs_sel & obs(:,4) == voltage;
                    val = nanmean(obs(obs_sel, mode_col),1);
                    if any(obs_sel) && ~isnan(val)
                        posIndex = posIndex + 1;
                        vals(posIndex,1) = val;
                        goodPositions(posIndex,:) = pos;
                    end
                end

                % thresholding
                vals = sign(voltage) * vals;
                if isfield(options, 'overlapThresoldPercentile')
                    percentile = options.overlapThresoldPercentile;
                else
                    percentile = 80;
                end
                thresholdLevel = prctile(vals, percentile);

                n = 1;
                % make colormaps for each surface
                if sign(voltage) < 0
                    % excitation
                    if intensity > 0.5
                        % ON (blue)
                        cmap = horzcat(zeros(n,2), linspace(.6,1,n)');
                    else
                        % OFF (green)
                        cmap = horzcat(zeros(n,1), linspace(.6,1,n)', zeros(n,1));
                    end
                else
                    % inhibition
                    if intensity > 0.5
                        % ON (red)
                        cmap = horzcat(linspace(.6,1,n)', zeros(n,2));
                    else
                        % OFF (yellow)
                        cmap = horzcat(linspace(.2,.6,n)', linspace(.2,.6,n)', zeros(n,1));
                    end
                end


                if posIndex >= 3
                    positions = goodPositions;
                    values = vals;
                    largestDistanceOffset = .8*max(abs(positions(:)));
                    X = linspace(-1*largestDistanceOffset, largestDistanceOffset, 200);
                    [xq,yq] = meshgrid(X, X);
                    num_columns = griddata(positions(:,1), positions(:,2), values, xq, yq);

                    num_columns(num_columns < thresholdLevel) = nan;

                    s = surface(xq, yq, zeros(size(xq)), num_columns);
                    alpha(s, .4);
                    grid off
                    axis equal
                    shading interp
                    colormap(gca(), cmap);
                    l = 100;
                    line([-l, l]/2, [0,0], 'LineWidth', 1, 'Color', 'k');
                    line([0,0], [-l, l]/2, 'LineWidth', 1, 'Color', 'k');
                end

            end
        end
        
        title(titlesByPlot{pp})
    end
    
elseif strcmp(mode, 'subunit') % contrast responses for each position

%     if ad.numValues > 1
    
        %% Plot figure with subunit models
    %     figure(12);


        % only use positions with observations (ignore 0,0)
        positions = [];
        i = 1;
        for pp = 1:size(ad.positions,1)
            pos = ad.positions(pp,1:2);
            if any(ismember(obs(:,1:2), pos, 'rows'))
                positions(i,1:2) = pos;
                i = i + 1;
            end
        end
        num_positions = size(positions,1);
        dim1 = floor(sqrt(num_positions));
        dim2 = ceil(num_positions / dim1);
        
        % nice way of displaying plots with an aligned-to-grid location using percentiles
        pos_sorted = flipud(sortrows(positions, 2));
        for i = 1:dim1 % chunk positions by display rows
            l = ((i-1) * dim2) + (1:dim2);
            l(l > num_positions) = [];
            pos_sorted(l,:) = sortrows(pos_sorted(l,:), 1);
        end
        positions = pos_sorted;
        
%         num_positions = size(ad.positions,1);
%         dim1 = floor(sqrt(num_positions));
%         dim2 = ceil(num_positions / dim1);
        
        ha = tight_subplot(dim1,dim2, .02);
        
        obs = ad.observations;
        if isempty(obs)
            return
        end
        voltages = unique(obs(:,4));
        num_voltages = length(voltages);
        
        
        goodPosIndex = 0;
        goodPositions = [];
        goodSlopes = [];
        for p = 1:num_positions
%             tight_subplot(dim1,dim2,p)
            axes(ha(p)) %#ok<*LAXES>
            hold on
            
            pos = positions(p,:);
            obs_sel = ismember(obs(:,1:2), pos, 'rows');
            
            for vi = 1:num_voltages
                voltage = voltages(vi);
                obs_sel_v = obs_sel & obs(:,4) == voltage;
            
                responses = obs(obs_sel_v, 6); % peak: 6, mean: 5
                intensities = obs(obs_sel_v, 3);

                plot(intensities, responses, 'o')
                if length(unique(intensities)) > 1
                    pfit = polyfit(intensities, responses, 1);
                    plot(intensities, polyval(pfit,intensities))
                    
                    
                    goodPosIndex = goodPosIndex + 1;
                    goodPositions(goodPosIndex, :) = pos;
%                     goodSlopes(goodPosIndex, 1) = mean(responses(intensities == 1)) - mean(responses(intensities == 0))
                    goodSlopes(goodPosIndex, 1) = pfit(1);
                end
%                 title(pos)
%                 ylim([0,6])
%                 yticks([])
                xticks([])
            end
            grid on
            hold off
            
%             set(gca, 'XTickMode', 'auto', 'XTickLabelMode', 'auto')
            set(gca, 'YTickMode', 'auto', 'YTickLabelMode', 'auto')

        end
        
        if ~isempty(goodPositions)
            figure(99);clf;
%             goodSlopes(abs(goodSlopes) < 2) = 0;
            plotSpatial(goodPositions, goodSlopes, 'intensity response slope', 1, 0)
        end
        
%         set(ha(1:end-dim2),'XTickLabel','');
%         set(ha,'YTickLabel','')
%     else
%         disp('No multiple value subunits measured');
%     end
    


elseif strcmp(mode, 'currentVoltage')
        % IV plots by position
    
        % only use positions with observations (ignore 0,0)
        positions = [];
        i = 1;
        for pp = 1:size(ad.positions,1)
            pos = ad.positions(pp,1:2);
            if any(ismember(obs(:,1:2), pos, 'rows'))
                positions(i,1:2) = pos;
                i = i + 1;
            end
        end
        
        num_positions = size(positions,1);
        dim1 = floor(sqrt(num_positions));
        dim2 = ceil(num_positions / dim1);
        
        % nice way of displaying plots with an aligned-to-grid location using percentiles
        pos_sorted = flipud(sortrows(positions, 2));
        for i = 1:dim1 % chunk positions by display rows
            l = ((i-1) * dim2) + (1:dim2);
            l(l > num_positions) = [];
            pos_sorted(l,:) = sortrows(pos_sorted(l,:), 1);
        end
        positions = pos_sorted;
        
%         num_positions = size(ad.positions,1);
%         dim1 = floor(sqrt(num_positions));
%         dim2 = ceil(num_positions / dim1);
        
        ha = tight_subplot(dim1,dim2, .01);
        
        obs = ad.observations;
        if isempty(obs)
            return
        end
              
        
%         goodPosIndex = 0;
%         goodPositions = [];
%         goodSlopes = [];
        for p = 1:num_positions
%             tight_subplot(dim1,dim2,p)
%             axes() %#ok<*LAXES>
%             hold on
            
            pos = positions(p,:);
            obs_sel = ismember(obs(:,1:2), pos, 'rows');
            intensities = unique(obs(obs_sel, 3));
            
            for ii = 1:length(intensities)
                intensity = intensities(ii);
                obs_sel_i = obs_sel & obs(:,3) == intensity;
            
                voltages = unique(obs(obs_sel,4));
                num_voltages = length(voltages);

                responses = [];
                for vi = 1:num_voltages
                    voltage = voltages(vi);
                    obs_sel_v = obs_sel_i & obs(:,4) == voltage;

                    responses(vi) = mean(obs(obs_sel_v, 5)); % peak: 6, mean: 5
                end
                plot(ha(p), voltages, responses)
                hold(ha(p), 'on');
            end


%                 if length(unique(intensities)) > 1
%                     pfit = polyfit(intensities, responses, 1);
%                     plot(intensities, polyval(pfit,intensities))
%                     
%                     
%                     goodPosIndex = goodPosIndex + 1;
%                     goodPositions(goodPosIndex, :) = pos;
% %                     goodSlopes(goodPosIndex, 1) = mean(responses(intensities == 1)) - mean(responses(intensities == 0))
%                     goodSlopes(goodPosIndex, 1) = pfit(1);
%                 end
%                 title(pos)
%                 ylim([0,6])
%                 yticks([])
%                 xticks([])
%             end
%             grid on
%             hold off
            
%             set(gca, 'XTickMode', 'auto', 'XTickLabelMode', 'auto')
            set(ha(p), 'YTickMode', 'auto', 'YTickLabelMode', 'auto')
            xlim(ha(p), [min(voltages),max(voltages)])
            line(xlim(ha(p)), [0,0], 'Parent',ha(p), 'color','k')

        end
        
        linkaxes(ha)
        
%         if ~isempty(goodPositions)
%             figure(99);clf;
% %             goodSlopes(abs(goodSlopes) < 2) = 0;
%             plotSpatial(goodPositions, goodSlopes, 'intensity response slope', 1, 0)
%         end
        
%         set(ha(1:end-dim2),'XTickLabel','');
        set(ha,'YTickLabel','')
        set(ha,'XTickLabel','')
        legend(ha(1),{'off','on'},'location','best')
%     else
%         disp('No multiple value subunits measured');
%     end


elseif strcmp(mode, 'temporalResponses')
    % simple display of temporal responses, which are the raw input to the system
    % displays spot intensity using the same signal used for cross correlation
    
    num_plots = length(ad.epochData);
    ha = tight_subplot(num_plots, 1, .03);
    
    for ei = 1:num_plots
        t = ad.epochData{ei}.t;
        resp = ad.epochData{ei}.response;
        
        % play with exponential fitting:
%         if max(t) > 5
%             resp = resp - mean(resp((end-100):end)); % set end to 0
%             startA = mean(resp(1:100))/exp(0);
%             startB = -0.3;
%             f = fit(t(1:end), resp(1:end), 'exp1','StartPoint',[startA, startB]);
%             expFit = f(t);
%             f
%         else
%             expFit = zeros(size(t));
%         end
        
        % display original and shifted light On signal
        plot(ha(ei), t, resp,'b');
        hold(ha(ei), 'on');
        light = ad.epochData{ei}.signalLightOn;
        if abs(min(resp)) > abs(max(resp))
            light = light * -1;
        end
        light = light * max(abs(resp)) * 0.5;
        plot(ha(ei), ad.epochData{ei}.timeOffset + t, light,'r')
        
%         resp = smooth(resp, 20);
%         plot(ha(ei), t, resp,'g');
        hold(ha(ei), 'off');
        
        
%         hold(ha(ei), 'on');
%         plot(ha(ei), t, expFit)
%         plot(ha(ei), t, resp - expFit);
%         hold(ha(ei), 'off');
        
        title(ha(ei), sprintf('Epoch %d at %d mV, time offset %d msec', ei, ad.epochData{ei}.ampVoltage, round(1000 * ad.epochData{ei}.timeOffset)))
%         disp('Normalization parameters:');
%         disp(ad.epochData{ei}.signalNormalizationParameters)
    end
    
    
elseif strcmp(mode, 'temporalComponents')
    % splits spot time period into two components (using a peak finding algorithm) and maps them separately, can find On and Off from a single polarity
    
    warning('off', 'stats:regress:RankDefDesignMat')
    
    % start with finding the times with highest variance, by voltage
    obs = ad.observations;
    paramColumn = 4; % intensity 3, voltage 4
    voltages = sort(unique(obs(:,paramColumn)));

    ha = tight_subplot(length(voltages), 1, .03, .03);

    positions = [];
    i = 1;
    for pp = 1:size(ad.positions,1)
        pos = ad.positions(pp,1:2);
        if any(ismember(obs(:,1:2), pos, 'rows'))
            positions(i,1:2) = pos;
            i = i + 1;
        end
    end    
    
    num_positions = size(positions,1);
    signalsByVoltageByPosition = {};
    peakIndicesByVoltage = {};
    basisByVoltageComp = {};
    maxComponents = 0;

    for vi = 1:length(voltages)
        v = voltages(vi);

        signalsByPosition = cell(num_positions,1);
        for poi = 1:num_positions
            pos = positions(poi,:);

            obs_sel = ismember(obs(:,1:2), pos, 'rows');
            obs_sel = obs_sel & obs(:,paramColumn) == v;
            indices = find(obs_sel);
                        
            signalsThisPos = {};
            for ii = 1:length(indices)
                entry = obs(indices(ii),:)';
                epoch = ad.epochData{entry(9)};
                
                signal = epoch.response(entry(10):entry(11)); % start and end indices into signal vector
                %                         signal = signal - mean(signal(1:10));
                signalsThisPos{ii,1} = signal';
            end
%             signalsThisPos
            maxLength=max(cellfun(@(x)numel(x),signalsThisPos))+1;
            
%             kk = cellfun(@(x)size(x,1),signalsThisPos,'UniformOutput',false)
            
            a = cell2mat(cellfun(@(x)cat(2,x,nan*zeros(1,maxLength-length(x))),signalsThisPos,'UniformOutput',false));
            signalsByPosition{poi,1} = nanmean(a, 1);
            
        end
        maxLength=max(cellfun(@(x)numel(x),signalsByPosition));
        a = cell2mat(cellfun(@(x)cat(2,x,nan*zeros(1,maxLength-length(x))),signalsByPosition,'UniformOutput',false));
        
        signalByV = nanmean(a, 1);
        varByV = nanvar(a, 1);
        varByV = varByV / max(varByV);
        
        signalsByVoltageByPosition{vi,1} = signalsByPosition;
        
%         axes(ha((vi - 1) * 2 + 1))    
        axes(ha(vi));
        t = (1:length(signalByV)) / ad.sampleRate - 1/ad.sampleRate;
        plot(t, signalByV ./ max(abs(signalByV)))
        hold on
        plot(t, varByV)
        title(sprintf('voltage: %d', v))
        legend('mean','variance');
        
%         axes(ha(vi * 2))

        % how about some magic numbers? you want some magic numbers? yeah, yes you do.
        % nice, arbitrary, need to be changed, overfitted magic numbers, right here for you
        % ah, now that's nice, you like magic numbers, so good, have some more, here they are
        [~, peakIndices] = findpeaks(smooth(varByV,30), 'MinPeakProminence',.05,'Annotate','extents','MinPeakDistance',0.08);
%         peakIndices = [80, 380]; % in ms
        maxComponents = max([maxComponents, length(peakIndices)]);
        peakIndicesByVoltage{vi,1} = peakIndices;
        plot(t(peakIndices), varByV(peakIndices), 'ro')
        
        componentWidth = 0.05; % hey, have another one!       
        
        for ci = 1:length(peakIndices)
            basisCenterTime = t(peakIndices(ci));
            basis = 1/sqrt(2*pi)/componentWidth*exp(-(t-basisCenterTime).^2/2/componentWidth/componentWidth);            
            plot(t, basis ./ max(basis) .* varByV(peakIndices(ci)));
            basisByVoltageComp{vi,ci} = basis;
        end

    end
    
    
    figure(21);clf;
    hb = tight_subplot(length(voltages), maxComponents, .03, .03);
    disp('Temporal component fits');
    for vi = 1:length(voltages)
        
        % now, with the peak locations in hand, we can pull out the components
        peakIndices = peakIndicesByVoltage{vi,1};
        num_components = length(peakIndices);
        valuesByComponent = nan * zeros(num_positions, num_components);
        signalsByPosition = signalsByVoltageByPosition{vi,1};
        fitX = [];
        fitY = [];
        for ci = 1:num_components
            basis = basisByVoltageComp{vi,ci};
            for poi = 1:num_positions

                signal = signalsByPosition{poi,1};
                signal(isnan(signal)) = [];
                basisCropped = basis(1:length(signal));
                
                val = regress(signal', basisCropped');
                valuesByComponent(poi, ci) = val;
                
            end

            p = maxComponents * (vi-1) + ci;
            axes(hb(p));
            gfit = plotSpatial(positions, valuesByComponent(:,ci), sprintf('v %d component %d', voltages(vi), ci), 1, sign(voltages(vi)));
            
            if isa(gfit, 'containers.Map')
                fitX(ci) = gfit('centerX');
                fitY(ci) = gfit('centerY');
            end
        end
        
        fprintf('Voltage %g, Off is ( %g, %g) from On\n', voltages(vi), diff(fitX), diff(fitY));
        
    end
    
    
elseif strcmp(mode, 'responsesByPosition')
    % display time traces of responses aligned for each location
    % plots are in a grid roughly similar to the spot spacing
    
    obs = ad.observations;
    voltages = sort(unique(obs(:,4)));
    adaptstates = unique(obs(:,14));
    intensities = sort(unique(obs(:,3)));
    
    num_options = length(voltages) * length(adaptstates) * length(intensities);
    
    colors = hsv(num_options);
    
    % only use positions with observations (ignore 0,0)
    positions = [];
    i = 1;
    for pp = 1:size(ad.positions,1)
        pos = ad.positions(pp,1:2);
        if any(ismember(obs(:,1:2), pos, 'rows'))
            positions(i,1:2) = pos;
            i = i + 1;
        end
    end
    num_positions = size(positions,1);
    dim1 = floor(sqrt(num_positions));
    dim2 = ceil(num_positions / dim1);

    ha = tight_subplot(dim1, dim2, .004, .004, .004);
    
    max_value = -inf;
    min_value = inf;
    
    % nice way of displaying plots with an aligned-to-grid location using percentiles
    pos_sorted = flipud(sortrows(positions, 2));
    for i = 1:dim1 % chunk positions by display rows
        l = ((i-1) * dim2) + (1:dim2);
        l(l > num_positions) = [];
        pos_sorted(l,:) = sortrows(pos_sorted(l,:), 1);
    end
    legends = {};
    

    % set up coloring & legend by going through the options:
    opti = 1;
    colorsets = [];
    for vi = 1:length(voltages)
        for ai = 1:length(adaptstates)
            for inti = 1:length(intensities)
                colorsets(vi, ai, inti, 1:3) = colors(opti,:);
                legends{opti} = sprintf('v: %d inti: %0.1f ai: %d', voltages(vi), intensities(inti), adaptstates(ai));
                opti = opti + 1;
            end
        end
    end

    for poi = 1:num_positions

        pos = pos_sorted(poi,:);
        for vi = 1:length(voltages)
            for ai = 1:length(adaptstates)
                for inti = 1:length(intensities)

                    v = voltages(vi);
                    obs_sel = ismember(obs(:,1:2), pos, 'rows');
                    obs_sel = obs_sel & obs(:,3) == intensities(inti) & obs(:,4) == v & obs(:,14) == adaptstates(ai);
                    indices = find(obs_sel);

                    hold(ha(poi), 'on');

                    for ii = 1:length(indices)
                        entry = obs(indices(ii),:)';
                        epoch = ad.epochData{entry(9)};

                        signal = epoch.response(entry(10):entry(11)); % start and end indices into signal vector
%                         signal = signal - mean(signal(1:10));

                        if v < 0
                            signal = signal * 4; % make excitation signals more visible
                        end

                        signal = smooth(signal, 20);
                        t = (0:(length(signal)-1)) / ad.sampleRate;
                        h = plot(ha(poi), t, signal,'color',squeeze(colorsets(vi, ai, inti,1:3)));
                        if ii > 1
                            set(get(get(h,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
                        end
                        
%                         responseValue = entry(6); % 6 for peak
%                         line([min(t), max(t)], [responseValue, responseValue], 'Parent', ha(poi), 'Color',squeeze(colorsets(vi, ai, inti,1:3)));

                        max_value = max(max_value, max(signal));
                        min_value = min(min_value, min(signal));
                    end
                    
                end
            end
        end
        
%         set(gca,'XTickLabelMode','manual')
        set(ha(poi),'XTickLabels',[])
        
        startSampleTime = ad.sampleSet(1) / ad.sampleRate;
        endSampleTime = ad.sampleSet(end) / ad.sampleRate;
        y = [-10,100];
        startLine = line([1,1]*startSampleTime, y, 'Parent', ha(poi), 'color', 'k');
        endLine = line([1,1]*endSampleTime, y, 'Parent', ha(poi), 'color', 'k');
        set(get(get(startLine,'Annotation'),'LegendInformation'),'IconDisplayStyle','off')
        set(get(get(endLine,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        
        grid(ha(poi), 'on')
        zline = line([0,max(t)],[0,0], 'Parent', ha(poi), 'color', 'k');
        set(get(get(zline,'Annotation'),'LegendInformation'),'IconDisplayStyle','off'); % only display one legend per type

%         title(ha(poi), sprintf('%d,%d', round(pos)));
        
    end
    set(ha(1),'YTickLabelMode','auto');
    set(ha(1),'XTickLabelMode','auto');
    legend(ha(1),legends,'location','best')

    linkaxes(ha);
%     for i = 1:length(ha)
%         i
%         min_value
    ylim(ha(1), [min_value, max_value*1.3]);
    xlim(ha(1), [0, max(t)])
%     end

elseif strcmp(mode, 'wholeCell_comparisons')
    % compares by subtraction the spatial RF of On and Off, and Ex and In 

    combinationMode = 'median';
    mode_col = 5; % mean
    modeLabel = 'mean';
    excitatory_multiplier = 6;
    
    voltages = sort(unique(obs(:,4)));
    num_voltages = length(voltages);
        
    intensities = sort(unique(obs(:,3)));
    num_intensities = length(intensities);
    
    dataByVoltageIntensity = cell(num_voltages, num_intensities, 2);
    
    largestDistanceOffset = max(abs(ad.positions(:)));
    X = linspace(-1*largestDistanceOffset, largestDistanceOffset, 200);
    [xq,yq] = meshgrid(X, X);
    
    num_rows = num_intensities;
    if num_intensities > 1
        num_rows = num_rows + 1;
    end
    num_columns = num_voltages;
    if num_voltages > 1
        num_columns = num_columns + 1;
    end
    ha = tight_subplot(num_rows, num_columns);
    for vi = 1:num_voltages
        for ii = 1:num_intensities
            intensity = intensities(ii);
            voltage = voltages(vi);
            
%             vals = zeros(length(ad.positions),1);
            vals = [];
            posIndex = 0;
            goodPositions = [];
            for poi = 1:length(ad.positions)
                pos = ad.positions(poi,:);
                obs_sel = ismember(obs(:,1:2), pos, 'rows');
                obs_sel = obs_sel & obs(:,3) == intensity;
                obs_sel = obs_sel & obs(:,4) == voltage;
                if strcmp(combinationMode, 'mean')
                    val = nanmean(obs(obs_sel, mode_col),1);
                elseif strcmp(combinationMode, 'median')
                    val = nanmedian(obs(obs_sel, mode_col),1);
                elseif strcmp(combinationMode, 'min')
                    val = nanmin(obs(obs_sel, mode_col));                    
                elseif strcmp(combinationMode, 'first')
                    val = obs(obs_sel, mode_col);
                    try
                        val = val(1);
                    catch
                    end
                elseif strcmp(combinationMode, 'last')
                    val = obs(obs_sel, mode_col);
                    try
                        val = val(end);
                    catch
                    end
                end
                if any(obs_sel) && ~isnan(val)
                    posIndex = posIndex + 1;
                    vals(posIndex,1) = val;
                    goodPositions(posIndex,:) = pos;
                end
            end
            
            a = vi + (ii-1) * num_columns;
            
            axes(ha(a));
            vals = vals * sign(voltage + 1);
%             vals = vals ./ max(abs(vals));
            
            if posIndex >= 3
               
                c = griddata(goodPositions(:,1), goodPositions(:,2), vals, xq, yq);
                s = surface(xq, yq, zeros(size(xq)), c);
                                
                line([-50, 50],largestDistanceOffset*[-1,-1]*.9, 'LineWidth', 1.5, 'Color', 'k');
                colorbar
                grid off
                axis equal
                shading interp
                % set axis limits
                axis(largestDistanceOffset * [-1 1 -1 1])
                set(gca, 'Box', 'off')
                set(gca, 'XTick', [], 'XColor', 'none')
                set(gca, 'YTick', [], 'YColor', 'none')
                set(gcf,'color','w');
                title(sprintf('%d mV, %.1f', voltage, intensity))
%                 caxis([-1,1]);
                
                dataByVoltageIntensity{vi, ii} = c;
            end

            
        end
    end
    
    % comparisons:
    if num_intensities > 1
        for vi = 1:num_voltages
            a = vi + num_columns * (num_rows-1);
            axes(ha(a));
            d = dataByVoltageIntensity{vi, 2} - dataByVoltageIntensity{vi, 1};
                s = surface(xq, yq, zeros(size(xq)), d);
                                
                line([-50, 50],largestDistanceOffset*[-1,-1]*.9, 'LineWidth', 1.5, 'Color', 'k');
                colorbar
                grid off
                axis equal
                shading interp
                % set axis limits
                axis(largestDistanceOffset * [-1 1 -1 1])
                set(gca, 'Box', 'off')
                set(gca, 'XTick', [], 'XColor', 'none')
                set(gca, 'YTick', [], 'YColor', 'none')
                set(gcf,'color','w');
                title(sprintf('comparison %d mV', voltages(vi)))
%                 caxis([-.7,.7]);
                
        end
    end
    
    if num_voltages > 1
        for ii = 1:num_intensities
            a = (ii - 1) * num_columns + 1 + num_intensities;
            axes(ha(a));
            d = dataByVoltageIntensity{1, ii} * excitatory_multiplier - dataByVoltageIntensity{2, ii};
                s = surface(xq, yq, zeros(size(xq)), d);
                                
                line([-50, 50],largestDistanceOffset*[-1,-1]*.9, 'LineWidth', 1.5, 'Color', 'k');
                colorbar
                grid off
                axis equal
                shading interp
                % set axis limits
                axis(largestDistanceOffset * [-1 1 -1 1])
                set(gca, 'Box', 'off')
                set(gca, 'XTick', [], 'XColor', 'none')
                set(gca, 'YTick', [], 'YColor', 'none')
                set(gcf,'color','w');
                title(sprintf('comparison int %d', intensities(ii)))
%                 caxis([-.7,.7]);
        end
    end
    
    if num_voltages > 1 && num_intensities > 1
        a = num_columns * num_rows;
        axes(ha(a));
        d = - dataByVoltageIntensity{1, 1} * excitatory_multiplier + dataByVoltageIntensity{2, 1} ...
            + dataByVoltageIntensity{1, 2} * excitatory_multiplier - dataByVoltageIntensity{2, 2};

            s = surface(xq, yq, zeros(size(xq)), d);

            line([-50, 50],largestDistanceOffset*[-1,-1]*.9, 'LineWidth', 1.5, 'Color', 'k');
            colorbar
            grid off
            axis equal
            shading interp
            % set axis limits
            axis(largestDistanceOffset * [-1 1 -1 1])
            set(gca, 'Box', 'off')
            set(gca, 'XTick', [], 'XColor', 'none')
            set(gca, 'YTick', [], 'YColor', 'none')
            set(gcf,'color','w');
            title('comparison overall')
%             caxis([-.7,.7]);
    end
   

elseif strcmp(mode, 'wholeCell')
    % compares Ex and In RF using gaussian fits
    
    obs = ad.observations;
   
    intensities = unique(obs(:,3));
    voltages = unique(obs(:,4));
    mapByVoltageIntensity = {};
    ratios = {};
    
    ha = tight_subplot(length(intensities),3);

    for ii = 1:length(intensities)
        intensity = intensities(ii);
        v_in = max(obs(:,4));
        v_ex = min(obs(:,4));

        r_ex = [];
        r_in = [];

        posIndex = 0;
        goodPositions = [];
        for poi = 1:length(ad.positions)
            pos = ad.positions(poi,:);
            obs_sel = ismember(obs(:,1:2), pos, 'rows');
            obs_sel = obs_sel & obs(:,3) == intensity;
            obs_sel_ex = obs_sel & obs(:,4) == v_ex;
            obs_sel_in = obs_sel & obs(:,4) == v_in;

            if any(obs_sel_ex) && any(obs_sel_in)
                posIndex = posIndex + 1;
                r_ex(posIndex,1) = mean(obs(obs_sel_ex,5),1);
                r_in(posIndex,1) = mean(obs(obs_sel_in,5),1);
                goodPositions(posIndex,:) = pos;
            end
        end
        
        
%         v_reversal_ex = 0;
%         v_reversal_in = -60;
%         r_ex = -r_ex ./ abs(v_ex - v_reversal_ex);
%         r_in = r_in ./ abs(v_in - v_reversal_in);
%         r_exinrat = r_ex - r_in;
        
        r_ex = -r_ex;
        r_ex = r_ex./max(abs(r_ex));
        r_in = r_in./max(abs(r_in));
        r_exinrat = r_ex - r_in;
        r_exinrat = r_exinrat ./ max(abs(r_exinrat));
    %     r_exinrat = sign(r_exinrat) .* log10(abs(r_exinrat));

    %     max_ = max(vertcat(r_ex, r_in));
    %     min_ = min(vertcat(r_ex, r_in));
    
    
        mapByVoltageIntensity{1, ii} = r_ex;
        mapByVoltageIntensity{2, ii} = r_in;

        ratios{ii} = r_exinrat;
        max(r_ex)
        % EX
        axes(ha(1+(ii-1)*3))
        plotSpatial(goodPositions, r_ex, sprintf('Exc cond: %d mV, Int: %d', v_ex, intensity), 1, 0);
    %     caxis([min_, max_]);

        % IN
        axes(ha(2+(ii-1)*3))
        plotSpatial(goodPositions, r_in, sprintf('Inh cond: %d mV, Int: %d', v_in, intensity), 1, 0);
    %     caxis([min_, max_]);

        % Ratio    
        axes(ha(3+(ii-1)*3))
        plotSpatial(goodPositions, r_exinrat, 'Ex/In difference', 1, 0)
    end
    
    % intensity difference maps:
    axes(ha(2+(ii-1)*3))
    plotSpatial(goodPositions, r_in, sprintf('Inh cond: %d mV, Int: %d', v_in, intensity), 1, 0);    
    
    
    % combining differences at each intensity
    figure(212);clf;
    rr = ratios{2} - ratios{1};
    plotSpatial(goodPositions, rr, '', 1, 0);
    title('On diff - Off diff');

elseif strcmp(mode, 'spatialOffset_onOff')
    obs = ad.observations;
   
    voltage = max(obs(:,4));
    i_high = max(obs(:,3));
    i_low = min(obs(:,3));
    
    if i_high == i_low
        disp('Only one intensity in data set');
        return
    end
    
    r_high = [];
    r_low = [];

    posIndex = 0;
    goodPositions_high = [];
    for poi = 1:length(ad.positions)
        pos = ad.positions(poi,:);
        obs_sel = ismember(obs(:,1:2), pos, 'rows');
        obs_sel = obs_sel & obs(:,4) == voltage;
        obs_sel_high = obs_sel & obs(:,3) == i_high;
        if any(obs_sel_high)
            posIndex = posIndex + 1;
%             r_high(posIndex,1) = min(obs(obs_sel_high,5));
            r_high(posIndex,1) = mean(obs(obs_sel_high,5),1);
            goodPositions_high(posIndex,:) = pos;
        end
    end
    
    posIndex = 0;
    goodPositions_low = [];
    for poi = 1:length(ad.positions)
        pos = ad.positions(poi,:);
        obs_sel = ismember(obs(:,1:2), pos, 'rows');
        obs_sel = obs_sel & obs(:,4) == voltage;
        obs_sel_low = obs_sel & obs(:,3) == i_low;
        if any(obs_sel_low)
            posIndex = posIndex + 1;
%             r_low(posIndex,1) = min(obs(obs_sel_low,5));
            r_low(posIndex,1) = mean(obs(obs_sel_low,5),1);
            goodPositions_low(posIndex,:) = pos;
        end
    end

    ha = tight_subplot(1,3, -.0);

    % EX
    axes(ha(1))
    g_high = plotSpatial(goodPositions_high, r_high, '', 1, 1); % sprintf('Exc. current (pA)')
%     caxis([min_, max_]);
    
    % IN
    axes(ha(2))
    g_low = plotSpatial(goodPositions_low, r_low, '', 1, 1); % sprintf('Inh. current (pA)')
%     caxis([min_, max_]);
        
    offsetDist = sqrt((g_low('centerX') - g_high('centerX')).^2) + sqrt((g_low('centerY') - g_high('centerY')).^2);
    avgSigma2 = mean([g_low('sigma2X'), g_low('sigma2Y'), g_high('sigma2X'), g_high('sigma2Y')]);
    
    firstEpoch = ad.epochData{1};
    fprintf('Spatial offset = %3.1f um, avg sigma2 = %3.1f, ratio = %2.2f, sessionId %s\n', offsetDist, avgSigma2, offsetDist/avgSigma2, firstEpoch.sessionId);

    axes(ha(3))
    hold on
    color_high = [.9 .7 0];
    e = ellipse(g_high('sigma2X'), g_high('sigma2Y'), -g_high('angle'), g_high('centerX'), g_high('centerY'), color_high);
    set(e, 'LineWidth', 1.5);
    line(g_high('centerX') + [-l, l]/2, g_high('centerY') * [1,1], 'LineWidth', 1.5, 'Color', color_high);
    line(g_high('centerX') * [1,1], g_high('centerY') + [-l, l]/2, 'LineWidth', 1.5, 'Color', color_high);
    
    color_low = 'k';
    e = ellipse(g_low('sigma2X'), g_low('sigma2Y'), -g_low('angle'), g_low('centerX'), g_low('centerY'), color_low);
    set(e, 'LineWidth', 1.5);
    line(g_low('centerX') + [-l, l]/2, g_low('centerY') * [1,1], 'LineWidth', 1.5, 'Color', color_low);
    line(g_low('centerX') * [1,1], g_low('centerY') + [-l, l]/2, 'LineWidth', 1.5, 'Color', color_low);
    
    
    line([-100, 0],[-130, -130], 'Color','k', 'LineWidth', 2) % 100 µm scale bar
%     legend('Exc','Inh')

    hold off
    axis equal
    largestDistanceOffset = max(abs(ad.positions(:)));
    axis(largestDistanceOffset * [-1 1 -1 1])
%     set(gca, 'XTickMode', 'auto', 'XTickLabelMode', 'auto')
%     set(gca, 'YTickMode', 'auto', 'YTickLabelMode', 'auto')
    set(gca, 'XTick', [], 'XColor', 'none')
    set(gca, 'YTick', [], 'YColor', 'none')    
%     title('Gaussian 2\sigma Fits Overlaid')
    colorbar
    linkaxes(ha)
    
    disp(g_high.keys)
    disp(cell2mat(g_high.values))
    disp(cell2mat(g_low.values))
    
elseif strcmp(mode, 'spatialOffset')
    
    obs = ad.observations;
   
    maxIntensity = max(obs(:,3));
    v_in = max(obs(:,4));
    v_ex = min(obs(:,4));
    
    if v_in == v_ex
        disp('Only one voltage in data set');
        return
    end
    
    r_ex = [];
    r_in = [];

    posIndex = 0;
    goodPositions_ex = [];
    for poi = 1:length(ad.positions)
        pos = ad.positions(poi,:);
        obs_sel = ismember(obs(:,1:2), pos, 'rows');
        obs_sel = obs_sel & obs(:,3) == maxIntensity;
        obs_sel_ex = obs_sel & obs(:,4) == v_ex;
        if any(obs_sel_ex)
            posIndex = posIndex + 1;
            r_ex(posIndex,1) = mean(obs(obs_sel_ex,5),1);
            goodPositions_ex(posIndex,:) = pos;
        end
    end
    
    posIndex = 0;
    goodPositions_in = [];
    for poi = 1:length(ad.positions)
        pos = ad.positions(poi,:);
        obs_sel = ismember(obs(:,1:2), pos, 'rows');
        obs_sel = obs_sel & obs(:,3) == maxIntensity;
        obs_sel_in = obs_sel & obs(:,4) == v_in;
        if any(obs_sel_in)
            posIndex = posIndex + 1;
            r_in(posIndex,1) = mean(obs(obs_sel_in,5),1);
            goodPositions_in(posIndex,:) = pos;
        end
    end

    ha = tight_subplot(1,3, .03);

    % EX
    axes(ha(1))
    g_ex = plotSpatial(goodPositions_ex, -r_ex, '', 1, 1); % sprintf('Exc. current (pA)')
%     caxis([min_, max_]);
    
    % IN
    axes(ha(2))
    g_in = plotSpatial(goodPositions_in, r_in, '', 1, 1); % sprintf('Inh. current (pA)')
%     caxis([min_, max_]);
        
    offsetDist = sqrt((g_in('centerX') - g_ex('centerX')).^2) + sqrt((g_in('centerY') - g_ex('centerY')).^2);
    avgSigma2 = mean([g_in('sigma2X'), g_in('sigma2Y'), g_ex('sigma2X'), g_ex('sigma2Y')]);
    
    firstEpoch = ad.epochData{1};
    fprintf('Spatial offset = %3.1f um, avg sigma2 = %3.1f, ratio = %2.2f, sessionId %d\n', offsetDist, avgSigma2, offsetDist/avgSigma2, firstEpoch.sessionId);
    
    axes(ha(3))
    hold on
    e = ellipse(g_ex('sigma2X'), g_ex('sigma2Y'), -g_ex('angle'), g_ex('centerX'), g_ex('centerY'), 'blue');
    set(e, 'LineWidth', 1.5);
    line(g_ex('centerX') + [-l, l]/2, g_ex('centerY') * [1,1], 'LineWidth', 1.5, 'Color', 'blue');
    line(g_ex('centerX') * [1,1], g_ex('centerY') + [-l, l]/2, 'LineWidth', 1.5, 'Color', 'blue');
    
    e = ellipse(g_in('sigma2X'), g_in('sigma2Y'), -g_in('angle'), g_in('centerX'), g_in('centerY'), 'red');
    set(e, 'LineWidth', 1.5);
    line(g_in('centerX') + [-l, l]/2, g_in('centerY') * [1,1], 'LineWidth', 1.5, 'Color', 'red');
    line(g_in('centerX') * [1,1], g_in('centerY') + [-l, l]/2, 'LineWidth', 1.5, 'Color', 'red');
    
    
    line([-100, 0],[-150, -150], 'Color','k', 'LineWidth', 2)
%     legend('Exc','Inh')

    hold off
    axis equal
    largestDistanceOffset = max(abs(ad.positions(:)));
    axis(largestDistanceOffset * [-1 1 -1 1])
%     set(gca, 'XTickMode', 'auto', 'XTickLabelMode', 'auto')
%     set(gca, 'YTickMode', 'auto', 'YTickLabelMode', 'auto')
    set(gca, 'XTick', [], 'XColor', 'none')
    set(gca, 'YTick', [], 'YColor', 'none')    
%     title('Gaussian 2\sigma Fits Overlaid')
    colorbar
    linkaxes(ha)
    
    disp(g_ex.keys)
    disp(cell2mat(g_ex.values))
    disp(cell2mat(g_in.values))
    
elseif strcmp(mode, 'spatialDiagnostics')
    obs = ad.observations;
    if isempty(obs)
        return
    end
    voltages = unique(obs(:,4));
    num_voltages = length(voltages);
        
    % variance by point value at max value
    maxIntensity = max(obs(:,3));
    
    ha = tight_subplot(1, num_voltages);
    for vi = 1:num_voltages
        voltage = voltages(vi);
        vals = [];
        for poi = 1:length(ad.positions)
            pos = ad.positions(poi,:);
            obs_sel = ismember(obs(:,1:2), pos, 'rows');
            obs_sel = obs_sel & obs(:,3) == maxIntensity;
            obs_sel = obs_sel & obs(:,4) == voltage;
            vals(poi,1) = std(obs(obs_sel,5),1) / mean(obs(obs_sel,5),1);
        end    
        axes(ha(vi));
        plotSpatial(ad.positions, vals, sprintf('STD/mean at V = %d mV', voltage), 1, 0)
%         caxis([0, max(vals)]);
    end
    
    
%     diagTxt = uicontrol('style','text');
%     diagTxt.HorizontalAlignment = 'left';
%     diagTxt.Units = 'characters';
%     diagTxt.Position = [0, 0, 30, 10];
%     align([diagTxt, h],'Distribute','Top')
%     
%     diagTxt.String = 'Hello World';
    
elseif strcmp(mode, 'positionDifferenceAnalysis')
    obs = ad.observations;
    if isempty(obs)
        return
    end
    
    % general distance to value
    subplot(2,1,1)
    plot(obs(:,8), obs(:,5), 'o')
    hold on
    sel = ~isnan(obs(:,8)) & ~isnan(obs(:,5));
    p = polyfit(obs(sel,8), obs(sel,5), 1);
    plot(obs(:,8), polyval(p, obs(:,8)))
    hold off
    
    % compare repeat values with different distances
    subplot(2,1,2)
    
    
elseif strcmp(mode, 'adaptationRegion')
    % analyzes and displays experiment with flicker and flashed spots map, to find the spatial properties of adaptation
    obs = ad.observations;
    
%     % get list of adaptation points
%     adaptationPositions = unique(obs(:,[12,13]), 'rows');
%     if ~any(~isnan(adaptationPositions(:)))
%         disp('No adaptation data found');
%         return
%     end
%     num_adapt = size(adaptationPositions, 1);
%     maxIntensity = max(obs(:,3));
%     
%     for ai = 1:num_adapt
%         thisAdaptPos = adaptationPositions(ai,:);
%         probesThisAdapt = obs(:,12) == thisAdaptPos(1) & obs(:,13) == thisAdaptPos(2);
%         probeDataThisAdapt = obs(probesThisAdapt, :);
%         % make a figure
%         figure(110 + ai)
%         spatialPositions = [];
%         spatialValues = [];
%         spatialIndex = 0;
%         intensity = maxIntensity;
%         
%         % make a subplot for each probe
%         probePositions = unique(probeDataThisAdapt(:,[1,2]), 'rows');
%         numProbes = size(probePositions, 1);
% %         dim1 = floor(sqrt(numProbes));
% %         dim2 = ceil(numProbes / dim1);
%         clf;
% %         ha = tight_subplot(dim1,dim2);
%         for pri = 1:numProbes
% %             axes(ha(pri));
%             
% %             hold on;
%             
%             pos = probePositions(pri,:);
%             spatialIndex = spatialIndex + 1;
%             spatialPositions(spatialIndex, :) = pos;
%             for adaptOn = 0:1
%                 
%                 obs_sel = ismember(probeDataThisAdapt(:,1:2), pos, 'rows');
%                 obs_sel = obs_sel & probeDataThisAdapt(:,14) == adaptOn & probeDataThisAdapt(:,3) == intensity;
%                 
% %                 ints = probeDataThisAdapt(obs_sel, 3);
%                 vals = probeDataThisAdapt(obs_sel, 5);
% %                 plot(ints, vals, '-o');
%                 spatialValues(spatialIndex, adaptOn + 1) = mean(vals);
%             end
%             
%             
% %             legend('off','on')
%         end
%         
%         ha = tight_subplot(1,3);
%         maxv = max(spatialValues(:));
%         minv = min(spatialValues(:));
%         spatialValues(:,3) = diff(spatialValues, 1, 2);
%         for a = 1:3
%             axes(ha(a))
%             plotSpatial(spatialPositions, spatialValues(:,a), '', 1, 0)
%             caxis([minv, maxv]);
%         end
%         title(ha(1), 'before adaptation');
%         title(ha(2), 'during adaptation');
%         title(ha(3), 'difference');
%     end
    
    %% do plot of response/intensity by position
%     figure(90);
    clf;
    obs = ad.observations;
    voltage = max(unique(obs(:,4)));
    intensities = sort(unique(obs(:,3)));
       
    % only use positions with observations (ignore 0,0)
    positions = [];
    i = 1;
    for pp = 1:size(ad.positions,1)
        pos = ad.positions(pp,1:2);
        if any(ismember(obs(:,1:2), pos, 'rows'))
            positions(i,1:2) = pos;
            i = i + 1;
        end
    end
    num_positions = size(positions,1);
    dim1 = floor(sqrt(num_positions));
    dim2 = ceil(num_positions / dim1);
    max_value = -inf;
    min_value = inf;

    ha = tight_subplot(dim1, dim2, .05, .05, .05);
    
    % nice way of displaying plots with an aligned-to-grid location using percentiles
    pos_sorted = flipud(sortrows(positions, 2));
    for i = 1:dim1 % chunk positions by display rows
        l = ((i-1) * dim2) + (1:dim2);
        l(l > num_positions) = [];
        pos_sorted(l,:) = sortrows(pos_sorted(l,:), 1);
    end
    
    for poi = 1:num_positions
        
        pos = pos_sorted(poi,:);
        axes(ha(poi))
        hold on
        for adaptstate = 0:1
            responses = [];
            for inti = 1:length(intensities)
                obs_sel = ismember(obs(:,1:2), pos, 'rows');
                obs_sel = obs_sel & obs(:,3) == intensities(inti) & obs(:,4) == voltage & obs(:,14) == adaptstate;
                
                responses(inti) = mean(obs(obs_sel,5));
                adaptPos = mean(obs(obs_sel, [12,13]));
            end
            plot(intensities, responses, 'o-')
            max_value = max(max_value, max(responses));
            min_value = min(min_value, min(responses));
            
        end
        distFromAdapt = sqrt(sum((pos - adaptPos).^2));
        title(sprintf('dist: %d um', round(distFromAdapt)));
        hold off
        set(gca, 'XTickMode', 'auto', 'XTickLabelMode', 'auto')
        set(gca, 'YTickMode', 'auto', 'YTickLabelMode', 'auto')
        if poi == 1
            legend({'before','after'},'location','best')
        end
    end
    for poi = 1:num_positions
        ylim(ha(poi), [min_value, max_value])
    end


else
    disp(mode)
    disp('incorrect plot type')
end

    function gfit = plotSpatial(positions, values, titl, addColorBar, gaussianfit, thresholdParams)
        
        if nargin < 6
            enableThresholding = false;
        else
            enableThresholding = true;
        end
        
%         positions = bsxfun(@plus, positions, positionOffset);
        largestDistanceOffset = max(abs(positions(:)));
        X = linspace(-1*largestDistanceOffset, largestDistanceOffset, 200);
        [xq,yq] = meshgrid(X, X);
        c = griddata(positions(:,1), positions(:,2), values, xq, yq);
        
        if enableThresholding
            threshold = thresholdParams{1};
            direction = thresholdParams{2};
            
            if direction > 0
                sel = c > threshold;
            else
                sel = c < threshold;
            end
%             xq(~sel) = [];
%             yq(~sel) = [];
            c(~sel) = nan;
        end
        
        s = surface(xq, yq, zeros(size(xq)), c);
%         hold on
% %         plot(positions(:,1), positions(:,2), '.r');
%         hold off
        title(titl)
        grid off
    %     axis square
        axis equal
        shading interp
        
        if addColorBar == 1
            colorbar
            
        elseif length(addColorBar) > 1
            colormap(gca(), addColorBar);
%             colorbar
            alpha(s, .2)
        end
        
        if gaussianfit ~= 0
            if gaussianfit < 0
                fitValues = values * -1; % seems to be the only place we need positive deflections is for fitting
            else
                fitValues = values;
            end
            hold on
            
%             values = zeros(size(values));
%             hi = 20;%round(length(values) / 2);
%             positions(hi,:)
%             values(hi) = 1;
            fitValues(fitValues < 0) = 0; % Interesting, maybe an improvement for fitting WC results
            gfit = fit2DGaussian(positions, fitValues);
            fprintf('gaussian fit center: %d um, %d um\n', round(gfit('centerX')), round(gfit('centerY')))
            v = fitValues - min(fitValues);
%             centerOfMass = mean(bsxfun(@times, positions, v ./ mean(v)), 1);
%             plot(centerOfMass(1), centerOfMass(2),'green','MarkerSize',20, 'Marker','+')
%             plot(gfit('centerX'), gfit('centerY'),'black','MarkerSize', 10, 'Marker','+')
            l = 20;
            line(gfit('centerX') + [-l, l]/2, gfit('centerY') * [1,1], 'LineWidth', 1.5, 'Color', 'k');
            line(gfit('centerX') * [1,1], gfit('centerY') + [-l, l]/2, 'LineWidth', 1.5, 'Color', 'k');

            e = ellipse(gfit('sigma2X'), gfit('sigma2Y'), -gfit('angle'), gfit('centerX'), gfit('centerY'));
            set(e, 'Color', 'black')
            e.LineWidth = 1.5;
            hold off
        else
            gfit = nan;
        end
        
        % draw soma
%         rectangle('Position',0.05 * largestDistanceOffset * [-.5, -.5, 1, 1],'Curvature',1,'FaceColor',[1 1 1]);

        line([-50, 50],largestDistanceOffset*[-1,-1], 'LineWidth', 1.5, 'Color', 'k');
        
        % set axis limits
        axis(largestDistanceOffset * [-1 1 -1 1])
        
%         set(gca, 'XTickMode', 'auto', 'XTickLabelMode', 'auto')
%         set(gca, 'YTickMode', 'auto', 'YTickLabelMode', 'auto')
        
%         % plot with no axis labels
        set(gca, 'Box', 'off')
        set(gca, 'XTick', [], 'XColor', 'none')
        set(gca, 'YTick', [], 'YColor', 'none')
        
        set(gcf,'color','w');

    end

end