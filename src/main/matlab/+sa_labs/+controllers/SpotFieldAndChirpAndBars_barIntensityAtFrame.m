function c = SpotFieldAndChirpAndBars_barIntensityAtFrame(frame, nFrames, bI)
%SPOTFIELDANDCHIRPANDBARS_BARINTENSITYATFRAME Controller helper for sa_labs.protocols.stage.SpotFieldAndChirpAndBars; runs on the Stage server, so it must stay free of protocol-object references.
    if frame >= (nFrames - 1)
        c = 0;
        return
    end

    i = mod(frame, 210); % TODO: this assumes frame rate of 60
    if (i < 15) || (i >= 195)
        c = 0;
    else
        c = bI;
    end
end
