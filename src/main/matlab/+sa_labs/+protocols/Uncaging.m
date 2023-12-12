classdef Uncaging < sa_labs.protocols.BaseProtocol
    % Presents a set of rectangular pulse stimuli to a specified amplifier and records from the same amplifier.
    % from the rieke lab with our thanks
    
    properties
        outputAmpSelection = 1          % Output amplifier (1 or 2)
        preTime = 2000                    % Pulse leading duration (ms)
        stimTime = 10000                  % Pulse duration (ms)
        tailTime = 2000                   % Pulse trailing duration (ms)
        pulseAmplitude = 0            % Pulse amplitude (mV or pA depending on amp mode)        
        numberOfEpochs = 1;
        numberOfStimGroups = 2;         %ROI groups in ScanImage
        numberOfSequences = 5;          %repeats of each stim group
        laser_power = 20;               %percent
        laser_wavelength = 800;         %nm
        shutter_open = true;            %laser shutter
        group_names = ' ';              %free text to enter names of ROI groups, comma separated
        drug_condition = 'RubiGlutamate + synBlock'; 
    end
    
    properties (Hidden)
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = ''; %'pulseAmplitude';
        drug_conditionType = symphonyui.core.PropertyType('char', 'row', {'control', 'synBlock', 'RubiGlutamate + synBlock'})
        group_namesType = symphonyui.core.PropertyType('char', 'row')
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end    
    
    methods
                
        
%         function prepareRun(obj)
%             prepareRun@sa_labs.protocols.BaseProtocol(obj, epoch);
%             
%         end
        
        function stim = createAmpStimulus(obj, ampName)
            gen = symphonyui.builtin.stimuli.PulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.pulseAmplitude;
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

