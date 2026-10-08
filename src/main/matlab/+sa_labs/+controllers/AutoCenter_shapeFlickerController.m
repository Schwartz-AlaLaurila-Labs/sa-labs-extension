function c = AutoCenter_shapeFlickerController(state, preTime, baseLevel, startTime, endTime, shapeData_someColumns, controllerIndex)
%AUTOCENTER_SHAPEFLICKERCONTROLLER Controller helper for sa_labs.protocols.stage.AutoCenter; runs on the Stage server, so it must stay free of protocol-object references.
    % controllerIndex is to have multiple shapes simultaneously
    t = state.time - preTime * 1e-3;
    activeNow = (t > startTime & t < endTime);
    if any(activeNow)
        actives = find(activeNow);
        if controllerIndex <= length(actives)
            myActive = actives(controllerIndex);
            vals = shapeData_someColumns(myActive,:);
            % [intensity, frequency, start]
            c = vals(1) * (cos(2 * pi * (t - vals(3)) * vals(2)) > 0);
        else
            c = baseLevel;
        end
    else
        c = baseLevel;
    end
end
