function im = ObjectMotionSensitivity_imageMovementController(state, startMotionTime, imageMatrix, scale, motionPath)
%OBJECTMOTIONSENSITIVITY_IMAGEMOVEMENTCONTROLLER Controller helper for sa_labs.protocols.stage.ObjectMotionSensitivity; runs on the Stage server, so it must stay free of protocol-object references.
    % Image matrix shifted along the motion path for a frame state.
    % A package function keeps the controller closure free of the
    % protocol object (and its classdef) so it can be serialized to
    % the Stage server.
    if state.time < startMotionTime / 1000
        frame = 1;
    else
        frame = 1+round(state.frame - 60 * (startMotionTime / 1000));
    end

    im = circshift(imageMatrix, round(motionPath(frame) * scale), 2); % second dim
end
