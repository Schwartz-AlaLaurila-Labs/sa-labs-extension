classdef Chirp < sa_labs.protocols.StageProtocol

    properties
        preTime = 2000; % ms
        tailTime = 2000; % ms
        numberOfEpochs = 10;
        
        %times in ms
        interTime = 2000; % ms, time before, between, or after stimuli in sec
        ONstepTime = 3000; % ms, time of the step stimulus
        OFFstepTime = 3000;
        %        
        spotSize = 200; % um
        intensity = 1; % only used if mean = 0
        
        % chirp params
        freqTotalTime = 8000; % msec of frequency modulation
        freqMin = 0; % minimum frequency
        freqMax = 8; % maximum frequency
        contrastTotalTime = 8000; % msec of contrast modulation
        contrastFreq = 2;
        contrastMin = 0; % minimum contrast
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
            
            if obj.meanLevel > 0
                contrastBaseline = obj.meanLevel;
            elseif obj.meanLevel == 0
                warning('mean level = 0, contrast will be determined by spot intensity');
                if obj.intensity == 0
                    error('intensity must be greater than 0 when mean = 0')
                else
                    contrastBaseline = obj.intensity;
                end
            end
            

            if obj.contrastMax > 1
                error('cannot use max contrast greater than 1')
            elseif contrastBaseline+obj.contrastMax/2 > 1
                error('mean/intensity + (max contrast/2) must be less than 1')
            elseif obj.contrastMax < 0 || obj.contrastMax > 1
                error('max contrast must be in the range of 0-1')
            end
            
            dt = 1/obj.frameRate; % assume frame rate in Hz
            
            % *0.001 is to make in terms of seconds
            prePattern = ones(1, round(obj.preTime*0.001*obj.frameRate))*obj.meanLevel;
            interPattern = ones(1, round(obj.interTime*0.001*obj.frameRate))*contrastBaseline;
            tailPattern = ones(1, round(obj.tailTime*0.001*obj.frameRate))*obj.meanLevel;
            posStepPattern = ones(1, round(obj.ONstepTime*0.001*obj.frameRate))*(contrastBaseline+(contrastBaseline*obj.contrastMax));
            negStepPattern = ones(1, round(obj.OFFstepTime*0.001*obj.frameRate))*(contrastBaseline-(contrastBaseline*obj.contrastMax));
            
            freqT = 0:dt:obj.freqTotalTime*0.001;
            freqChange = linspace(obj.freqMin, obj.freqMax, length(freqT));
            freqPhase = cumsum(freqChange*dt);
            freqPattern = obj.contrastMax*contrastBaseline*-sin(2*pi*freqPhase + pi) + contrastBaseline;
            
            contrastT = 0:dt:obj.contrastTotalTime*0.001;
            contrastChange = linspace(obj.contrastMin, obj.contrastMax, length(contrastT));
            contrastPattern = contrastChange.*contrastBaseline.*-sin(2*pi*obj.contrastFreq.*contrastT + pi) + contrastBaseline;

            obj.chirpPattern = [prePattern, posStepPattern, negStepPattern, interPattern...
                freqPattern, interPattern, contrastPattern, interPattern, tailPattern];
%         figure
%         plot(linspace(0,dt*length(obj.chirpPattern),length(obj.chirpPattern)), obj.chirpPattern)
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
            stimTime = obj.interTime*3 + obj.ONstepTime + obj.OFFstepTime + obj.freqTotalTime + obj.contrastTotalTime;
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
    end
    
end