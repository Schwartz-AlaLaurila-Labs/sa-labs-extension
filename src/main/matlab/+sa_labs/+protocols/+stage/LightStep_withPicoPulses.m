classdef LightStep_withPicoPulses < sa_labs.protocols.StageProtocol
    
    properties
        %times in ms
        preTime = 9000% Spot leading duration (ms)
        stimTime = 500 % Spot duration (ms)
        tailTime = 5000	% Spot trailing duration (ms)
        pulse1_start = 1000;
        pulse2_start = 11000;
        pulse_dur = 500;
        
        intensity = 0.5;
        
        spotSize = 200; % um
        numberOfEpochs = 500;
        
        alternatePatterns = false % alternates spot pattern between PRIMARY and SECONDARY OBJECT PATTERNS
    end
    
    properties (Hidden)
        version = 4
        currentSpotPattern
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'currentSpotPattern';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareEpoch(obj, epoch)
             % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
            gen = symphonyui.builtin.stimuli.PulseTrainGenerator();
            gen.preTime = obj.pulse1_start;
            gen.pulseTime = obj.pulse_dur;
            gen.tailTime = obj.preTime + obj.tailTime + obj.stimTime - ...
                (obj.pulse2_start + 2*gen.pulseTime);
            gen.intervalTime = obj.pulse2_start - obj.pulse1_start;
            gen.numPulses = 2;
            gen.sampleRate = obj.sampleRate;
            gen.amplitude = 5;
            gen.mean = 0;
            gen.units = 'V';
            triggers = obj.rig.getDevices('picospritz_trigger');
            if ~isempty(triggers)
                %epoch.addStimulus(triggers{1},  gen.generate());
            else
                disp('no pico trigger device found')
            end            
            
            obj.currentSpotPattern = obj.primaryObjectPattern;
            if obj.numberOfPatterns > 1
                if obj.alternatePatterns
                    if mod(obj.numEpochsPrepared, 2) == 1
                        obj.currentSpotPattern = obj.secondaryObjectPattern;
                        currentSpotColor = obj.colorPattern2;
                    else
                        obj.currentSpotPattern = obj.primaryObjectPattern;
                        currentSpotColor = obj.colorPattern1;
                    end
                    disp(currentSpotColor)
                end
            end
            epoch.addParameter('currentSpotPattern', obj.currentSpotPattern);
           gen
           
            
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            spot.color = obj.intensity;
            spot.opacity = 1;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            obj.setOnDuringStimController(p, spot);
            
            % shared code for multi-pattern objects
            obj.setColorController(p, spot);
            
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
    end
    
end