function [] = plotShapeData(ad, mode)

if ~isfield(ad,'observations')
    disp('no observations');
    return 
end
obs = ad.observations;
if isempty(obs)
    disp('empty observations')
    return
end


if strcmp(mode, 'printParameters')
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
% elseif strcmp(mode, 'plotSpatial_tHalfMax')

    if strfind(mode, 'mean')
        mode_col = 5;
        smode = 'mean';
    elseif strfind(mode, 'peak')
        mode_col = 6;
        smode = 'peak';
    elseif strfind(mode, 'tHalfMax')
        mode_col = 7;
        smode = 't half max';
    elseif strfind(mode, 'saveMaps')
        mode_col = 5;
        smode = 'saveMaps';        
    end
   
    
    voltages = sort(unique(obs(:,4)));
    num_voltages = length(voltages);
        
    intensities = sort(unique(obs(:,3)));
    num_intensities = length(intensities);
    
    data = cell(num_voltages, num_intensities, 2);
    
    ha = tight_subplot(num_intensities, num_voltages);
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
                val = nanmean(obs(obs_sel, mode_col),1);
                if any(obs_sel) && ~isnan(val)
                    posIndex = posIndex + 1;
                    vals(posIndex,1) = val;
                    goodPositions(posIndex,:) = pos;
                end
            end
            
            a = vi + (ii-1) * num_voltages;
            
            axes(ha(a));

            if posIndex >= 3
                plotSpatial(goodPositions, vals, sprintf('%s at V = %d mV, intensity = %f', smode, voltage, intensity), 1, sign(voltage));
    %             caxis([0, max(vals)]);
    %             colormap(flipud(colormap))
            end
            
            data(vi, ii, 1:2) = {goodPositions, vals};
        end
    end
    
    if strcmp(smode, 'saveMaps')
        save('savedMaps.mat', 'data','voltages','intensities');
        disp('saved maps to savedMaps.mat');
    end
    
    
elseif strcmp(mode, 'subunit')

%     if ad.numValues > 1
    
        %% Plot figure with subunit models
    %     figure(12);


%         distance_to_center = zeros(num_positions, 1);
%         for p = 1:num_positions
%             gfp = ad.gaussianFitParams_ooi{3};
%             distance_to_center(p,1) = sqrt(sum((ad.positions(p,:) - [gfp('centerX'),gfp('centerY')]).^2));
%         end
%         sorted_positions = sortrows([distance_to_center, (1:num_positions)'], 1);


        num_positions = size(ad.positions,1);
        dim1 = floor(sqrt(num_positions));
        dim2 = ceil(num_positions / dim1);
        
        ha = tight_subplot(dim1,dim2);
        
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
            
            pos = ad.positions(p,:);
            obs_sel = ismember(obs(:,1:2), pos, 'rows');
            
            for vi = 1:num_voltages
                voltage = voltages(vi);
                obs_sel_v = obs_sel & obs(:,4) == voltage;
            
                responses = obs(obs_sel_v, 5); % peak: 6, mean: 5
                intensities = obs(obs_sel_v, 3);

                plot(intensities, responses, 'o')
                if length(unique(intensities)) > 1
                    pfit = polyfit(intensities, responses, 1);
                    plot(intensities, polyval(pfit,intensities))
                    
                    
                    goodPosIndex = goodPosIndex + 1;
                    goodPositions(goodPosIndex, :) = pos;
                    goodSlopes(goodPosIndex, 1) = pfit(1);
                end
%                 title(pfit)
    %             ylim([0,max(rate)+.1])
            end
            grid on
            hold off
            
            set(gca, 'XTickMode', 'auto', 'XTickLabelMode', 'auto')
            set(gca, 'YTickMode', 'auto', 'YTickLabelMode', 'auto')

        end
        
        if ~isempty(goodPositions)
            figure(99)
            plotSpatial(goodPositions, goodSlopes, 'intensity response slope', 1, 0)
        end
        
%         set(ha(1:end-dim2),'XTickLabel','');
%         set(ha,'YTickLabel','')
%     else
%         disp('No multiple value subunits measured');
%     end
    
elseif strcmp(mode, 'temporalResponses')
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
    
    
%     old alignment display is deprecated for now. Use temporal responses
% elseif strcmp(mode, 'temporalAlignment')
%     
%     ha = tight_subplot(2, 1, .1);
%     
%     ei = ad.alignmentEpochIndex;
%     axes(ha(1));
%     if ~isnan(ei)
%         t = ad.epochData{ei}.t;
%         hold on
%         plot(t, -1 * ad.alignmentRate ./ max(abs(ad.alignmentRate)),'r');
%         plot(t, ad.alignmentLightOn,'b')
%         plot(t + ad.timeOffset(1), ad.alignmentLightOn * .8,'g')
%         legend('rate','light','shifted')
%         title(ad.timeOffset(1))
%         hold off
%     end
%     
%     % new format
% %     obs = ad.observations;
% %     voltages = sort(unique(obs(:,4)));
% %     for vi = 1:length(voltages)
% %         obs_sel = obs(:,4) == voltages(vi);
% %         indices = find(obs_sel);
% % 
% %         for ii = 1:length(indices)
% %             entry = obs(indices(ii),:)';
% %             epoch = ad.epochData{entry(9)};
% % 
% %             signal = epoch.response(entry(10):entry(11));    
% %         end
% %         plot(mean(signal));
% %     end
% 
%     
%     %% plot time graph
%     axes(ha(2));
%     spotOnTime = ad.spotOnTime;
%     spotTotalTime = ad.spotTotalTime;
% 
%     %                 spikeBins = nodeData.spikeBins.value;
%     
%     
%     % get average of all responses
%     obs = ad.observations;
%     if isempty(obs)
%         return;
%     end
%     sm = [];
%     for oi = 1:size(obs, 1)
%         
%         entry = obs(oi,:)';
%         epoch = ad.epochData{entry(9)};
% 
%         sm(oi,:) = epoch.response(entry(10):entry(11));
%     end
%     spotBinDisplay = mean(sm,1);
%     
% %     spotBinDisplay = mean(ad.spikeRate_by_spot, 1);
%     timeOffset = ad.timeOffset;
%     
%     displayTime = (1:length(spotBinDisplay)) ./ ad.sampleRate + timeOffset(1);
%     
%     plot(displayTime, spotBinDisplay)
%     %                 plot(spikeBins(1:end-1), spikeBinsValues);
%     %                 xlim([0,spikeBins(end-1)])
% 
%     title('Temporal offset calculation')
% 
%     top = max(spotBinDisplay)*1.1;
% 
%     % two light spot patches
%     p = patch([0 spotOnTime spotOnTime 0],[0 0 top top],'y');
%     set(p,'FaceAlpha',0.3);
%     set(p,'EdgeColor','none');
%     p = patch(spotTotalTime+[0 spotOnTime spotOnTime 0],[0 0 top top],'y');
%     set(p,'FaceAlpha',0.3);
%     set(p,'EdgeColor','none');
% 
%     % analysis spot patch
%     p = patch(ad.timeOffset(1)+[0 spotOnTime spotOnTime 0],[0 0 -.1*top -.1*top],'g');
%     set(p,'FaceAlpha',0.3);
%     set(p,'EdgeColor','none');
%     p = patch(ad.timeOffset(1)+[spotOnTime spotTotalTime spotTotalTime spotOnTime],[0 0 -.1*top -.1*top],'r');
%     set(p,'FaceAlpha',0.3);
%     set(p,'EdgeColor','none');    
% 
%     title(['temporal offset of collection bins (on, off): ' num2str(timeOffset) ' sec'])

elseif strcmp(mode, 'temporalComponents')
    
    warning('off', 'stats:regress:RankDefDesignMat')
    
    % start with finding the times with highest variance, by voltage
    obs = ad.observations;
    voltages = sort(unique(obs(:,4)));

    ha = tight_subplot(length(voltages), 1, .03, .03);
    
    num_positions = size(ad.positions,1);
    signalsByVoltageByPosition = {};
    peakIndicesByVoltage = {};
    basisByVoltageComp = {};
    maxComponents = 0;

    for vi = 1:length(voltages)
        v = voltages(vi);

        signalsByPosition = cell(num_positions,1);
        for poi = 1:num_positions
            pos = ad.positions(poi,:);

            obs_sel = ismember(obs(:,1:2), pos, 'rows');
            obs_sel = obs_sel & obs(:,4) == v;
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

    for vi = 1:length(voltages)
        
        %% now, with the peak locations in hand, we can pull out the components
        peakIndices = peakIndicesByVoltage{vi,1};
        num_components = length(peakIndices);
        valuesByComponent = nan * zeros(num_positions, num_components);
        signalsByPosition = signalsByVoltageByPosition{vi,1};
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
            plotSpatial(ad.positions, valuesByComponent(:,ci), sprintf('v %d component %d', v, ci), 1, 0);
        end
        
    end
    
    
elseif strcmp(mode, 'responsesByPosition')
    
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
                        signal = smooth(signal, 20);
                        t = (0:(length(signal)-1)) / ad.sampleRate;
                        h = plot(ha(poi), t, signal,'color',squeeze(colorsets(vi, ai, inti,1:3)));
                        if ii > 1
                            set(get(get(h,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
                        end

                        max_value = max(max_value, max(signal));
                        min_value = min(min_value, min(signal));
                    end
                    
                end
            end
        end
        
%         set(gca,'XTickLabelMode','manual')
        set(ha(poi),'XTickLabels',[])
        
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
    ylim(ha(1), [min_value, max_value]);
    xlim(ha(1), [0, max(t)])
%     end
    
elseif strcmp(mode, 'wholeCell')
    obs = ad.observations;
   
    maxIntensity = max(obs(:,3));
    v_in = max(obs(:,4));
    v_ex = min(obs(:,4));
    
    r_ex = [];
    r_in = [];

    posIndex = 0;
    goodPositions = [];
    for poi = 1:length(ad.positions)
        pos = ad.positions(poi,:);
        obs_sel = ismember(obs(:,1:2), pos, 'rows');
        obs_sel = obs_sel & obs(:,3) == maxIntensity;
        obs_sel_ex = obs_sel & obs(:,4) == v_ex;
        obs_sel_in = obs_sel & obs(:,4) == v_in;
        
        if any(obs_sel_ex) && any(obs_sel_in)
            posIndex = posIndex + 1;
            r_ex(posIndex,1) = mean(obs(obs_sel_ex,5),1);
            r_in(posIndex,1) = mean(obs(obs_sel_in,5),1);
            goodPositions(posIndex,:) = pos;
        end
    end
    v_reversal_ex = 0;
    v_reversal_in = -60;
    r_ex = r_ex ./ abs(v_ex - v_reversal_ex);
    r_in = r_in ./ abs(v_in - v_reversal_in);
    r_exinrat = r_ex - r_in;
%     r_exinrat = sign(r_exinrat) .* log10(abs(r_exinrat));
    
%     max_ = max(vertcat(r_ex, r_in));
%     min_ = min(vertcat(r_ex, r_in));


    ha = tight_subplot(1,3);

    % EX
    axes(ha(1))
    plotSpatial(goodPositions, r_ex, sprintf('Excitatory conductance: %d mV', v_ex), 1, 0);
%     caxis([min_, max_]);
    
    % IN
    axes(ha(2))
    plotSpatial(goodPositions, r_in, sprintf('Inhibitory conductance: %d mV', v_in), 1, 0);
%     caxis([min_, max_]);
    
    % Ratio    
    axes(ha(3))
    plotSpatial(goodPositions, r_exinrat, 'Ex/In difference', 1, 0)
    
elseif strcmp(mode, 'spatialOffset')
    
    obs = ad.observations;
   
    maxIntensity = max(obs(:,3));
    v_in = max(obs(:,4));
    v_ex = min(obs(:,4));
    
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
    g_ex = plotSpatial(goodPositions_ex, -r_ex, sprintf('Exc. current (pA)'), 1, 1);
%     caxis([min_, max_]);
    
    % IN
    axes(ha(2))
    g_in = plotSpatial(goodPositions_in, r_in, sprintf('Inh. current (pA)'), 1, 1);
%     caxis([min_, max_]);
        
    offsetDist = sqrt((g_in('centerX') - g_ex('centerX')).^2) + sqrt((g_in('centerY') - g_ex('centerY')).^2);
    avgSigma2 = mean([g_in('sigma2X'), g_in('sigma2Y'), g_ex('sigma2X'), g_ex('sigma2Y')]);
    
    firstEpoch = ad.epochData{1};
    fprintf('Spatial offset = %3.1f um, avg sigma2 = %3.1f, ratio = %2.2f, sessionId %d\n', offsetDist, avgSigma2, offsetDist/avgSigma2, firstEpoch.sessionId);
    
    axes(ha(3))
    hold on
    ellipse(g_ex('sigma2X'), g_ex('sigma2Y'), -g_ex('angle'), g_ex('centerX'), g_ex('centerY'), 'magenta');
    
    ellipse(g_in('sigma2X'), g_in('sigma2Y'), -g_in('angle'), g_in('centerX'), g_in('centerY'), 'cyan');
    
    legend('Exc','Inh')
    
    plot(g_ex('centerX'), g_ex('centerY'),'red','MarkerSize',20, 'Marker','+')
    plot(g_in('centerX'), g_in('centerY'),'blue','MarkerSize',20, 'Marker','+')
    
    hold off
    axis equal
    largestDistanceOffset = max(abs(ad.positions(:)));
    axis(largestDistanceOffset * [-1 1 -1 1])
%     set(gca, 'XTickMode', 'auto', 'XTickLabelMode', 'auto')
%     set(gca, 'YTickMode', 'auto', 'YTickLabelMode', 'auto')
        set(gca, 'XTick', [], 'XColor', 'none')
        set(gca, 'YTick', [], 'YColor', 'none')    
    title('Gaussian 2\sigma Fits Overlaid')
    colorbar
    linkaxes(ha)
    
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

    function gfit = plotSpatial(positions, values, titl, addcolorbar, gaussianfit)
%         positions = bsxfun(@plus, positions, positionOffset);
        largestDistanceOffset = max(abs(positions(:)));
        X = linspace(-1*largestDistanceOffset, largestDistanceOffset, 100);
        [xq,yq] = meshgrid(X, X);        
        c = griddata(positions(:,1), positions(:,2), values, xq, yq);
        surface(xq, yq, zeros(size(xq)), c)
        hold on
%         plot(positions(:,1), positions(:,2), '.r');
        hold off
        title(titl)
        grid off
    %     axis square
        axis equal
        shading interp
        if addcolorbar
            colorbar
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
            gfit = fit2DGaussian(positions, fitValues);
            fprintf('gaussian fit center: %d um, %d um\n', round(gfit('centerX')), round(gfit('centerY')))
            v = fitValues - min(fitValues);
%             centerOfMass = mean(bsxfun(@times, positions, v ./ mean(v)), 1);
%             plot(centerOfMass(1), centerOfMass(2),'green','MarkerSize',20, 'Marker','+')
            plot(gfit('centerX'), gfit('centerY'),'red','MarkerSize',20, 'Marker','+')
            ellipse(gfit('sigma2X'), gfit('sigma2Y'), -gfit('angle'), gfit('centerX'), gfit('centerY'), 'red');
            hold off
        else
            gfit = nan;
        end
        
        % draw soma
%         rectangle('Position',0.05 * largestDistanceOffset * [-.5, -.5, 1, 1],'Curvature',1,'FaceColor',[1 1 1]);
        
        % set axis limits
        axis(largestDistanceOffset * [-1 1 -1 1])
        
%         set(gca, 'XTickMode', 'auto', 'XTickLabelMode', 'auto')
%         set(gca, 'YTickMode', 'auto', 'YTickLabelMode', 'auto')
        
        % plot with no axis labels
        set(gca, 'XTick', [], 'XColor', 'none')
        set(gca, 'YTick', [], 'YColor', 'none')
    end

end