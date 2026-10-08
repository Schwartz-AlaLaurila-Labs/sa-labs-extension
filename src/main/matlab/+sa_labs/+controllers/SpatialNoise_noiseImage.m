function i = SpatialNoise_noiseImage(frame, dimensions, frameDwell, meanLevel, contrast, noiseFn)
%SPATIALNOISE_NOISEIMAGE Controller helper for sa_labs.protocols.stage.SpatialNoise; runs on the Stage server, so it must stay free of protocol-object references.
    % TODO: verify X vs Y in matrix
    persistent intensity;
    if frame < 0 %pre frames. frame 0 starts stimPts
        intensity = meanLevel;
        intensity = sa_labs.controllers.SpatialNoise_clipIntensity(intensity, meanLevel);
    else %in stim frames
        if mod(frame, frameDwell) == 0 %noise update
            intensity = meanLevel + ...
                contrast * meanLevel * noiseFn(dimensions);
            intensity = sa_labs.controllers.SpatialNoise_clipIntensity(intensity, meanLevel);
        end
    end
    %                 intensity = imgaussfilt(intensity, 1);
    i = intensity;
end
