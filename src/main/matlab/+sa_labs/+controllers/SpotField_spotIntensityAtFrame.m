function c = SpotField_spotIntensityAtFrame(frame, spotPreStimPost, nSpots, spotPre, spotPreStim, intensities)
%SPOTFIELD_SPOTINTENSITYATFRAME Controller helper for sa_labs.protocols.stage.SpotField; runs on the Stage server, so it must stay free of protocol-object references.
    spot_ind = min(floor(frame / spotPreStimPost) + 1, nSpots);
    spot_intensity = intensities(spot_ind);

    i = mod(frame, spotPreStimPost);
    if (i < spotPre) || (i >= spotPreStim)
        c = 0;
    else
        c = spot_intensity;
    end
end
