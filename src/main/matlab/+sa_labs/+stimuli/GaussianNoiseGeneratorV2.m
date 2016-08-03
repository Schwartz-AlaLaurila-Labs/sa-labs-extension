% FILE FROM: riekelab-package

classdef GaussianNoiseGeneratorV2 < symphonyui.core.StimulusGenerator
    % Generates a gaussian noise stimulus. This is version 2 of GaussianNoiseGenerator. Version 1 does not apply 
    % multiple filter poles correctly or scale the post-smoothed noise correctly.
    
    properties
        preTime             % Leading duration (ms)
        stimTime            % Noise duration (ms)
        tailTime            % Trailing duration (ms)
        stDev               % Noise standard deviation, post-smoothing (units)
        freqCutoff          % Noise frequency cutoff for smoothing (Hz)
        numFilters = 0      % Number of filters in cascade for smoothing
        mean                % Mean amplitude (units)
        seed                % Random number generator seed
        inverted = false    % Invert noise polarity about the mean (true/false)
        upperLimit = inf    % Upper bound on signal, signal is clipped to this value (units)
        lowerLimit = -inf   % Lower bound on signal, signal is clipped to this value (units)
        sampleRate          % Sample rate of generated stimulus (Hz)
        units               % Units of generated stimulus
    end
    
    methods
        
        function obj = GaussianNoiseGeneratorV2(map)
            if nargin < 1
                map = containers.Map();
            end
            obj@symphonyui.core.StimulusGenerator(map);
        end
        
    end
    
    methods (Access = protected)
        
        function s = generateStimulus(obj)
            import Symphony.Core.*;
            
            timeToPts = @(t)(round(t / 1e3 * obj.sampleRate));
            
            prePts = timeToPts(obj.preTime);
            stimPts = timeToPts(obj.stimTime);
            tailPts = timeToPts(obj.tailTime);
            
            % Initialize random number generator.
            stream = RandStream('mt19937ar', 'Seed', obj.seed);
            
            % Create gaussian noise.
            noiseTime = obj.stDev * stream.randn(1, stimPts);
            
            % To frequency domain.
            noiseFreq = fft(noiseTime);
            
            % The filter will change based on whether or not there are an even or odd number of points.
            freqStep = obj.sampleRate / stimPts;
            if mod(stimPts, 2) == 0
                % Construct the filter.
                frequencies = (0:stimPts / 2) * freqStep;
                oneSidedFilter = 1 ./ (1 + (frequencies / obj.freqCutoff) .^ (2 * obj.numFilters));
                filter = [oneSidedFilter fliplr(oneSidedFilter(2:end - 1))];
            else
                % Construct the filter.
                frequencies = (0:(stimPts - 1) / 2) * freqStep;
                oneSidedFilter = 1 ./ (1 + (frequencies / obj.freqCutoff) .^ (2 * obj.numFilters));
                filter = [oneSidedFilter fliplr(oneSidedFilter(2:end))];
            end
            
            % Figure out factor by which filter will alter st dev - in the frequency domain, values should be 
            % proportional to standard deviation of each independent sinusoidal component, but it is the variances of 
            % these sinusoidal components that add to give the final variance, therefore, one needs to consider how the 
            % filter values will affect the variances; note that the first value of the filter is omitted, because the 
            % first value of the fft is the mean, and therefore shouldn't contribute to the variance/standard deviation
            % in the time domain.
            filterFactor = sqrt(filter(2:end) * filter(2:end)' / (stimPts - 1));
            
            % Filter in freq domain.
            noiseFreq = noiseFreq .* filter;
            
            % Set first value of fft (i.e., mean in time domain) to 0.
            noiseFreq(1) = 0;
            
            % Go back to time domain.
            noiseTime = ifft(noiseFreq);
            
            % FilterFactor should represent how much the filter is expected to affect the standard deviation in the time 
            % domain, use it to rescale the noise.
            noiseTime = noiseTime / filterFactor;
            
            noiseTime = real(noiseTime);
            
            % Flip if specified.
            if obj.inverted
                noiseTime = -noiseTime;
            end
            
            data = ones(1, prePts + stimPts + tailPts) * obj.mean;
            data(prePts + 1:prePts + stimPts) = noiseTime + obj.mean;
            
            % Clip signal to upper and lower limit.
            % NOTE: IF THERE ARE POINTS THAT ARE ACTUALLY OUT OF BOUNDS, THIS WILL MAKE IT SO THAT THE EXPECTATION OF 
            % THE STANDARD DEVIATION IS NO LONGER WHAT WAS SPECIFIED...
            data(data > obj.upperLimit) = obj.upperLimit;
            data(data < obj.lowerLimit) = obj.lowerLimit;
            
            parameters = obj.dictionaryFromMap(obj.propertyMap);
            measurements = Measurement.FromArray(data, obj.units);
            rate = Measurement(obj.sampleRate, 'Hz');
            output = OutputData(measurements, rate);
            
            cobj = RenderedStimulus(class(obj), parameters, output);
            s = symphonyui.core.Stimulus(cobj);
        end
        
    end
    
end

