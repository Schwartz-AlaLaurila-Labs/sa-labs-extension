function i = Temporal_Noise_1_f_noiseIntensity(frame, stimFrames, frameDwell, spotMeanLevel, noise_series)
%TEMPORAL_NOISE_1_F_NOISEINTENSITY Controller helper for sa_labs.protocols.stage.Temporal_Noise_1_f; runs on the Stage server, so it must stay free of protocol-object references.
    persistent intensity;
    if (frame < 0) || (frame > stimFrames)
        intensity = spotMeanLevel;
    else
        if mod(frame, frameDwell) == 0 %noise update
            if frame < length(noise_series) % Ensure valid indexing
                intensity = noise_series(frame + 1);
            else
                intensity = noise_series(end); % Prevent out-of-bounds error
            end
        end
    end
    i = intensity;
    intensity = sa_labs.controllers.Temporal_Noise_1_f_clipIntensity(intensity, spotMeanLevel);
end
