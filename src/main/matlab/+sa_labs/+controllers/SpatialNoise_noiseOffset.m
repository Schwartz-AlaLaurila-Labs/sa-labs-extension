function p = SpatialNoise_noiseOffset(frame, pattern, canvasSize, frameDwell, ppm, pFactor, ss, offsetStream)
%SPATIALNOISE_NOISEOFFSET Controller helper for sa_labs.protocols.stage.SpatialNoise; runs on the Stage server, so it must stay free of protocol-object references.
    persistent position;
    if frame<0 %pre frames. frame 0 starts stimPts
        position = canvasSize/2;
    elseif pattern == 0 %only want to move once per update?
        if mod(frame, frameDwell) == 0 %noise update
            % position = canvasSize/2 + ppm*...
            %     (obj.offsetDelta * obj.offsetStream.randi(2*obj.maxOffset/obj.offsetDelta,1,2) - obj.maxOffset);

            position = canvasSize/2 + ppm.*pFactor.*[offsetStream.randi(2*ss(1) - 1) - ss(1), offsetStream.randi(2*ss(2) - 1) - ss(2)];
        end
    end
    p = position;
end
