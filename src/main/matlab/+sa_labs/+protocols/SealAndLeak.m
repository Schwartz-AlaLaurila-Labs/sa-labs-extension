classdef SealAndLeak < sa_labs.protocols.BaseProtocol
    
    properties
        mode = 'seal'                   % Current mode of protocol
        alternateMode = true            % Alternate from seal to leak to seal etc., on each successive run
        preTime = 15                    % Pulse leading duration (ms)
        stimTime = 30                   % Pulse duration (ms)
        tailTime = 15                   % Pulse trailing duration (ms)
        pulseAmplitude = 5              % Pulse amplitude (mV or pA)
        leakAmpHoldSignal = -60         % Amplifier hold signal to use while in leak mode
        ampNumber = 1;                  % Which amplifier to use
    end
    
    properties (Hidden, Dependent)
        ampHoldSignal
    end
    
    properties (Hidden)
        modeType = symphonyui.core.PropertyType('char', 'row', {'seal', 'leak'})
        modeFigure
        responsePlotMode = false;
    end
    
    methods
        
        function s = get.ampHoldSignal(obj)
            if strcmpi(obj.mode, 'seal')
                s = 0;
            else
                s = obj.leakAmpHoldSignal;
            end
        end
        
        function didSetRig(obj)
            didSetRig@sa_labs.protocols.BaseProtocol(obj);
        end
        
        function p = getPreview(obj, panel)
            p = symphonyui.builtin.previews.StimuliPreview(panel, @()createPreviewStimuli(obj));
            function s = createPreviewStimuli(obj)
                gen = symphonyui.builtin.stimuli.PulseGenerator(obj.createAmpStimulus().parameters);
                s = gen.generate();
            end
        end
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.BaseProtocol(obj, false); % don't change the hold signal
            
            if isempty(obj.modeFigure) || ~isvalid(obj.modeFigure)
                obj.modeFigure = obj.showFigure('symphonyui.builtin.figures.CustomFigure', @null);
                f = obj.modeFigure.getFigureHandle();
                set(f, 'Name', 'Mode');
                layout = uix.VBox('Parent', f);
                uix.Empty('Parent', layout);
                obj.modeFigure.userData.text = uicontrol( ...
                    'Parent', layout, ...
                    'Style', 'text', ...
                    'FontSize', 24, ...
                    'HorizontalAlignment', 'center', ...
                    'String', '');
                uix.Empty('Parent', layout);
                set(layout, 'Height', [-1 42 -1]);
            end
            
            if isvalid(obj.modeFigure)
                set(obj.modeFigure.userData.text, 'String', [obj.mode ' running...']);
            end
        end
        
        function stim = createAmpStimulus(obj)
            gen = symphonyui.builtin.stimuli.RepeatingPulseGenerator();
            
            gen.preTime = obj.preTime;
            gen.stimTime = obj.stimTime;
            gen.tailTime = obj.tailTime;
            gen.amplitude = obj.pulseAmplitude;
            gen.mean = obj.ampHoldSignal;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice(sprintf('amp%g', obj.ampNumber)).background.displayUnits;
            
            stim = gen.generate();
        end
        
        function stim = createOscilloscopeTriggerStimulus(obj)
            gen = symphonyui.builtin.stimuli.RepeatingPulseGenerator();
            
            gen.preTime = 0;
            gen.stimTime = 1;
            gen.tailTime = obj.preTime + obj.stimTime + obj.tailTime - 1;
            gen.amplitude = 1;
            gen.mean = 0;
            gen.sampleRate = obj.sampleRate;
            gen.units = obj.rig.getDevice('Oscilloscope Trigger').background.displayUnits;
            
            stim = gen.generate();
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@sa_labs.protocols.BaseProtocol(obj, epoch);
            
            devices = obj.rig.getInputDevices();
            for i = 1:numel(devices)
                if epoch.hasResponse(devices{i})
                    epoch.removeResponse(devices{i});
                end
            end
            
            epoch.addStimulus(obj.rig.getDevice(sprintf('amp%g', obj.ampNumber)), obj.createAmpStimulus());
            
            triggers = obj.rig.getDevices('Oscilloscope Trigger');
            if ~isempty(triggers)
                epoch.addStimulus(triggers{1}, obj.createOscilloscopeTriggerStimulus());
            else
                disp('no trigger device found')
            end
            
            device = obj.rig.getDevice(sprintf('amp%g', obj.ampNumber));
            device.background = symphonyui.core.Measurement(obj.ampHoldSignal, device.background.displayUnits);
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < 1;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < 1;
        end
        
        function completeRun(obj)
            completeRun@sa_labs.protocols.BaseProtocol(obj);
            
            if obj.alternateMode
                if strcmpi(obj.mode, 'seal')
                    obj.mode = 'leak';
                else
                    obj.mode = 'seal';
                end
            end
            
            if isvalid(obj.modeFigure)
                set(obj.modeFigure.userData.text, 'String', [obj.mode ' next']);
            end
        end
        
    end
    
end

