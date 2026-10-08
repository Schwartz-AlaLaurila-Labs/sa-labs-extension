function intensity = SpatialNoise_clipIntensity(intensity, mn)
%SPATIALNOISE_CLIPINTENSITY Controller helper for sa_labs.protocols.stage.SpatialNoise; runs on the Stage server, so it must stay free of protocol-object references.
    intensity(intensity < 0) = 0;
    intensity(intensity > mn * 2) = mn * 2;
    intensity(intensity > 1) = 1;
    intensity = uint8(255 * intensity);
end
