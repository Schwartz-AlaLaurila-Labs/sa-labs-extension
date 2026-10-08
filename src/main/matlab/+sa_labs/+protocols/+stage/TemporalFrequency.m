classdef TemporalFrequency < sa_labs.protocols.StageProtocol
    
    properties
        %times in ms
        preTime = 250	% Spot leading duration (ms)
        stimTime = 4000	% Spot duration (ms)
        tailTime = 250	% Spot trailing duration (ms)
        
        %mean (bg) and amplitude of pulse
        contrast = 1;
        spotSize = 200; %um
        
        %stim size in microns, use rigConfig to set microns per pixel
        minFrequency = 1
        maxFrequency = 20

        numberOfFrequencySteps = 10
        numberOfCycles = 2;
        
        waveShape = 'sine'
    end
    
    properties (Hidden)
        version = 1
        curFrequency
        frequencies
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'curFrequency';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            %set spot size vector
%             if ~obj.logScaling
%                 obj.frequencies = linspace(obj.minSize, obj.maxSize, obj.numberOfSizeSteps);
%             else
            obj.frequencies = logspace(log10(obj.minFrequency), log10(obj.maxFrequency), obj.numberOfFrequencySteps);
%             end

        end
        
        function prepareEpoch(obj, epoch)

            % Randomize sizes if this is a new set
            index = mod(obj.numEpochsPrepared - 1, obj.numberOfFrequencySteps);
            if index == 0
                obj.frequencies = obj.frequencies(randperm(obj.numberOfFrequencySteps)); 
            end
                       
            %get current position
            obj.curFrequency = obj.frequencies(index+1);
            epoch.addParameter('curFrequency', obj.curFrequency);
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
                        
        end
        
        
        function p = createPresentation(obj)
            %set bg
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);            
            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize) / 2);
            spot.radiusY = spot.radiusX;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2;
            p.addStimulus(spot);
            
            % The controller closure is serialized to the Stage server, so it
            % captures plain values only (never obj or a nested function,
            % which shares this workspace and drags obj along).
            preTime = obj.preTime;   %#ok<*PROP>
            stimTime = obj.stimTime;
            contrast = obj.contrast;
            meanLevel = obj.meanLevel;
            curFrequency = obj.curFrequency;
            controller = stage.builtin.controllers.PropertyController(spot, 'color', ...
                @(s) sa_labs.controllers.TemporalFrequency_sineWaveStim(s.time, preTime, stimTime, contrast, meanLevel, curFrequency));
            p.addController(controller);

        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfFrequencySteps;
        end


    end

end