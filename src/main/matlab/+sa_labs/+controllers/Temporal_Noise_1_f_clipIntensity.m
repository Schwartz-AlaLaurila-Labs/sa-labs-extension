function intensity = Temporal_Noise_1_f_clipIntensity(intensity, mn)
%TEMPORAL_NOISE_1_F_CLIPINTENSITY Controller helper for sa_labs.protocols.stage.Temporal_Noise_1_f; runs on the Stage server, so it must stay free of protocol-object references.
    intensity(intensity > mn * 2) = mn * 2;
    intensity(intensity < 0) = 0;
    intensity(intensity > 1) = 1;
end
