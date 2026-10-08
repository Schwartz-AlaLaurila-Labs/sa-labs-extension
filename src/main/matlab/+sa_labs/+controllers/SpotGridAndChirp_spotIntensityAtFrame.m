function c = SpotGridAndChirp_spotIntensityAtFrame(frame, nFrames, spotPreStimPost, spotPre, spotPreStim, sI)
%SPOTGRIDANDCHIRP_SPOTINTENSITYATFRAME Controller helper for sa_labs.protocols.stage.SpotGridAndChirp; runs on the Stage server, so it must stay free of protocol-object references.
    if frame >= nFrames - 1
        c = 0;
        return
    end

    i = mod(frame, spotPreStimPost);

    if i < spotPre || i >= spotPreStim
        c = 0;
    else
        c = sI;
    end
end
