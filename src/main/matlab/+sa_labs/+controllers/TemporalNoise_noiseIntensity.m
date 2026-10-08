function i = TemporalNoise_noiseIntensity(frame, stimFrames, frameDwell, spotMeanLevel, contrast, noiseFn)
%TEMPORALNOISE_NOISEINTENSITY Controller helper for sa_labs.protocols.stage.TemporalNoise; runs on the Stage server, so it must stay free of protocol-object references.
    persistent intensity;
    if (frame < 0) || (frame > stimFrames)
        intensity = spotMeanLevel;
        intensity = sa_labs.controllers.TemporalNoise_clipIntensity(intensity, spotMeanLevel);
    else
        if mod(frame, frameDwell) == 0
            intensity = spotMeanLevel + spotMeanLevel * contrast * noiseFn();
            intensity = sa_labs.controllers.TemporalNoise_clipIntensity(intensity, spotMeanLevel);
        end
    end
    i = intensity;
end
