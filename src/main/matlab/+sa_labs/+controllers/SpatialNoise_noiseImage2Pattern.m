function i = SpatialNoise_noiseImage2Pattern(frame, pattern, dimensions, frameDwell, meanLevel1, contrast1, meanLevel2, contrast2, noiseFn)
%SPATIALNOISE_NOISEIMAGE2PATTERN Controller helper for sa_labs.protocols.stage.SpatialNoise; runs on the Stage server, so it must stay free of protocol-object references.
    persistent intensity;
    if isempty(intensity)
        intensity = cell(2,1);
    end
    if pattern == 1
        mn = meanLevel1;
        c = contrast1;
    else
        mn = meanLevel2;
        c = contrast2;
    end

    if frame<0 %pre frames. frame 0 starts stimPts
        intensity{pattern} = mn;
        intensity{pattern} = sa_labs.controllers.SpatialNoise_clipIntensity(intensity{pattern}, mn);
    else %in stim frames
        if mod(frame, frameDwell) == 0 %noise update
            intensity{pattern} = mn + c * mn * noiseFn(dimensions);
            intensity{pattern} = sa_labs.controllers.SpatialNoise_clipIntensity(intensity{pattern}, mn);
        end

    end

    i = intensity{pattern};
end
