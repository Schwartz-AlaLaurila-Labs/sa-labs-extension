classdef Chirp < sa_labs.protocols.StageProtocol

    properties
        preTime = 0;
        tailTime = 0;
        numberOfEpochs = 10;
        
        %times in ms
        interTime = 1; % s, time before, between, or after stimuli in sec
        stepTime = 0.5; % s, time of the step stimulus
        
        %
        %meanLevel = 0.35; % mean light level        
        spotSize = 200; % um
        intensity = 0; % this doesn't do anything
        
        % chirp params
        freqTotalTime = 10; % 10 sec of frequency modulation
        freqMin = 0.5; % minimum frequency
        freqMax = 20; % maximum frequency
        contrastTotalTime = 10; % 10 sec of contrast modulation
        contrastFreq = 2;
        contrastMin = 0.02; % minimum contrast
        contrastMax = 1; % maximum contrast
    end
    
    properties (Hidden)
        version = 4;
        contrastPattern = [];
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = '';
    end
    
    properties (Dependent) 
        stimTime
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            if obj.meanLevel == 0
                warning('Mean Level must be greater than 0 for this to work');
            end
            
            dt = 1/obj.frameRate;
            
            interPattern = ones(1, ceil(obj.interTime*obj.frameRate))*obj.meanLevel;
            posStepPattern = ones(1, ceil(obj.stepTime*obj.frameRate))*(obj.meanLevel+obj.meanLevel);
            negStepPattern = ones(1, ceil(obj.stepTime*obj.frameRate))*(obj.meanLevel-obj.meanLevel);
            
            freqT = 0:dt:obj.freqTotalTime;
            freqChange = linspace(obj.freqMin, obj.freqMax, length(freqT));
            freqPhase = cumsum(freqChange/obj.FS);
            freqPattern = obj.meanLevel*-sin(2*pi*freqPhase + pi) + obj.meanLevel;
            
            contrastT = 0:dt:obj.contrastTotalTime;
            contrastChange = linspace(obj.contrastMin, obj.contrastMax, length(contrastT));
            contrastPattern = contrastChange.*obj.meanLevel.*-sin(2*pi*obj.contrastFreq.*contrastT + pi) + obj.meanLevel;
            
            obj.chirpPattern = [interPattern, posStepPattern, interPattern, negStepPattern, interPattern...
                freqPattern, interPattern, contrastPattern, interPattern];
            
            prepareRun@sa_labs.protocols.StageProtocol(obj);
        end
        
        function prepareEpoch(obj, epoch)
           
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation(obj.stimTime);
            
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
            
            spotIntensity = stage.builtin.controllers.PropertyController(spot, 'color',...
                @(state)getSpotIntensity(obj, state.frame));
            p.addController(spotIntensity);
            
        end
        
        function i = getIntensityFromPattern(obj, state)
            if state.frame<0 %pre frames. frame 0 starts stimPts
                frame = 1;
            else
                frame = state.frame;
            end

            i = obj.chirpPattern(frame);
        end
        
        function stimTime = get.stimTime(obj)
            stimTime = obj.interTime*5 + obj.stepTime*2 + obj.freqTotalTime + obj.contrastTotalTime;
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
    end
    
end