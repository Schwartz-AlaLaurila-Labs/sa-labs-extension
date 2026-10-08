function intensity = CenterSurroundNoise_clipIntensity(intensity, mn)
%CENTERSURROUNDNOISE_CLIPINTENSITY Controller helper for sa_labs.protocols.stage.CenterSurroundNoise; runs on the Stage server, so it must stay free of protocol-object references.
    if intensity < 0
        intensity = 0;
    elseif intensity > mn * 2
        intensity = mn * 2; % probably important to be symmetrical to whiten the stimulus
    elseif intensity > 1
        intensity = 1;
    end
end
