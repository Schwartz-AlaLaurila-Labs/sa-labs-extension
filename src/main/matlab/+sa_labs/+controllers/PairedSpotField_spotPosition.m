function xy = PairedSpotField_spotPosition(frame, spot, stimFrames, spotPreStimPost, canvasSize, cx, cy)
%PAIREDSPOTFIELD_SPOTPOSITION Controller helper for sa_labs.protocols.stage.PairedSpotField; runs on the Stage server, so it must stay free of protocol-object references.
    if (frame < 0) || (frame >= stimFrames)
        xy = [0;0];
        return
    end
    i = min(floor(frame / spotPreStimPost) + 1, length(cx));
    xy = canvasSize/2 + [cx(i, spot); cy(i, spot)];
end
