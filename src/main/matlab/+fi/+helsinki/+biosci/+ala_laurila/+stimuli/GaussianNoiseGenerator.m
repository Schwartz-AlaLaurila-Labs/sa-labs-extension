% Generates a gaussian noise stimulus.

classdef GaussianNoiseGenerator < symphonyui.core.StimulusGenerator
    
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
        
        function obj = GaussianNoiseGenerator(map)
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
            
            % Find the number of stimulus points to the next power of 2.
            numFftPts = 2^nextpow2(stimPts);
            
            % Create gaussian noise.
            noise = obj.stDev * stream.randn(1, numFftPts);
            
            % To frequency domain.
            noise = fft(noise);
            
            % Filter noise and calculate correction so that standard deviation refers to noise post-smoothing.
            scFact = 0;
            freqStep = obj.sampleRate / numFftPts;
            for i = 0:numFftPts/2 - 1
                temp = i * freqStep / obj.freqCutoff;
                temp = 1 / (1 + temp * temp);
                temp = temp^obj.numFilters;
                
                scFact = scFact + temp;
                
                noise(i + 1) = noise(i + 1) * temp;
                noise(end - i) = noise(end - i) * temp;
            end
            
            % Back to time domain.
            noise = ifft(noise);
            if obj.inverted
                noise = -noise;
            end
            
            scFact = sqrt(numFftPts / (2 * scFact));
            
            data = ones(1, prePts + stimPts + tailPts) * obj.mean;
            data(prePts + 1:prePts + stimPts) = real(noise(1:stimPts)) * scFact + obj.mean;
            
            % Clip signal to upper and lower limit.
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

