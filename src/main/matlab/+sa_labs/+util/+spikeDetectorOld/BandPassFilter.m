function Xfilt = BandPassFilter(X,low,high,SampleInterval)
%this is not really correct
Xfilt = LowPassFilter(HighPassFilter(X,low,SampleInterval),high,SampleInterval);
