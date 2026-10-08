function pos = linearPosition(t, stimTime, x0, y0, xStep, yStep)
%LINEARPOSITION Controller helper for sa_labs.protocols.StageProtocol (moving-bar/object protocols); runs on the Stage server, so it must stay free of protocol-object references.
    % Position of a linearly moving stage object at time t (s after
    % stimulus onset): [NaN NaN] outside [0, stimTime). Used by the
    % moving-bar/object controllers; a package function keeps the
    % controller closure free of the protocol object (and its classdef)
    % so it can be serialized to the Stage server.
    if t >= 0 && t < stimTime
        pos = [x0 + t * xStep, y0 + t * yStep];
    else
        pos = [NaN, NaN];
    end
end
