classdef Ramp < sa_labs.protocols.BaseProtocol
    % Presents current (or voltage) ramps to a specified amplifier and records from the same amplifier.
    % rampSlope may be a vector of slopes; each repeat presents every slope once, in
    % pseudorandom order when randomOrdering is set (as in SpotsMultiSize).
    % from the rieke lab with our thanks

    properties
        outputAmpSelection = 1          % Output amplifier (1 or 2)
        preTime = 500                    % Pulse leading duration (ms)
        stimTime = 6000                  % Pulse duration (ms)
        tailTime = 6000                  % Pulse trailing duration (ms)
        rampSlope = 50                   % Ramp slope(s) (pA/sec or mV/sec); a vector presents each slope once per repeat
        numberOfRepeats = 5              % Number of times each slope is presented
        randomOrdering = true            % Present the slopes in pseudorandom order within each repeat
    end

    properties (Hidden)
        version = 2                      % v1: single slope, numberOfEpochs; v2: slope vector, numberOfRepeats, randomOrdering
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'currentRampSlope';
        slopeOrder                       % slopes in presentation order for the current repeat
        currentRampSlope
    end

    properties (Hidden, Dependent)
        totalNumEpochs
    end

    methods

        function obj = Ramp()
            obj@sa_labs.protocols.BaseProtocol();
            obj.chan1Mode = 'Whole cell';   % this protocol only; the base default is unchanged
        end

        function prepareRun(obj)
            prepareRun@sa_labs.protocols.BaseProtocol(obj);
            obj.slopeOrder = obj.rampSlope(:)';
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
            gen.amplitude = obj.currentRampSlope * obj.stimTime / 1e3;
            gen.mean = obj.rig.getDevice(ampName).background.quantity;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(ampName).background.displayUnits;

            stim = gen.generate();
        end

        function prepareEpoch(obj, epoch)
            % New pseudorandom order at the start of each repeat.
            slopes = obj.rampSlope(:)';
            index = mod(obj.numEpochsPrepared, numel(slopes)) + 1;
            if index == 1
                if obj.randomOrdering && numel(slopes) > 1
                    obj.slopeOrder = slopes(randperm(numel(slopes)));
                else
                    obj.slopeOrder = slopes;
                end
            end
            obj.currentRampSlope = obj.slopeOrder(index);
            epoch.addParameter('currentRampSlope', obj.currentRampSlope);

            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);

            outputAmpName = sprintf('amp%g', obj.outputAmpSelection);
            epoch.addStimulus(obj.rig.getDevice(outputAmpName), obj.createAmpStimulus(outputAmpName));
        end

        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfRepeats * numel(obj.rampSlope);
        end

    end

end
