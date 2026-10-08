function i = low_high_TemporalContrast_noiseIntensity(frame, preFrames, stimFrames, tailFrames, frameDwell, spotMeanLevel, lowContrast, highContrast, switchTime, stream)
%LOW_HIGH_TEMPORALCONTRAST_NOISEINTENSITY Controller helper for sa_labs.protocols.stage.low_high_TemporalContrast; runs on the Stage server, so it must stay free of protocol-object references.
    persistent intensity
    totalFrames = preFrames + stimFrames + tailFrames;
    % Determine contrast based on frame position
    if frame < preFrames % Pre-time
        contrast = lowContrast;

    elseif frame >= preFrames && frame < (preFrames + stimFrames) % Stims time
        relative_frame = frame - preFrames;
        blockNumber = floor((relative_frame/ (60*switchTime))); %60Hz is default frame rate. Dont like hard coding it but its not accessing obj.frameRate

        if mod(blockNumber, 2) == 0
            contrast = lowContrast;
        else
            contrast = highContrast;
        end

    else
        contrast = lowContrast; %tail time and beyond
        if frame == totalFrames - 1
            intensity = spotMeanLevel;
            i = intensity;
            return
        end
    end
    if mod(frame, frameDwell) == 0
        noise = sa_labs.util.randn(stream, 1);
        intensity = spotMeanLevel + spotMeanLevel * contrast * noise;
    end

    intensity = sa_labs.controllers.low_high_TemporalContrast_clipIntensity(intensity, spotMeanLevel);
    i= intensity;
end
