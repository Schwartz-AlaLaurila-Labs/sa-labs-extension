function c = ReceptiveField1D_stimWave(t, preTime, stimTime, conOrInt, meanLevel, freq, sineWave)
%RECEPTIVEFIELD1D_STIMWAVE Controller helper for sa_labs.protocols.stage.ReceptiveField1D; runs on the Stage server, so it must stay free of protocol-object references.
    % Bar color at presentation time t (s). A package function so the
    % controller closure (serialized to the Stage server) carries only
    % plain values and no classdef.
    if t>preTime*1e-3 && t<=(preTime+stimTime)*1e-3
        if sineWave
            timeVal = t - preTime*1e-3; %s
            %inelegant solution for zero mean
            if meanLevel < 0.05
                c = conOrInt * sin(2*pi*timeVal*freq);
                if c<0, c = 0; end %rectify
            else
                c = meanLevel + meanLevel * conOrInt * sin(2*pi*timeVal*freq);
            end

        else
            c = conOrInt;
        end
    else
        c = meanLevel;
    end
end
