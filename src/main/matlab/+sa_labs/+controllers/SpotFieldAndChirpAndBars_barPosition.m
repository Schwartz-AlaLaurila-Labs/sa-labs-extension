function xy = SpotFieldAndChirpAndBars_barPosition(frame, xStartPos, yStartPos, xStep, yStep)
%SPOTFIELDANDCHIRPANDBARS_BARPOSITION Controller helper for sa_labs.protocols.stage.SpotFieldAndChirpAndBars; runs on the Stage server, so it must stay free of protocol-object references.
    xy = [NaN, NaN];

    i = mod(frame, 210); % TODO: this assumes frame rate of 60
    t = floor(frame / 210) + 1;

    if i >= 15 && i < 195 %i.e., 3sec per bar
        xy = [xStartPos(t) + (i-15) * xStep(t), yStartPos(t) + (i-15) * yStep(t)];
    end
end
