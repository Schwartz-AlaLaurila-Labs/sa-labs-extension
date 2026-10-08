function c = AutoCenter_shapeController(state, preTime, baseLevel, startTime, endTime, shapeData_someColumns, controllerIndex)
%AUTOCENTER_SHAPECONTROLLER Controller helper for sa_labs.protocols.stage.AutoCenter; runs on the Stage server, so it must stay free of protocol-object references.
    % controllerIndex is to have multiple shapes simultaneously
    t = state.time - preTime * 1e-3;
    activeNow = (t > startTime & t < endTime);
    if any(activeNow)
        actives = find(activeNow);
        if controllerIndex <= length(actives)
            c = shapeData_someColumns(actives(controllerIndex),:);
        else
            c = baseLevel;
        end
    else
        c = baseLevel;
    end
end
