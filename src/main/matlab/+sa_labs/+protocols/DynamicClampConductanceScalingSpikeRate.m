classdef DynamicClampConductanceScalingSpikeRate < sa_labs.protocols.BaseProtocol
% copied from:
    %https://github.com/Rieke-Lab/baudin-package/blob/master/%2Bedu/%2Bwashington/%2Briekelab/%2Bbaudin/%2Bprotocols/DynamicClampConductanceScalingSpikeRate.m

    properties
        preTime = 25; % samples, prior to conductance trace
        tailTime = 25; % samples, after conductance trace
        gExcMultiplier = 1;
        gInhMultiplier = 1;
        
        ExcConductancesFile = 'testRig';
        InhConductancesFile = 'testRig';
        
        ExcReversal = 10;
        InhReversal = -70;
        
        nSPerVolt = 20;
        
        epochToUse = 1;
        
        amp
        numberOfAverages = uint16(5)
        interpulseInterval = 0.2
    end
    
    properties (Hidden)
        conductancesFolderName = 'C:\Users\Greg\Documents\DynamicClampConductances\';
        excConductanceData
        inhConductanceData
        stimTime
        
        ampType
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = '';
    end
    
    
    methods
        function loadConductanceData(obj)
            obj.excConductanceData = load([obj.conductancesFolderName obj.ExcConductancesFile '.mat']);
            obj.inhConductanceData = load([obj.conductancesFolderName obj.InhConductancesFile '.mat']);
        end
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.BaseProtocol(obj, true);
            
            % load the conductances
            obj.loadConductanceData();
            obj.stimTime = getStimTime(obj);
            
            DynamicTrigger = UnitConvertingDevice('Dynamic Trigger', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
            daq.getStream('doport1').setBitPosition(DynamicTrigger, 3);
            obj.addDevice(DynamicTrigger);
            
        end
        
        
        function stim = createConductanceStimulus(obj, conductance)
            % conductanceType is string: 'exc' or 'inh'
            gen = symphonyui.builtin.stimuli.WaveformGenerator();
            gen.sampleRate = obj.sampleRate;
            gen.units = 'V';
            

            newExcConductanceTrace = obj.gExcMultiplier .* conductance; %nS
            newInhConductanceTrace = obj.gInhMultiplier .* conductance; %nS
            
            
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
            
            %%% make ttl pulse
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
            
%             excConductance = obj.determineConductance();
%             
%             epoch.addStimulus(obj.rig.getDevice('Excitatory conductance'), ...
%                 obj.createConductanceStimulus('exc', excConductance));
%             epoch.addStimulus(obj.rig.getDevice('Inhibitory conductance'), ...
%                 obj.createConductanceStimulus('inh', zeros(size(excConductance))));
%             epoch.addResponse(obj.rig.getDevice(obj.amp));
%             epoch.addResponse(obj.rig.getDevice('Injected current'));
%             
%             epoch.addParameter('excitatoryConductance', excConductance);
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
        
        function conductance = determineConductance(obj)
            conductance = obj.conductanceData.conductances(obj.epochToUse, :);
        end
        
        function volts = nSToVolts(obj, nS)
            volts = nS / obj.nSPerVolt;
        end
        
        function prepareInterval(obj, interval)
            prepareInterval@edu.washington.riekelab.protocols.RiekeLabProtocol(obj, interval);
            
            device = obj.rig.getDevice(obj.amp);
            interval.addDirectCurrentStimulus(device, device.background, obj.interpulseInterval, obj.sampleRate);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfAverages;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfAverages;
        end
    end
end