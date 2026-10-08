function o = NaturalMovingObjectAndFlash_opacityController(state, nFrames, mo_, preFrames, stimFrames)
%NATURALMOVINGOBJECTANDFLASH_OPACITYCONTROLLER Controller helper for sa_labs.protocols.stage.NaturalMovingObjectAndFlash; runs on the Stage server, so it must stay free of protocol-object references.
    % Spot opacity for a frame state: on until nFrames, and in flash
    % mode (mo_ == 2) only during the stim frames. A package function
    % keeps the controller closure free of the protocol object (and its
    % classdef) so it can be serialized to the Stage server.
    o = 1.0* ((state.frame + 1) < nFrames);
    
    if (mo_ == 2) 
        if (state.frame+1) <= preFrames
            o = 0;
        end
        if (state.frame+1) > preFrames+stimFrames
            o = 0;
        end
    end
end
