classdef DynamicClampConductanceScalingSpikeRate < sa_labs.protocols.BaseProtocol
% copied from:
    %https://github.com/Rieke-Lab/baudin-package/blob/master/%2Bedu/%2Bwashington/%2Briekelab/%2Bbaudin/%2Bprotocols/DynamicClampConductanceScalingSpikeRate.m

    properties
        numberOfAverages = uint16(5); % how many times to run each pair of traces
        
        preTime = 25; % samples, prior to loaded conductance trace
        tailTime = 25; % samples, after loaded conductance trace
        
        gExcMultiplier = 1;
        gInhMultiplier = 1;
        
        ExcConductancesFile = 'testRig0';
        InhConductancesFile = 'testRig0';
        
        ExcReversal = 10;
        InhReversal = -70;
        
        nSPerVolt = 30;
        
        amp = 1;
    end
    
    properties (Hidden)
        conductancesFolderName = 'C:\Users\Greg\Documents\DynamicClampConductances\';
        excConductanceData
        inhConductanceData
        stimTime
        
        totalNumEpochs
        numberOfTraces % number of traces (rows) in the conductance matrices
        epochOrdering % random ordering of the conductance traces
        
        ampType
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = '';
    end
    
    
    methods
        function loadConductanceData(obj)
            % load in data and check that they are the same size
            obj.excConductanceData = load([obj.conductancesFolderName obj.ExcConductancesFile '.mat']);
            obj.inhConductanceData = load([obj.conductancesFolderName obj.InhConductancesFile '.mat']);
            
            if size(obj.excConductanceData.conductances) ~= size(obj.inhConductanceData.conductances)
                warning('Conductance matrices are not the same size')
            else
                % number of traces = number of rows
                obj.numberOfTraces = size(obj.excConductanceData.conductances, 1);
                obj.totalNumEpochs = obj.numberOfAverages*obj.numberOfTraces;
            end
        end
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.BaseProtocol(obj, true);
            
            % load the conductances
            obj.loadConductanceData();
            obj.stimTime = getStimTime(obj);
            obj.epochOrdering = randperm(obj.numberOfTraces);
        end
        
        
        function stim = createConductanceStimulus(obj, conductance, type)
            % conductanceType is string: 'exc' or 'inh'
            gen = symphonyui.builtin.stimuli.WaveformGenerator();
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            
            preTimeTrace = zeros(1, obj.preTime*10);
            tailTimeTrace = zeros(1, obj.tailTime*10);
            
            if strcmp(type, 'exc')
                newConductanceTrace = obj.gExcMultiplier .* conductance; %nS
            elseif strcmp(type, 'inh')
                newConductanceTrace = obj.gInhMultiplier .* conductance; %nS
            else
                warning('Type is non-existant to createConductanceStimulus')
            end
            newConductanceTrace = [preTimeTrace, newConductanceTrace, tailTimeTrace];
            
            %map conductance (nS) to DAC output (V) to match expectation of
            %Arduino...
            % oftem, 200 nS = 10 V, 1 nS = 0.05 V
            mappedConductanceTrace = obj.nSToVolts(newConductanceTrace);
            
            if any(mappedConductanceTrace > 10)
                mappedConductanceTrace = zeros(1,length(mappedConductanceTrace)); %#ok<PREALL>
                error(['G_',conductance, ': voltage command out of range!'])
            end
            
            gen.waveshape = mappedConductanceTrace;
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            'preparing run'
            
            % run through different sets of epochs
            index = mod(obj.numEpochsPrepared, obj.numberOfTraces);
            if index == 0
                obj.epochOrdering = randperm(obj.numberOfTraces);
            end
            traceInd = obj.epochOrdering(index + 1);
            
            %%% make ttl pulse length of conductance stimulus
            p = symphonyui.builtin.stimuli.PulseGenerator();
            p.preTime = obj.preTime;
            p.stimTime = obj.stimTime; 
            p.tailTime = obj.tailTime;
            p.amplitude = 1;
            p.mean = 0;
            p.sampleRate = obj.sampleRate;
            p.units = Symphony.Core.Measurement.UNITLESS;
            triggers = obj.rig.getDevices('Dynamic Trigger');
            if ~isempty(triggers)
                epoch.addStimulus(triggers{1},  p.generate());
            else
                disp('No dynamic clamp trigger device found.')
            end
            
            excConductance = obj.excConductanceData.conductances(traceInd, :);
            inhConductance = obj.inhConductanceData.conductances(traceInd, :);
                   
            epoch.addStimulus(obj.rig.getDevice('Excitatory conductance'), ...
                obj.createConductanceStimulus(excConductance, 'exc'));
            epoch.addStimulus(obj.rig.getDevice('Inhibitory conductance'), ...
                obj.createConductanceStimulus(inhConductance, 'inh'));
            
            epoch.addParameter('excitatoryConductance', excConductance);
            epoch.addParameter('inhibitoryConductance', inhConductance);
        end
        
        
        function stimTime = getStimTime(obj)
            stimTime = 0;
            excStimTime = obj.excConductanceData.preCondTime + obj.excConductanceData.stimCondTime + obj.excConductanceData.tailCondTime;
            inhStimTime = obj.inhConductanceData.preCondTime + obj.inhConductanceData.stimCondTime + obj.inhConductanceData.tailCondTime;
            if excStimTime ~= inhStimTime
                warning('Excitatory and Inhibitory conductances are not the same length')
            else 
                stimTime = excStimTime; 
            end
        end
        
        function volts = nSToVolts(obj, nS)
            volts = nS / obj.nSPerVolt;
        end
        
    end
end