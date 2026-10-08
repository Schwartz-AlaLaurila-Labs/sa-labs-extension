function pos = DriftingTexture_movementController(state, stimTime, preTime, movementDelay, pixelSpeed, angle, center, randomMotion, motionPath, movementSensitivity, sensitivityStep)
%DRIFTINGTEXTURE_MOVEMENTCONTROLLER Controller helper for sa_labs.protocols.stage.DriftingTexture; runs on the Stage server, so it must stay free of protocol-object references.
    % Texture position for a frame state (random motion, movement
    % sensitivity or standard drift mode). A package function keeps the
    % controller closure free of the protocol object (and its classdef)
    % so it can be serialized to the Stage server.
    t = state.time;
    duration = stimTime / 1000;
    shapeOnTime = preTime / 1000;
    startMovementTime = shapeOnTime + movementDelay/1000;
    endMovementTime = startMovementTime + stimTime/1000;
    
    if randomMotion

        % random motion
        if state.frame < 1
            frame = 1;
        else
            frame = state.frame;
        end
        if size(motionPath,2) == 1
            y = sind(angle) * pixelSpeed * motionPath(frame);
            x = cosd(angle) * pixelSpeed * motionPath(frame);
        else
            y = sind(angle) * pixelSpeed * motionPath(frame, 1);
            x = cosd(angle) * pixelSpeed * motionPath(frame, 2);
        end
        pos = [x,y] + center;
        
    elseif movementSensitivity
        disp(sensitivityStep)
        if t < shapeOnTime
            pos = [NaN, NaN];
        elseif t < startMovementTime
            pos = center;
        elseif t < endMovementTime
            x = cosd(angle) * sensitivityStep;
            y = sind(angle) * sensitivityStep;
            pos = [x,y] + center;
        else
            pos = [nan,nan];
        end
    else % standard drift mode
        if t < shapeOnTime
            pos = [NaN, NaN];
        elseif t < startMovementTime
            y = pixelSpeed * sind(angle) * (0 - duration/2);
            x = pixelSpeed * cosd(angle) * (0 - duration/2);
            pos = [x,y] + center;
            %                 else
        elseif t < endMovementTime
            timeFromStartMovement = t - startMovementTime;
            y = pixelSpeed * sind(angle) * (timeFromStartMovement - duration/2);
            x = pixelSpeed * cosd(angle) * (timeFromStartMovement - duration/2);
            pos = [x,y] + center;
        else
            pos = [NaN, NaN];
        end
    end
end
