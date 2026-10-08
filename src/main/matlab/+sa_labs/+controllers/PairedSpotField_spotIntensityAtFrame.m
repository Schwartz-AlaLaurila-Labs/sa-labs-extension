function c = PairedSpotField_spotIntensityAtFrame(frame, stimFrames, spotPre, spotPreStim, spotPreStimPost, bg, sI)
%PAIREDSPOTFIELD_SPOTINTENSITYATFRAME Controller helper for sa_labs.protocols.stage.PairedSpotField; runs on the Stage server, so it must stay free of protocol-object references.
    if (frame < 0) || (frame >= stimFrames)
        c = bg;
        return
    end
    i = min(floor(frame / spotPreStimPost) + 1, length(sI)); %spot index
    j = mod(frame, spotPreStimPost);
    if (j < spotPre) || (j >= spotPreStim)
        c = bg;
    else
        c = sI(i);
    end
end
