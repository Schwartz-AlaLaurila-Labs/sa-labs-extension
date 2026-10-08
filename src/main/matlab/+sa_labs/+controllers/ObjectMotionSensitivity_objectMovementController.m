function pos = ObjectMotionSensitivity_objectMovementController(state, startMotionTime, center, angle, motionPathPixels)
%OBJECTMOTIONSENSITIVITY_OBJECTMOVEMENTCONTROLLER Controller helper for sa_labs.protocols.stage.ObjectMotionSensitivity; runs on the Stage server, so it must stay free of protocol-object references.
    % Object position along the motion path for a frame state.

    if state.time < startMotionTime / 1000
        frame = 1;
    else
        frame = 1+round(state.frame - 60 * (startMotionTime / 1000));
    end
    
    y = sind(angle) * motionPathPixels(frame);
    x = cosd(angle) * motionPathPixels(frame);
    pos = [x,y] + center;
        
end
