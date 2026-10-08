function intensity = White_to_Pink_Temporal_Noise_clipIntensity(intensity, meanLevel)
%WHITE_TO_PINK_TEMPORAL_NOISE_CLIPINTENSITY Controller helper for sa_labs.protocols.stage.White_to_Pink_Temporal_Noise; runs on the Stage server, so it must stay free of protocol-object references.
    % Ensures the intensity stays within valid range
    intensity(intensity > meanLevel * 2) = meanLevel * 2;
    intensity(intensity < 0) = 0;
    intensity(intensity > 1) = 1;
end
