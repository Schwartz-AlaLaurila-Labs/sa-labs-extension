function intensity = low_high_TemporalContrast_clipIntensity(intensity, mean_level)
%LOW_HIGH_TEMPORALCONTRAST_CLIPINTENSITY Controller helper for sa_labs.protocols.stage.low_high_TemporalContrast; runs on the Stage server, so it must stay free of protocol-object references.
    intensity(intensity > mean_level * 2) = mean_level * 2;
    intensity(intensity < 0) = 0;
    intensity(intensity > 1) = 1;
end
