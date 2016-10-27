function r = getRebounds(peaks_ind,trace,searchInterval)
%get rebound as fraction of peak amplitude

%trace = abs(trace);
peaks = trace(peaks_ind);
r = zeros(size(peaks));

for i=1:length(peaks)
   endPoint = min(peaks_ind(i)+searchInterval,length(trace));
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
