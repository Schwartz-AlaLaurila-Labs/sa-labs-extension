function c = TemporalFrequency_sineWaveStim(t, preTime, stimTime, contrast, meanLevel, freq)
%TEMPORALFREQUENCY_SINEWAVESTIM Controller helper for sa_labs.protocols.stage.TemporalFrequency; runs on the Stage server, so it must stay free of protocol-object references.
    % Spot color at presentation time t (s). A package function so the
    % controller closure (serialized to the Stage server) carries only
    % plain values and no classdef.
    if t>preTime*1e-3 && t<=(preTime+stimTime)*1e-3
        timeVal = t - preTime*1e-3; %s
        %inelegant solution for zero mean
        if meanLevel < 0.05
            c = contrast * sin(2*pi*timeVal*freq);
            if c<0, c = 0; end %rectify
        else
            c = meanLevel + meanLevel * contrast * sin(2*pi*timeVal*freq);
        end
    else
        c = meanLevel;
    end
end
