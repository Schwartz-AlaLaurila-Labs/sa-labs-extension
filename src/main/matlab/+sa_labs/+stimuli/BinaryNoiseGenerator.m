% Generates a binary noise stimulus. Noise generated consists of periodic discrete updates -- e.g. new value chosen 
% every 2 ms -- permitting noise to be produced which looks like light output of a computer monitor (e.g. new value
% every 16 ms.

classdef BinaryNoiseGenerator < symphonyui.core.StimulusGenerator
    
    properties
        preTime     % Leading duration (ms)
        stimTime    % Noise duration (ms)
        tailTime    % Trailing duration (ms)
        segmentTime % Duration of each independent noise value (ms)
        amplitude   % Noise amplitude (units)
        mean        % Mean amplitude (units)
        seed        % Random number generator seed
        sampleRate  % Sample rate of generated stimulus (Hz)
        units       % Units of generated stimulus
    end
    
    methods
        
        function obj = BinaryNoiseGenerator(map)
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
            segmentPts = timeToPts(obj.segmentTime);
            
            % Initialize random number generator.
            stream = RandStream('mt19937ar', 'Seed', obj.seed);
            
            % Generate binary noise.
            noise = zeros(1, stimPts);
            for i = 1:segmentPts:stimPts
                if (stream.rand() > 0.5)
                    amp = obj.amplitude;
                else
                    amp = -obj.amplitude;
                end
                
                noise(i:i+segmentPts-1) = amp;
            end
            
            data = ones(1, prePts + stimPts + tailPts) * obj.mean;
            data(prePts + 1:prePts + stimPts) = noise + obj.mean;
            
            parameters = obj.dictionaryFromMap(obj.propertyMap);
            measurements = Measurement.FromArray(data, obj.units);
            rate = Measurement(obj.sampleRate, 'Hz');
            output = OutputData(measurements, rate);
            
            cobj = RenderedStimulus(class(obj), parameters, output);
            s = symphonyui.core.Stimulus(cobj);
        end
        
    end
    
end

