classdef Chirp < sa_labs.protocols.StageProtocol

    properties
        preTime = 500; % ms
        tailTime = 500; % ms
        numberOfEpochs = 10;
        
        %times in ms
        interTime = 1000; % ms, time before, between, or after stimuli in sec
        stepTime = 500; % ms, time of the step stimulus
        
        %        
        spotSize = 200; % um
        intensity = 0; % this doesn't do anything
        
        % chirp params
        freqTotalTime = 10000; % msec of frequency modulation
        freqMin = 0.5; % minimum frequency
        freqMax = 20; % maximum frequency
        contrastTotalTime = 10000; % msec of contrast modulation
        contrastFreq = 2;
        contrastMin = 0.02; % minimum contrast
        contrastMax = 1; % maximum contrast
    end
    
    properties (Hidden)
        chirpPattern = [];
        
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
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if obj.meanLevel == 0
                warning('Mean Level must be greater than 0 for this to work');
            end
            
            dt = 1/obj.frameRate; % assume frame rate in Hz
            
            % *0.001 is to make in terms of seconds
            prePattern = ones(1, ceil(obj.preTime*0.001*obj.frameRate))*obj.meanLevel;
            interPattern = ones(1, ceil(obj.interTime*0.001*obj.frameRate))*obj.meanLevel;
            tailPattern = ones(1, ceil(obj.tailTime*0.001*obj.frameRate))*obj.meanLevel;
            posStepPattern = ones(1, ceil(obj.stepTime*0.001*obj.frameRate))*(obj.meanLevel+obj.meanLevel);
            negStepPattern = ones(1, ceil(obj.stepTime*0.001*obj.frameRate))*(obj.meanLevel-obj.meanLevel);
            
            freqT = 0:dt:obj.freqTotalTime*0.001;
            freqChange = linspace(obj.freqMin, obj.freqMax, length(freqT));
            freqPhase = cumsum(freqChange*dt);
            freqPattern = obj.meanLevel*-sin(2*pi*freqPhase + pi) + obj.meanLevel;
            
            contrastT = 0:dt:obj.contrastTotalTime*0.001;
            contrastChange = linspace(obj.contrastMin, obj.contrastMax, length(contrastT));
            contrastPattern = contrastChange.*obj.meanLevel.*-sin(2*pi*obj.contrastFreq.*contrastT + pi) + obj.meanLevel;
            
            obj.chirpPattern = [prePattern, posStepPattern, interPattern, negStepPattern, interPattern...
                freqPattern, interPattern, contrastPattern, tailPattern];
        end
        
        function prepareEpoch(obj, epoch)
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime)*0.001);
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            spot.color = obj.meanLevel;
            spot.opacity = 1;
            spot.position = canvasSize/2;
            p.addStimulus(spot);
            
           
            function i = getIntensityFromPattern(obj, state)
                %clip the time axis to [1, T]
                frame=max(1, min(state.frame, numel(obj.chirpPattern)));
                i = obj.chirpPattern(frame);
            end
            
            spotIntensity = stage.builtin.controllers.PropertyController(spot, 'color',...
                @(state)getIntensityFromPattern(obj, state));
            p.addController(spotIntensity);
        end
        
        function stimTime = get.stimTime(obj)
            stimTime = obj.interTime*3 + obj.stepTime*2 + obj.freqTotalTime + obj.contrastTotalTime;
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
    end
    
end