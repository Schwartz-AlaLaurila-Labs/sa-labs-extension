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
            
             function c = sineWaveStim(state, preTime, stimTime, contrast, meanLevel, freq)
                if state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3
                    timeVal = state.time - preTime*1e-3; %s
                    %inelegant solution for zero mean
                    if meanLevel < 0.05
                        c = contrast * sin(2*pi*timeVal*freq);
                        if c<0, c = 0; end %rectify
                    else
                        c = meanLevel + meanLevel * contrast * sin(2*pi*timeVal*freq);
                    end
                else
                    c = meanLevel;
                end
            end
            
            controller = stage.builtin.controllers.PropertyController(spot, 'color', @(s)sineWaveStim(s, obj.preTime, obj.stimTime, obj.contrast, obj.meanLevel, obj.curFrequency));
            p.addController(controller);

        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfFrequencySteps;
        end
        
        
    end
    
end