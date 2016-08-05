classdef SpikeDetector < handle
    %SPIKEDETECTOR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        HighPassCut_drift = 70; %Hz, in order to remove drift and 60Hz noise
        HighPassCut_spikes = 500; %Hz, in order to remove everything but spikes
        ref_period = 2E-3; %s
        searchInterval = 1E-3; %s
        SampleInterval
        thres_std
    end
    
    methods
        
        function Xfilt = BandPassFilter(obj, X, low, high)
            Xfilt = obj.LowPassFilter(obj.HighPassFilter(X, low), high);
        end
        
        function Xfilt = HighPassFilter(obj, X, F)
            % %F is in Hz
            % %Sample interval is in seconds
            % %X is a vector or a matrix of row vectors
            L = size(X,2);
            if L == 1 %flip if given a column vector
                X=X';
                L = size(X,2);
            end
            
            FreqStepSize = 1/(obj.SampleInterval * L);
            FreqKeepPts = round(obj.HighPassCut_ / FreqStepSize);
            
            FFTData = fft(X, [], 2);
            FFTData(:,1:FreqKeepPts) = 0;
            FFTData(end-FreqKeepPts:end) = 0;
            Xfilt = real(ifft(FFTData, [], 2));
        end
        
        function Xfilt = LowPassFilter(obj, X)
            L = size(X,2);
            if L == 1 %flip if given a column vector
                X=X';
                L = size(X,2);
            end
            
            FreqStepSize = 1/(obj.SampleInterval * L);
            FreqCutoffPts = round(obj.HighPassCut_spikes / FreqStepSize);
            
            FFTData = fft(X, [], 2);
            FFTData(:,FreqCutoffPts:size(FFTData,2)-FreqCutoffPts) = 0;
            Xfilt = real(ifft(FFTData, [], 2));
            
        end
        
        function Ind = getThresCross(obj, V, th, dir)
            %dir 1 = up, -1 = down
            Vorig = V(1:end-1);
            Vshift = V(2:end);
            
            if dir>0
                Ind = find(Vorig<th & Vshift>=th) + 1;
            else
                Ind = find(Vorig>=th & Vshift<th) + 1;
            end
        end
        
        function r = getRebounds(obj, trace, peaks_ind)
            %get rebound as fraction of peak amplitude
            
            %trace = abs(trace);
            peaks = trace(peaks_ind);
            r = zeros(size(peaks));
            
            for i=1:length(peaks)
                endPoint = min(peaks_ind(i)+obj.searchInterval, length(trace));
                nextMin = getPeaks(trace(peaks_ind(i):endPoint),-1);
                if isempty(nextMin), nextMin = peaks(i);
                else nextMin = nextMin(1); end
                nextMax = getPeaks(trace(peaks_ind(i):endPoint),1);
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
            
            if strcmp(obj.spikeDetectorMode, 'Simple threshold')
                data = data - mean(data);
                sp = obj.getThresCross(data, obj.spikeThreshold, sign(obj.spikeThreshold));
                results.sp = sp;
                
            else
                
                ref_period_points = round(obj.ref_period./obj.SampleInterval);
                searchInterval_points = round(obj.searchInterval./obj.SampleInterval);
                
                [Ntraces,~] = size(data);
                D_noSpikes = obj.BandPassFilter(data);
                Dhighpass = obj.HighPassFilter(data);
                
                sp = cell(Ntraces,1);
                spikeAmps = cell(Ntraces,1);
                violation_ind = cell(Ntraces,1);
                minSpikePeakInd = zeros(Ntraces,1);
                
                for i=1:Ntraces
                    %get the trace and noise_std
                    trace = Dhighpass(i,:);
                    trace(1:20) = data(i,1:20) - mean(data(i,1:20));
                    %     plot(trace);
                    %     pause;
                    if abs(max(trace)) > abs(min(trace)) %flip it over
                        trace = -trace;
                    end
                    
                    
                    trace_noise = D_noSpikes(i,:);
                    noise_std = std(trace_noise);
                    
                    %get peaks
                    [peaks,peak_times] = getPeaks(trace,-1); %-1 for negative peaks
                    peak_times = peak_times(peaks<0); %only negative deflections
                    peaks = trace(peak_times);
                    
                    %add a check for rebounds on the other side
                    r = getRebounds(peak_times,trace,searchInterval_points);
                    peaks = abs(peaks);
                    peakAmps = peaks+r;
                    
                    if ~isempty(peaks) && max(data(i,:)) > min(data(i,:)) %make sure we don't have bad/empty trace
                        spike_ind = find(peakAmps > obj.thres_std*noise_std);
                        
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
            end
        end
    end
end

