import sa_labs.util.*;

% sd = sa_labs.util.SpikeDetector('Simple threshold');
sd = sa_labs.util.SpikeDetector('');

sd.spikeThreshold = 1;

sampleInterval = .0001;
t = 0:sampleInterval:1;
data = randn(size(t));

result = sd.detectSpikes(data);

clf
plot(t, data)
hold on
plot(result.sp * sampleInterval, data(result.sp), 'o')
hold off

fprintf('Spike count: %d\n',length(result.sp))