classdef ShapeData < handle
    
    properties
        sessionId
        presentationId
        
        epochMode
        ampMode
        ampVoltage
        sampleRate
        preTime
        stimTime
        positionOffset
        timeOffset % set in curator
        rigOffsetAngle % set by script
        
        spikes
        spikeRate
        t
        response
        signalNormalizationParameters
        signalLightOn
        signalLightOff
        channel % like 'Amplifier_Ch1'

        spotTotalTime
        spotOnTime
%         numSpots
        totalNumSpots % including values and repeats
        spotDiameter
        searchDiameter
        numValues
        numValueRepeats
        
        shapeDataMatrix
        shapeDataColumns
    end
    
    methods
        function obj = ShapeData(epoch, runmode, channel)
            
            if nargin < 3
                obj.channel = 'Amplifier_Ch1';
            else
                obj.channel = channel;
            end
            
            fprintf('Starting ShapeData with channel %s\n', obj.channel)
            
            obj.sampleRate = 1000; %desired rate
            obj.preTime = .250; % fixed always anyway
            
            % standard parameters in epoch
            if strcmp(runmode, 'offline')
                obj.sessionId = epoch.get('sessionId');
                obj.presentationId = epoch.get('presentationId');
                sdc = epoch.get('shapeDataColumns');
                sdm = epoch.get('shapeDataMatrix');
                if ~(isa(sdm,'System.String') || isa(sdm,'char') || isa(sdm,'double'))
                    sdm = epoch.get('shapeData');
                end
                em = epoch.get('epochMode');
                obj.spotTotalTime = epoch.get('spotTotalTime');
                obj.spotOnTime = epoch.get('spotOnTime');
                obj.spotDiameter = epoch.get('spotDiameter');
                obj.searchDiameter = epoch.get('searchDiameter');
%                 obj.numSpots = epoch.get('numSpots');
                obj.ampMode = char(epoch.get('ampMode'));
                obj.ampVoltage = epoch.get('ampHoldSignal');
                obj.numValues = epoch.get('numValues');
                obj.numValueRepeats = epoch.get('numValueRepeats');
                obj.stimTime = epoch.get('stimTime');
                obj.positionOffset = [epoch.get('offsetX'),epoch.get('offsetY')];
                obj.timeOffset = epoch.get('timeOffset');
                obj.rigOffsetAngle = epoch.get('angleOffsetForRigAndStimulus');
                
            elseif strcmp(runmode, 'online')
                obj.sessionId = epoch.getParameter('sessionId');
                obj.presentationId = epoch.getParameter('presentationId');                
                sdc = epoch.getParameter('shapeDataColumns');
                sdm = epoch.getParameter('shapeDataMatrix');
                if ~(isa(sdm,'System.String') || isa(sdm,'char'))
                    sdm = epoch.getParameter('shapeData');
                end
                em = epoch.getParameter('epochMode');
                obj.spotTotalTime = epoch.getParameter('spotTotalTime');
                obj.spotOnTime = epoch.getParameter('spotOnTime');
                obj.spotDiameter = epoch.getParameter('spotDiameter');
                obj.searchDiameter = epoch.getParameter('searchDiameter');
%                 obj.numSpots = epoch.getParameter('numSpots');
                obj.ampMode = char(epoch.getParameter('ampMode'));
                obj.ampVoltage = epoch.getParameter('ampHoldSignal');                
                obj.numValues = epoch.getParameter('numValues');
                obj.numValueRepeats = epoch.getParameter('numValueRepeats');
                obj.stimTime = epoch.getParameter('stimTime');
                obj.positionOffset = [epoch.getParameter('offsetX'),epoch.getParameter('offsetY')];
                obj.timeOffset = nan;
                obj.rigOffsetAngle = epoch.getParameter('angleOffsetForRigAndStimulus');
            end
                       
            % process shape data from epoch
            obj.shapeDataColumns = containers.Map;
            newColumnsNames = {};
            newColumnsData = [];
            % collect what data we have to make the ShapeDataMatrix
            
            % positions w/ X,Y
            if ~(isa(sdc,'System.String') || isa(sdc,'char'))
                obj.shapeDataColumns('X') = 1;
                obj.shapeDataColumns('Y') = 2;
                obj.shapeDataMatrix = reshape(str2num(char(epoch.get('positions'))), [], 2);
            else
                % shapedata w/ X,Y,intensity...
                colsTxt = strsplit(char(sdc), ',');
                obj.shapeDataColumns('intensity') = find(not(cellfun('isempty', strfind(colsTxt, 'intensity'))));
                obj.shapeDataColumns('X') = find(not(cellfun('isempty', strfind(colsTxt, 'X'))));
                obj.shapeDataColumns('Y') = find(not(cellfun('isempty', strfind(colsTxt, 'Y'))));
                
                % ... startTime,endTime,diameter (also)
                % this is the main area for contemporary changes, the above
                % are mostly for making it work with old epochs
                if isa(em,'System.String') || isa(em,'char')
                    obj.epochMode = char(em);
                    obj.shapeDataColumns('diameter') = find(not(cellfun('isempty', strfind(colsTxt, 'diameter'))));
                    obj.shapeDataColumns('startTime') = find(not(cellfun('isempty', strfind(colsTxt, 'startTime'))));
                    obj.shapeDataColumns('endTime') = find(not(cellfun('isempty', strfind(colsTxt, 'endTime'))));
                    
                    ff = find(not(cellfun('isempty', strfind(colsTxt, 'flickerFrequency'))));
                    if ff
                        obj.shapeDataColumns('flickerFrequency') = ff;
                    end

                else
                    % or need to generate those later
                    obj.epochMode = 'flashingSpots';
                end
            
                num_cols = length(obj.shapeDataColumns);
                
                if isa(sdm,'double')
                    sdmNumbers = sdm; % symphony 2 has numerical storage
                else
                    sdmNumbers = str2num(char(sdm));
                end
                obj.shapeDataMatrix = reshape(sdmNumbers, [], num_cols); %#ok<*ST2NM>
            end
            

            obj.totalNumSpots = size(obj.shapeDataMatrix,1);
            
            % add default values for columns that we don't have in the epoch
            if ~isKey(obj.shapeDataColumns, 'intensity')
                newColumnsNames{end+1} = 'intensity';
                newColumnsData = horzcat(newColumnsData, ones(size(obj.shapeDataMatrix,1),1));
            end
            
            if ~isKey(obj.shapeDataColumns, 'startTime')
                si = (1:obj.totalNumSpots)';
                startTime = (si - 1) * obj.spotTotalTime;
                endTime = startTime + obj.spotOnTime;
                newColumnsNames{end+1} = 'startTime';
                newColumnsNames{end+1} = 'endTime';
                newColumnsData = horzcat(newColumnsData, startTime, endTime);
            end
                                
            if ~isKey(obj.shapeDataColumns, 'diameter')
                newColumnsData = horzcat(newColumnsData, obj.spotDiameter * ones(size(obj.shapeDataMatrix,1),1));
                newColumnsNames{end+1} = 'diameter';
            end
            
            if ~isKey(obj.shapeDataColumns, 'flickerFrequency')
                newColumnsData = horzcat(newColumnsData, zeros(size(obj.shapeDataMatrix,1),1));
                newColumnsNames{end+1} = 'flickerFrequency';
            end

            % add new columns to matrix and column Map
            for ci = 1:length(newColumnsNames)
                name = newColumnsNames{ci};
                obj.shapeDataMatrix = horzcat(obj.shapeDataMatrix, newColumnsData(:,ci));
                obj.shapeDataColumns(name) = size(obj.shapeDataMatrix, 2);
            end

            positions = obj.shapeDataMatrix(:, [obj.shapeDataColumns('X'), obj.shapeDataColumns('Y')]);

            % add offset to get real positions relative to center of scope
%             positions = bsxfun(@plus, positions, obj.positionOffset);
            
            % rotate positions using rig angle offset
            if isnan(obj.rigOffsetAngle)
                obj.rigOffsetAngle = 180;
                disp('AutoCenter epoch is missing angle offset, using default 180 for rig A');
            end

            theta = -1 * obj.rigOffsetAngle; % not sure if this should be positive or negative... test to confirm
            R = [cosd(theta) -sind(theta); sind(theta) cosd(theta)];
            for p = 1:size(positions, 1)
                positions(p,:) = (R * positions(p,:)')';
            end
            obj.shapeDataMatrix(:, [obj.shapeDataColumns('X'), obj.shapeDataColumns('Y')]) = positions;
            
            % process actual response or spikes from epoch
            if strcmp(runmode, 'offline')
                if strcmp(obj.ampMode, 'Cell attached')
                    obj.setSpikes(epoch.getSpikes(obj.channel));
                elseif strcmp(obj.ampMode, 'emulated')
                    obj.spikes = [];
                else % whole cell
                    obj.spikes = [];
                    obj.setResponse(epoch.getData(obj.channel)); %get whole cell response
                    obj.processWholeCell()
                end
            else
                obj.spikes = [];
                obj.response = [];
            end
        end
        
        function setResponse(obj, response)
            % downsample and generate time vector
            offset = response(1); % offset to avoid resample filtering artifact at start
            % should I reoffset afterward? don't know.
            response = resample(response - offset, obj.sampleRate, 10000);
            obj.response = response;
            obj.t = (0:(length(obj.response)-1))' / obj.sampleRate;
            obj.t = obj.t - obj.preTime;
        end
        
        function setSpikes(obj, spikes)
            if isnan(spikes)
                disp('No spikes found (detect them maybe?)')
            else
                obj.spikes = spikes;
                obj.processSpikes()
            end
        end
    
        function processSpikes(obj)
            % convert spike times to raw response
            
            if ~isempty(obj.spikes)
                spikeRate_orig = zeros(max(obj.spikes) + 100, 1);
                spikeRate_orig(obj.spikes) = 1.0;
                obj.spikeRate = filtfilt(hann(obj.sampleRate / 10), 1, spikeRate_orig); % 10 ms (100 samples) window filter
            else
                obj.spikeRate = 0;
            end
            obj.setResponse(obj.spikeRate)
        end
        
        function processWholeCell(obj)
%             figure(99)
            % call after setResponse to make current like spikeRate
%             subplot(4,1,1)
            
            % flip currents
            resp = obj.response;
%             resp = sign(obj.ampVoltage + eps) * resp; % use positive for 0 mV
            
            % exponential decay cancellation
            if max(obj.t) > 6.0
                % first order fit the whole length
                resp = resp - mean(resp((end-100):end)); % set end to 0
                startA = mean(resp(1:100))/exp(0);
                startB = -0.1;
                f1 = fit(obj.t, resp, 'exp1','StartPoint',[startA, startB]);
                resp = resp - f1(obj.t);
                
                % second order cancel just the very beginning (no, cause it could be bad for the whole thing)
                startA = mean(resp(1:100))/exp(0);
                startB = -1;
                f2 = fit(obj.t, resp, 'exp1','StartPoint',[startA, startB]);
                resp = resp - f2(obj.t);
                
                obj.signalNormalizationParameters = [f1.a, f1.b, f2.a, f2.b];
%                 disp(obj.signalNormalizationParameters)
            end
            
            
%             r = r - median(r(1:round(obj.sampleRate*obj.preTime)));
%             r = r - r(1);
%             plot(r)
%             r = r - mean(r);
%             subplot(4,1,2); plot(r);
            
%             Fstop = .02;
%             Fpass = .03;
%             Astop = 20;
%             Apass = 0.5;
%             wc_filter = designfilt('highpassiir','StopbandFrequency',Fstop, ...
%                 'PassbandFrequency',Fpass,'StopbandAttenuation',Astop, ...
%                 'PassbandRipple',Apass,'SampleRate',obj.sampleRate);
            
%             wc_filter = butter(200, .000001, 'high');
%             wc_filter = [0.999879883755627,-19.9975976751125,189.977177913569,-1139.86306748141,4844.41803679601,-15502.1377177472,38755.3442943681,-77510.6885887362,125954.868956696,-167939.825275595,184733.807803155,-167939.825275595,125954.868956696,-77510.6885887362,38755.3442943681,-15502.1377177472,4844.41803679601,-1139.86306748141,189.977177913569,-19.9975976751125,0.999879883755627];
            
%             resp = filtfilt(wc_filter, 1, resp);
%             subplot(4,1,3)
%             plot(r)
                        
%             r = r - prctile(r,10); % set the bottom 10 % of samples to be negative, to keep things generally positive
           
%             r = r - median(r(1:round(obj.sampleRate*obj.preTime)));

%             subplot(4,1,4)
%             plot(r)
%             pause
            
%             fprintf('%d %d ', obj.sessionId, obj.presentationId)
%             fprintf('processing wc %d V\n', obj.ampVoltage);
            obj.response = resp;
            

        end
        
        function simulateSpikes(obj)
            sp = simulateSpikeTrain(obj);
            obj.setSpikes(sp);
        end
    end
end



% signalData = {};
% if strcmp(responsemode, 'ca')
%     % cell attached spikes
%     if isempty(varargin) % responses included in epochs already
%         for p = 1:num_epochs
%             epoch = epochData{p,1};
%             signalData{p,1} = epoch.getSpikes();
%         end
%     else
%         signalData = varargin{1};
%     end
% else
%     % whole cell signal
%     if isempty(varargin)
%         for p = 1:num_epochs
%             epoch = epochData{p,1};
%             [signal, ~, ~] = epoch.response();
%             signalData{p,1} = signal;
%         end
%     else
%         signalData = varargin{1};
%     end
% end
