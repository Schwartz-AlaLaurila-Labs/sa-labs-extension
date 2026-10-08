function c = CenterSurround_onDuringStim(state, preTime, stimTime, intensity, activePatternNumber, backgroundPatternNumber, meanLevel)
%CENTERSURROUND_ONDURINGSTIM Controller helper for sa_labs.protocols.stage.CenterSurround; runs on the Stage server, so it must stay free of protocol-object references.
    % Color of a spot on the current pattern: intensity on the active
    % pattern during the stimulus, meanLevel on the background pattern,
    % 0 otherwise. A package function (not a class method) so the
    % controller closure serializes to the Stage server without the
    % protocol object or its classdef.
    if state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3
        if state.pattern == activePatternNumber
            c = intensity;
        elseif state.pattern == backgroundPatternNumber
            c = meanLevel;
        else
            c = 0;
        end
    else
        if state.pattern == backgroundPatternNumber
            c = meanLevel;
        else
            c = 0;
        end
    end
end
