classdef SpikeDetector < handle
    
    properties
%         freq_driftAndNoise = 70; %Hz, in order to remove drift and 60Hz noise
%         freq_spikeLowerThreshold = 500; %Hz, in order to remove everything but spikes
%         highPassFilter
%         bandPassFilter
%         ref_period = 2E-3; %s
%         searchInterval = 1E-3; %s
%         sampleInterval = 1E-4;
%         thres_std
        spikeDetectorMode
        spikeThreshold
        
        % advanced:
        spikeFilter
    end
    
    methods
        
        function obj = SpikeDetector(spikeDetectorMode, spikeThreshold)
            obj.spikeThreshold = spikeThreshold;
            obj.spikeDetectorMode = spikeDetectorMode;
            %             if ~strcmp(obj.spikeDetectorMode, 'Simple threshold')
            
            %             [b,a] = butter(21, obj.freq_spikeLowerThreshold / (.5/obj.sampleInterval), 'high');
            %             obj.highPassFilter = {b,a};
            %
            %             [b,a] = butter(21, [obj.freq_driftAndNoise, obj.freq_spikeLowerThreshold] / (.5/obj.sampleInterval));
            %             obj.bandPassFilter = {b,a};
            %             end
            
            obj.spikeFilter = designfilt('bandpassiir', 'StopbandFrequency1', 200, 'PassbandFrequency1', 300, 'PassbandFrequency2', 3000, 'StopbandFrequency2', 3500, 'StopbandAttenuation1', 60, 'PassbandRipple', 1, 'StopbandAttenuation2', 60, 'SampleRate', 10000);
        end
        
        function Xfilt = BandPassFilter(obj, X,low,high,SampleInterval)
            %this is not really correct
            Xfilt = obj.LowPassFilter(obj.HighPassFilter(X,low,SampleInterval),high,SampleInterval);
        end
        
        function Xfilt = HighPassFilter(~, X,F,SampleInterval)
            % %F is in Hz
            % %Sample interval is in seconds
            % %X is a vector or a matrix of row vectors
            L = size(X,2);
            if L == 1 %flip if given a column vector
                X=X';
                L = size(X,2);
            end
            
            FreqStepSize = 1/(SampleInterval * L);
            FreqKeepPts = round(F / FreqStepSize);
            
            % eliminate frequencies beyond cutoff (middle of matrix given fft
            % representation)
            
            FFTData = fft(X, [], 2);
            FFTData(:,1:FreqKeepPts) = 0;
            FFTData(end-FreqKeepPts:end) = 0;
            Xfilt = real(ifft(FFTData, [], 2));
            
            % Wn = F*SampleInterval; %normalized frequency cutoff
            % [z, p, k] = butter(1,Wn,'high');
            % [sos,g]=zp2sos(z,p,k);
            % myfilt=dfilt.df2sos(sos,g);
            % Xfilt = filter(myfilt,X');
            % Xfilt = Xfilt';
        end
        
        function Xfilt = LowPassFilter(~, X,F,SampleInterval)
            %F is in Hz
            %Sample interval is in seconds
            %X is a vector or a matrix of row vectors
            
            L = size(X,2);
            if L == 1 %flip if given a column vector
                X=X';
                L = size(X,2);
            end
            
            FreqStepSize = 1/(SampleInterval * L);
            FreqCutoffPts = round(F / FreqStepSize);
            
            % eliminate frequencies beyond cutoff (middle of matrix given fft
            % representation)
            FFTData = fft(X, [], 2);
            FFTData(:,FreqCutoffPts:size(FFTData,2)-FreqCutoffPts) = 0;
            Xfilt = real(ifft(FFTData, [], 2));
            
            
            % Wn = F*SampleInterval; %normalized frequency cutoff
            % [z, p, k] = butter(1,Wn,'low');
            % [sos,g]=zp2sos(z,p,k);
            % myfilt=dfilt.df2sos(sos,g);
            % Xfilt = filter(myfilt,X');
            % Xfilt = Xfilt';
            
        end
        
        
        function [peaks,Ind] = getPeaks(~, X,dir)
            if dir > 0 %local max
                Ind = find(diff(diff(X)>0)<0)+1;
            else %local min
                Ind = find(diff(diff(X)>0)>0)+1;
            end
            peaks = X(Ind);
        end
        
        function Ind = getThresCross(~, signal, threshold, direction)
            %             disp(obj.highPassFilter{1})
            %             figure(77)
            %             signalf = filtfilt(obj.highPassFilter{1}, obj.highPassFilter{2}, signal);
            %             subplot(2,1,1)
            %             plot(signal)
            %             subplot(2,1,2)
            %             plot(signalf)
            
            %dir 1 = up, -1 = down
            Vorig = signal(1:end-1);
            Vshift = signal(2:end);
            
            if direction>0
                Ind = find(Vorig<threshold & Vshift>=threshold) + 1;
            else
                Ind = find(Vorig>=threshold & Vshift<threshold) + 1;
            end
        end
        
        function r = getRebounds(obj, peaks_ind,trace,searchInterval)
            %get rebound as fraction of peak amplitude
            
            %trace = abs(trace);
            peaks = trace(peaks_ind);
            r = zeros(size(peaks));
            
            for i=1:length(peaks)
                endPoint = min(peaks_ind(i)+searchInterval,length(trace));
                nextMin = obj.getPeaks(trace(peaks_ind(i):endPoint),-1);
                if isempty(nextMin), nextMin = peaks(i);
                else nextMin = nextMin(1); end
                nextMax = obj.getPeaks(trace(peaks_ind(i):endPoint),1);
                if isempty(nextMax), nextMax = 0;
                else nextMax = nextMax(1); end
                
                if nextMin<peaks(i) %not the real spike min
                    r(i) = 0;
                else
                    r(i) = nextMax;
                end
            end
        end
        
        
        function results = detectSpikes(obj, data)
            results = struct();
            
            if strcmp(obj.spikeDetectorMode, 'none')
                results.sp = [];
                return
            end
            
            if strcmp(obj.spikeDetectorMode, 'Simple Threshold')
                data = data - mean(data);
                sp = obj.getThresCross(data, obj.spikeThreshold, sign(obj.spikeThreshold));
                results.sp = sp;
                
            elseif strcmp(obj.spikeDetectorMode, 'Filtered Threshold')
                
                
                HighPassCut_drift = 70; %Hz, in order to remove drift and 60Hz noise
                HighPassCut_spikes = 500; %Hz, in order to remove everything but spikes
                ref_period = 2E-3; %s
                searchInterval = 1E-3; %s
                SampleInterval = 1E-4;                
                
                results = [];
                
                ref_period_points = round(ref_period./SampleInterval);
                searchInterval_points = round(searchInterval./SampleInterval);
                
                [Ntraces,L] = size(data);
                % plot(ha(1), D)
                signal_noise = obj.BandPassFilter(data,HighPassCut_drift,HighPassCut_spikes,SampleInterval);
                % plot(ha(2), signal_noise)
                signal_filtered = obj.HighPassFilter(data,HighPassCut_spikes,SampleInterval);
                % plot(ha(3), signal_filtered)
                
                sp = cell(Ntraces,1);
                spikeAmps = cell(Ntraces,1);
                violation_ind = cell(Ntraces,1);
                minSpikePeakInd = zeros(Ntraces,1);
                for i=1:Ntraces
                    %get the trace and noise_std
                    trace = signal_filtered(i,:);
                    trace(1:20) = data(i,1:20) - mean(data(i,1:20));
                    %     plot(trace);
                    %     pause;
                    if abs(max(trace)) > abs(min(trace)) %flip it over
                        trace = -trace;
                    end
                    
                    
                    trace_noise = signal_noise(i,:);
                    noise_std = std(trace_noise);
                    
                    %get peaks
                    [peaks,peak_times] = obj.getPeaks(trace,-1); %-1 for negative peaks
                    peak_times = peak_times(peaks<0); %only negative deflections
                    peaks = trace(peak_times);
                    
                    %add a check for rebounds on the other side
                    r = obj.getRebounds(peak_times,trace,searchInterval_points);
                    peaks = abs(peaks);
                    peakAmps = peaks+r;
                    if ~isempty(peaks) && max(data(i,:)) > min(data(i,:)) %make sure we don't have bad/empty trace
                        spike_ind = find(peakAmps > abs(obj.spikeThreshold) * noise_std);
                        
                        if isempty(spike_ind)
                            disp(['Epoch ' num2str(i) ': no spikes']);
                            sp{i} = [];
                            spikeAmps{i} = [];
                        else %spikes found
                            spike_peaks = peaks(spike_ind);
                            sp{i} = peak_times(spike_ind);
                            spikeAmps{i} = spike_peaks./noise_std;
                            
                            [minSpikePeak,minSpikePeakInd(i)] = min(spike_peaks);
                            
                            %check for violations again, just for warning this time
                            violation_ind{i} = find(diff(sp{i})<ref_period_points) + 1;
                            ref_violations = length(violation_ind{i});
                            if ref_violations>0
                                %find(diff(sp{i})<ref_period_points)
                                disp(['warning, trial '  num2str(i) ': ' num2str(ref_violations) ' refractory violations']);
                            end
                        end %if spikes found
                    end %end if not bad trace
                end
                
                if length(sp) == 1 %return vector not cell array if only 1 trial
                    sp = sp{1};
                    spikeAmps = spikeAmps{1};
                    violation_ind = violation_ind{1};
                end
                results.sp = sp;
                results.spikeAmps = spikeAmps;
                results.minSpikePeakInd = minSpikePeakInd;
                results.violation_ind = violation_ind;
                
            elseif strcmp(obj.spikeDetectorMode, 'advanced')
                response = data - mean(data);
                [fresponse, noise] = obj.filterResponse(response);
                spikeIndices = obj.getThresCross(fresponse, noise * obj.spikeThreshold, sign(obj.spikeThreshold));

                % refine spike locations to tips
                if obj.spikeThreshold < 0
                    for si = 1:length(spikeIndices)
                        sp = spikeIndices(si);
                        if sp < 100 || sp > length(response) - 100
                            continue
                        end
                        while response(sp) > response(sp+1)
                            sp = sp+1;
                        end
                        while response(sp) > response(sp-1)
                            sp = sp-1;
                        end
                        spikeIndices(si) = sp;
                    end
                else
                    for si = 1:length(spikeIndices)
                        sp = spikeIndices(si);
                        if sp < 100 || sp > length(response) - 100
                            continue
                        end                             
                        while response(sp) < response(sp+1)
                            sp = sp+1;
                        end
                        while response(sp) < response(sp-1)
                            sp = sp-1;
                        end
                        spikeIndices(si) = sp;
                    end
                end
                
                %remove double-counted spikes
                if length(spikeIndices) >= 2
                    ISItest = diff(spikeIndices);
                    spikeIndices = spikeIndices([(ISItest > (0.001 * 10000)) true]);
                end
                
                results.sp = spikeIndices;
%                 results.spikeAmps = spikeAmps;
%                 results.minSpikePeakInd = minSpikePeakInd;
%                 results.violation_ind = violation_ind;
                results.filtered = fresponse;
                
            else
                warning('unknown spike detector mode')
            end
        end
        
        function [fdata, noise] = filterResponse(obj, fdata)
            fdata = [fdata(1) + zeros(1,2000), fdata, fdata(end) + zeros(1,2000)];
            fdata = filtfilt(obj.spikeFilter, fdata);
            fdata = fdata(2001:(end-2000));
            noise = median(abs(fdata) / 0.6745);
        end        
        
    end
    
end

