function intensity = TemporalNoise_clipIntensity(intensity, mn)
%TEMPORALNOISE_CLIPINTENSITY Controller helper for sa_labs.protocols.stage.TemporalNoise; runs on the Stage server, so it must stay free of protocol-object references.
    intensity(intensity > mn * 2) = mn * 2;
    intensity(intensity < 0) = 0;
    intensity(intensity > 1) = 1;
end
