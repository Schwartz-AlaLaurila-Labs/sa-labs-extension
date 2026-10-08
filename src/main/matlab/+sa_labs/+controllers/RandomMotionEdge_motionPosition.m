function pos = RandomMotionEdge_motionPosition(frame, angle, center, motionPath, edgeOffset)
%RANDOMMOTIONEDGE_MOTIONPOSITION Controller helper for sa_labs.protocols.stage.RandomMotionEdge; runs on the Stage server, so it must stay free of protocol-object references.
    % Bar position at a presentation frame along the random motion
    % path. A package function so the controller closure (serialized
    % to the Stage server) carries only plain values and no classdef.
    if frame < 1
        frame = 1;
    end
    if size(motionPath,2) == 1
        y = sind(angle) * (motionPath(frame) + edgeOffset);
        x = cosd(angle) * (motionPath(frame) + edgeOffset);
    else
        y = sind(angle) * motionPath(frame, 1);
        x = cosd(angle) * motionPath(frame, 2);
    end
    pos = [x,y] + center;
end
