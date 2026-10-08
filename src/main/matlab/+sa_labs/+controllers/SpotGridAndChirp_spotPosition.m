function xy = SpotGridAndChirp_spotPosition(frame, spotPreStimPost, canvasSize, cx, cy)
%SPOTGRIDANDCHIRP_SPOTPOSITION Controller helper for sa_labs.protocols.stage.SpotGridAndChirp; runs on the Stage server, so it must stay free of protocol-object references.
    i = min(floor(frame / spotPreStimPost) + 1, length(cx));
    xy = canvasSize/2 + [cx(i); cy(i)];
end
