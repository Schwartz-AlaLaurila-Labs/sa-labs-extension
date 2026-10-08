function intensity = White_to_Pink_Temporal_Noise_noiseIntensity(frame, preFrames, stimFrames1, stimFrames2, stimNoise, spotMeanLevel)
%WHITE_TO_PINK_TEMPORAL_NOISE_NOISEINTENSITY Controller helper for sa_labs.protocols.stage.White_to_Pink_Temporal_Noise; runs on the Stage server, so it must stay free of protocol-object references.
    if frame < preFrames % **Pre-time (using noise1)**
%                 stimFrame = frame + 1;
        intensity = spotMeanLevel;

    elseif frame < (preFrames + stimFrames1) % **First stimulus segment (Beta 1)**
        stimFrame = frame - preFrames + 1;
        intensity = stimNoise(preFrames + stimFrame);

    elseif frame < (preFrames + stimFrames1 + stimFrames2) % **Second stimulus segment (Beta 2)**
        stimFrame = frame - preFrames - stimFrames1 + 1;
        intensity = stimNoise(preFrames + stimFrames1 + stimFrame);

    else % **Tail-Time (using noise1)**
%                 stimFrame = frame - (preFrames + stimFrames1 + stimFrames2) + 1;
%                 intensity = stimNoise(preFrames + stimFrames1 + stimFrames2 + stimFrame);
          intensity = spotMeanLevel;
    end

    % Ensure intensity stays within valid range
    intensity = sa_labs.controllers.White_to_Pink_Temporal_Noise_clipIntensity(intensity, spotMeanLevel);
end
