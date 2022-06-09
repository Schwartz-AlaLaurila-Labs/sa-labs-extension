classdef DynamicClampConductanceScalingSpikeRate < sa_labs.protocols.BaseProtocol
% copied from:
    %https://github.com/Rieke-Lab/baudin-package/blob/master/%2Bedu/%2Bwashington/%2Briekelab/%2Bbaudin/%2Bprotocols/DynamicClampConductanceScalingSpikeRate.m

    properties
        numberOfAverages = uint16(5); % how many times to run each pair of traces
        
        preTime = 25; % samples, prior to loaded conductance trace
        tailTime = 25; % samples, after loaded conductance trace
        stimTime = 0; % put in the length of the conductance trace
        
        gExcMultiplier = 1;
        gInhMultiplier = 1;
        
        ExcConductancesFile = 'testRigMultiple';
        InhConductancesFile = 'testRigMultiple';
        
        amp = 1;
    end
    
    properties (Hidden)
        conductancesFolderName = 'C:\Users\SchwartzLab\Documents\DynamicClampConductances\';
        excConductanceData
        inhConductanceData
        
        traceInd
        
        ExcReversal = 10;
        InhReversal = -70;
        nSPerVolt = 30;
        
        totalNumEpochs
        numberOfTraces % number of traces (rows) in the conductance matrices
        epochOrdering % random ordering of the conductance traces
        
        ampType
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'conductanceMatrixRowIndex';
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
            % load the conductances
            obj.loadConductanceData();
            obj.setStimTime();
            obj.epochOrdering = randperm(obj.numberOfTraces);
            
            prepareRun@sa_labs.protocols.BaseProtocol(obj, true);
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
            
            if max(mappedConductanceTrace) > 3.3
                error('Your conductances are too large')
            end
            
            if min(mappedConductanceTrace) < 0
                mappedConductanceTrace(mappedConductanceTrace < 0) = 0;
            end
            
            
            if any(mappedConductanceTrace > 10)
                mappedConductanceTrace = zeros(1,length(mappedConductanceTrace)); %#ok<PREALL>
                error(['G_',conductance, ': voltage command out of range!'])
            end
            
            gen.waveshape = mappedConductanceTrace;
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            % run through different sets of epochs
            index = mod(obj.numEpochsPrepared, obj.numberOfTraces);
            if index == 0
                obj.epochOrdering = randperm(obj.numberOfTraces);
            end
            obj.traceInd = obj.epochOrdering(index + 1);
            
            excConductance = obj.excConductanceData.conductances(obj.traceInd, :);
            inhConductance = obj.inhConductanceData.conductances(obj.traceInd, :);
                   
            epoch.addStimulus(obj.rig.getDevice('Excitatory conductance'), ...
                obj.createConductanceStimulus(excConductance, 'exc'));
            epoch.addStimulus(obj.rig.getDevice('Inhibitory conductance'), ...
                obj.createConductanceStimulus(inhConductance, 'inh'));
            
            epoch.addParameter('conductanceMatrixRowIndex', obj.traceInd);
            %str = ['exc ' obj.excConductanceData.labels{obj.traceInd} ' inh ' obj.inhConductanceData.labels{obj.traceInd}];
            %epoch.addParameter('trialLabel', str);
        end
        
        
        function stimTime = setStimTime(obj)
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