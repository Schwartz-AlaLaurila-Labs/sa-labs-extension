function spikes = simulateSpikeTrain(sd)

% shapeDataMatrix
% shapeDataColumns

center = [0,0];
width = 70;
baseFiringRate = 200; % Hz
baseDiameter = 30;

col_x = sd.shapeDataColumns('X');
col_y = sd.shapeDataColumns('Y');
col_intensity = sd.shapeDataColumns('intensity');
col_startTime = sd.shapeDataColumns('startTime');
col_endTime = sd.shapeDataColumns('endTime');
col_diameter = sd.shapeDataColumns('diameter');

% setup time vector
endTime = sd.shapeDataMatrix(:,col_endTime);

t = 0:(1/sd.sampleRate):(max(endTime) + 1);

% vector of light intensity
lightIntensity = zeros(size(t));

epoch_positions = sd.shapeDataMatrix(:,[col_x col_y]);
epoch_intensities = sd.shapeDataMatrix(:,col_intensity);
startTime = sd.shapeDataMatrix(:,col_startTime);
diams = sd.shapeDataMatrix(:,col_diameter);

diam_intensity = (diams ./ baseDiameter);
rf_intensity = receptiveFieldStrength(center, width, epoch_positions);
real_intensities = epoch_intensities .* diam_intensity .* rf_intensity;

for si = 1:sd.totalNumSpots
    lightIntensity(t > startTime(si) & t < endTime(si)) = real_intensities(si);
end

% ha=[];
% figure(15)
% ha(1) = subplot(3,1,1);
% area(t, lightIntensity)

% convolve with temporal filter

% filter = zeros(ones(1);
% save('li.mat','lightIntensity')
% [b,a] = butter(40, .7, 'high');
lightIntensityFiltered = lightIntensity;%abs(filter(b, a, lightIntensity)) * 10;
delay = .250 + .08;%+ .1 + rand() * .5;
shiftFrames = round(delay * sd.sampleRate);
lightIntensityFiltered = [zeros(1, shiftFrames) lightIntensityFiltered(1:(end-shiftFrames))];

% ha(2) = subplot(3,1,2);
% area(t, lightIntensityFiltered)

% time bin to rate
% pd = makedist('Poisson');
chance = rand(size(t));
rate = lightIntensityFiltered * baseFiringRate / sd.sampleRate;


spikeBins = rate > chance;

% ha(3) = subplot(3,1,3);
% area(t, spikeBins)
% linkaxes(ha)

% poisson generator and collect spikes
spikes = 10 * find(spikeBins); % 10 multiplier to match hardware sampling rate

end

function strengths = receptiveFieldStrength(center, width, positions)
%     strengths = ones(size(positions,1), 1);
    diffs = bsxfun(@plus, positions, -1 * center);
    dists = sqrt(sum(diffs.^2, 2));
    strengths = exp(-(dists/width).^2);
end