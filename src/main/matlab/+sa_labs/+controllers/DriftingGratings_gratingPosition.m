function pos = DriftingGratings_gratingPosition(t, onTime, offTime, centerPos)
%DRIFTINGGRATINGS_GRATINGPOSITION Controller helper for sa_labs.protocols.stage.DriftingGratings; runs on the Stage server, so it must stay free of protocol-object references.
    % Grating position at time t (s): off screen (NaN) during the
    % pre and tail time, centerPos otherwise. A package function keeps
    % the controller closure free of the protocol object (and its
    % classdef) so it can be serialized to the Stage server.
    if t<=onTime || t>offTime %in pre or tail time
        %off screen
        pos = [NaN, NaN];
    else
        %on screen
        pos = centerPos;
    end
end
