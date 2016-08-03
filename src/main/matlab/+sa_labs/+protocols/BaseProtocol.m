classdef (Abstract) BaseProtocol < symphonyui.core.Protocol
% this class handles protocol control which is not visual stimulus specific

    properties
        chan1 = 'Amp1';
        chan1Mode = 'Cell attached'
        chan2 = 'None';   
        chan2Mode = 'Cell attached'
        chan3  = 'None';  
        chan3Mode = 'Cell attached'
        chan4  = 'None';  
        chan4Mode = 'Cell attached'
    end

    properties (Dependent, SetAccess = private)

        ndfs    % Selected ndfs. To change ndf press ctrl+D and change for given LED
    end
    
    properties(Hidden)

        chan1Type
        chan2Type
        chan3Type
        chan4Type
        chan1ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell'});
        chan2ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell','Off'});
        chan3ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell','Off'});
        chan4ModeType = symphonyui.core.PropertyType('char', 'row', {'Cell attached','Whole cell','Off'});
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@symphonyui.core.Protocol(obj);
            
            ampList = horzcat({'None'}, obj.rig.getDeviceNames('Amp'));
            
            obj.chan1Type = symphonyui.core.PropertyType('char', 'row', ampList(2:end)); % first channel should always be filled
            obj.chan2Type = symphonyui.core.PropertyType('char', 'row', ampList);
            obj.chan3Type = symphonyui.core.PropertyType('char', 'row', ampList);
            obj.chan4Type = symphonyui.core.PropertyType('char', 'row', ampList);
        end

        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@symphonyui.core.Protocol(obj, name);

%             if ismember(name, obj.chanList) && isempty(obj.getSecondaryAmp(name))
%                 d.isHidden = true;
%             end
%             
%             if strncmp(name, 'ndfs', 4) && isempty(obj.ndfs)
%                 d.isHidden = true;
%             end            
            
            switch name
                case {'numberOfCycles','numberOfEpochs','ndfs'}
                    d.category = '1 Basic';
                case {'stimTime','preTime','tailTime'}
                    d.category = '2 Timing';
                case {'chan1','chan2','chan3','chan4','chan1Mode','chan2Mode','chan3Mode','chan4Mode','sampleRate'}
                    d.category = '9 Amplifiers';
                otherwise
                    d.category = '4 Other';
            end
        end 
        
        
        function prepareRun(obj)
            prepareRun@symphonyui.core.Protocol(obj);
%             obj.showFigure('symphonyui.builtin.figures.ResponseFigure', obj.rig.getDevice(obj.chan));
%             obj.showFigure('symphonyui.builtin.figures.MeanResponseFigure', obj.rig.getDevice(obj.chan));
        end
        
        function prepareEpoch(obj, epoch)
            prepareEpoch@symphonyui.core.Protocol(obj, epoch);           
            
            amps = obj.rig.getDevices('Amp');
            for ai = 1:length(amps)
                epoch.addResponse(amps{ai});
            end
            
            obj.addGaussianLoopbackSignals(epoch);

            controllers = obj.rig.getDevices('Temperature Controller');
            if ~isempty(controllers)
                epoch.addResponse(controllers{1});
            end
            
        end
        
        function addGaussianLoopbackSignals(obj, epoch)
            % make fake input data via loopback
            for ci = 1:4
                if strcmp(obj.(['chan' num2str(ci)]), 'None')
                   continue
                end
                device = obj.rig.getDevice(obj.(['chan' num2str(ci)]));
                g = sa_labs.stimuli.GaussianNoiseGeneratorV2();
                g.freqCutoff = 100;
                g.numFilters = 1;
                g.stDev = .2;
                g.mean = rand() * 10;
                g.seed = randi(100000);
                g.preTime = obj.preTime;
                g.tailTime = obj.tailTime;
                g.stimTime = obj.stimTime;
                measurement = device.background;
                g.units = measurement.displayUnits;
                g.sampleRate = obj.sampleRate;
                epoch.addStimulus(device, g.generate());
            end

        end
            
        
        function completeEpoch(obj, epoch)
            completeEpoch@symphonyui.core.Protocol(obj, epoch);
            
            controllers = obj.rig.getDevices('Temperature Controller');
            if ~isempty(controllers) && epoch.hasResponse(controllers{1})
                response = epoch.getResponse(controllers{1});
                [quantities, units] = response.getData();
                if ~strcmp(units, 'V')
                    error('Temperature Controller must be in volts');
                end
                
                % Temperature readout from Warner TC-324B controller 100 mV/degree C.
                temperature = mean(quantities) * 1000 * (1/100);
                temperature = round(temperature * 10) / 10;
                epoch.addParameter('bathTemperature', temperature);
                
                epoch.removeResponse(controllers{1});
            end
        end
        
        function ndfs = get.ndfs(obj)
            ndfs = obj.getSelectedNdfs();
        end
        
        % default configuration for led device.
        % Can be overridden, if stage is configured for netural density filter
        function ndfs = getSelectedNdfs(obj)
            ndfs = [];
            if ~ isprop(obj, 'led')
                return;
            end
            ledDevice = obj.rig.getDevice(obj.led);
            ndfs = ledDevice.getConfigurationSetting('ndfs');
        end
    end
    
end

