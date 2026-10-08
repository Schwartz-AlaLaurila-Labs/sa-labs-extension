function i = CenterSurroundNoise_noiseIntensity(frame, pattern, frameDwell, noise, meanLevels, contrasts)
%CENTERSURROUNDNOISE_NOISEINTENSITY Controller helper for sa_labs.protocols.stage.CenterSurroundNoise; runs on the Stage server, so it must stay free of protocol-object references.
    % Spot intensity at stimulus frame `frame` (frame 0 starts the
    % stimulus, negative during pre frames) on pattern `pattern`.
    % noise(r, k) is the standard-normal draw for the k-th noise update
    % (frames 0, frameDwell, 2*frameDwell, ...) on pattern r-1, drawn
    % column-major, i.e. in the order Stage evaluates the controller
    % (patterns in order within each frame). meanLevels/contrasts hold
    % one entry per row of noise. A package function (not a class
    % method) so the controller closure serializes to the Stage server
    % without the protocol object or its classdef.
    row = min(pattern + 1, size(noise, 1));
    mn = meanLevels(row);
    if frame < 0 % pre frames. frame 0 starts stimPts
        intensity = mn;
    else % in stim frames
        k = min(floor(frame / frameDwell) + 1, size(noise, 2));
        if mod(frame, frameDwell) == 0 % noise update
            intensity = mn + contrasts(row) * mn * noise(row, k);
        else
            % between updates the former nested controller held the
            % value computed by its last call, i.e. the last pattern's
            % value at the last update frame
            last = size(noise, 1);
            intensity = meanLevels(last) + contrasts(last) * meanLevels(last) * noise(last, k);
        end
    end
    i = sa_labs.controllers.CenterSurroundNoise_clipIntensity(intensity, mn);
end
