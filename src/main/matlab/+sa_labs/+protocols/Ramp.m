classdef Ramp < sa_labs.protocols.BaseProtocol
    % Presents a set of rectangular pulse stimuli to a specified amplifier and records from the same amplifier.
    % from the rieke lab with our thanks
    
    properties
        outputAmpSelection = 1          % Output amplifier (1 or 2)
        preTime = 500                    % Pulse leading duration (ms)
        stimTime = 6000                  % Pulse duration (ms)
        tailTime = 500                   % Pulse trailing duration (ms)
        rampSlope = 50 %pA/sec
        numberOfEpochs = 5;
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = ''; %'pulseAmplitude';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end    
    
    methods
                
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.BaseProtocol(obj);
            obj.responseFigure = obj.showFigure('sa_labs.figures.RampFigure', obj.devices, ...
                    'totalNumEpochs',obj.totalNumEpochs,...
                    'analysisRegion', 1e-3 * [obj.preTime, obj.preTime + obj.stimTime],...
                    'responseMode',obj.chan1Mode,... % TODO: different modes for multiple amps
                    'spikeThreshold', obj.spikeThreshold, ...
                    'spikeDetectorMode', obj.spikeDetectorMode,...
                    'slope', obj.rampSlope);
        end
        
        function stim = createAmpStimulus(obj, ampName)
            gen = symphonyui.builtin.stimuli.RampGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.rampSlope * obj.stimTime / 1e3;%obj.pulseAmplitude;
            gen.mean = obj.rig.getDevice(ampName).background.quantity;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(ampName).background.displayUnits;
            
            stim = gen.generate();
        end
                
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
%             shutterDevice = obj.rig.getDevice('ScanImageShutter');
%             epoch.addResponse(shutterDevice);
            
            outputAmpName = sprintf('amp%g', obj.outputAmpSelection);
            epoch.addStimulus(obj.rig.getDevice(outputAmpName), obj.createAmpStimulus(outputAmpName));
        end
        
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end        

        
    end
    
end

