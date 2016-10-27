function results = SpikeDetector_simple(D, SampleInterval, thres_std)
% tic
% 
% disp('test')
% figure(100)
% ha = tight_subplot(3,1);

HighPassCut_drift = 70; %Hz, in order to remove drift and 60Hz noise
HighPassCut_spikes = 500; %Hz, in order to remove everything but spikes
ref_period = 2E-3; %s
searchInterval = 1E-3; %s

results = [];

ref_period_points = round(ref_period./SampleInterval);
searchInterval_points = round(searchInterval./SampleInterval);

[Ntraces,L] = size(D);
% plot(ha(1), D)
signal_noise = BandPassFilter(D,HighPassCut_drift,HighPassCut_spikes,SampleInterval);
% plot(ha(2), signal_noise)
signal_filtered = HighPassFilter(D,HighPassCut_spikes,SampleInterval);
% plot(ha(3), signal_filtered)

sp = cell(Ntraces,1);
spikeAmps = cell(Ntraces,1);
violation_ind = cell(Ntraces,1);
minSpikePeakInd = zeros(Ntraces,1);
for i=1:Ntraces
    %get the trace and noise_std
    trace = signal_filtered(i,:);
    trace(1:20) = D(i,1:20) - mean(D(i,1:20));
%     plot(trace);
%     pause;
   if abs(max(trace)) > abs(min(trace)) %flip it over
       trace = -trace;
   end


    trace_noise = signal_noise(i,:);
    noise_std = std(trace_noise);
    
    %get peaks
    [peaks,peak_times] = getPeaks(trace,-1); %-1 for negative peaks
    peak_times = peak_times(peaks<0); %only negative deflections
    peaks = trace(peak_times);    
    
    %add a check for rebounds on the other side
    r = getRebounds(peak_times,trace,searchInterval_points);
    peaks = abs(peaks);
    peakAmps = peaks+r;
    if ~isempty(peaks) && max(D(i,:)) > min(D(i,:)) %make sure we don't have bad/empty trace
        spike_ind = find(peakAmps>thres_std*noise_std);
                               
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
