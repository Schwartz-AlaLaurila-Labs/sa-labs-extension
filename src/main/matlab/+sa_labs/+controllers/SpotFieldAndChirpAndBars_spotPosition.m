function xy = SpotFieldAndChirpAndBars_spotPosition(frame, spotPreStimPost, nSpots, canvasSize, cx, cy)
%SPOTFIELDANDCHIRPANDBARS_SPOTPOSITION Controller helper for sa_labs.protocols.stage.SpotFieldAndChirpAndBars; runs on the Stage server, so it must stay free of protocol-object references.
    i = min(floor(frame / spotPreStimPost) + 1, nSpots);
    xy = canvasSize/2 + [cx(i); cy(i)];
end
