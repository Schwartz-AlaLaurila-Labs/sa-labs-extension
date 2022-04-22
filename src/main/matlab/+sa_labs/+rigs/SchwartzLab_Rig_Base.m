classdef SchwartzLab_Rig_Base < symphonyui.core.descriptions.RigDescription
    properties
        daqStreams = containers.Map();
    end
    
    properties (Access=protected)
        lcr = @LightCrafter4500;
    end
    
    methods
        
        function initializeRig(obj)
            
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            if obj.testMode
                if strcmpi(obj.daq_type, 'Heka')
                    daq = HekaSimulationDaqController();
                elseif strcmpi(obj.daq_type, 'NI')
                    daq = NiSimulationDaqController();
                else
                    error('Could not identify Daq type from RigConfig')
                end
            else
                if strcmpi(obj.daq_type, 'Heka')
                    daq = HekaDaqController(HekaDeviceType.USB18);
                elseif strcmpi(obj.daq_type, 'NI')
                    daq = NiDaqController();
                else
                    error('Could not identify Daq type from RigConfig')
                end
            end
            
            obj.daqController = daq;
            
            for i = 1:obj.numberOfAmplifiers
                amp = MultiClampDevice(sprintf('Amp%g', i), i).bindStream(daq.getStream(sprintf('ao%g', i-1))).bindStream(daq.getStream(sprintf('ai%g', i-1)));
                obj.addDevice(amp);
            end
            
            propertyDevice = sa_labs.devices.RigPropertyDevice(obj.rigName, obj.testMode);
            obj.addDevice(propertyDevice);
            
            
            if ~obj.testMode
                names = obj.daqStreams.keys;
                for ii = 1:obj.daqStreams.length
                    dS = obj.daqStreams(names{ii});
                    port = dS{1};
                    bit = dS{2};
                    unit = dS{3};

                    if ~unit
                        unit = symphonyui.core.Measurement.UNITLESS;
                    end
                    
                    if length(dS)>3
                        Stream = CalibratedDevice(names{ii}, unit, dS{4}, dS{5}).bindStream(daq.getStream(port));
                    else
                        Stream = UnitConvertingDevice(names{ii}, unit).bindStream(daq.getStream(port));
                    end
                    
                    if bit ~= -1
                        daq.getStream(port).setBitPosition(Stream, bit); %Set bit depth for Digital signal
                    end                
                    obj.addDevice(Stream);
                end
            end
            
            Symphony.Core.Converters.Register('V','degC', Symphony.Core.ConvertProcs.Scale(10,'degC')); %for the bath controller
            
            neutralDensityFilterWheel = sa_labs.devices.NeutralDensityFilterWheelDevice(obj.filterWheelComPort);
            neutralDensityFilterWheel.setConfigurationSetting('filterWheelNdfValues', obj.filterWheelNdfValues);
            neutralDensityFilterWheel.addResource('filterWheelAttenuationValues_Blue', obj.filterWheelAttenuationValues_Blue);
            neutralDensityFilterWheel.addResource('filterWheelAttenuationValues_Green', obj.filterWheelAttenuationValues_Green);
            neutralDensityFilterWheel.addResource('filterWheelAttenuationValues_UV', obj.filterWheelAttenuationValues_UV);
            neutralDensityFilterWheel.addResource('defaultNdfValue', obj.filterWheelDefaultValue);
            obj.addDevice(neutralDensityFilterWheel);
            
            lightCrafter = sa_labs.devices.LightCrafterDevice(obj, obj.lcr);
            obj.addDevice(lightCrafter);

            if isprop(obj,'video_path')
                fname = sprintf('%s/%s.h264', obj.video_path, datestr(datetime(),'YYYYmmDD_HHMMSS'))
                camera = RigCamera.RigCamera(fname);
                obj.addDevice(camera);
            end
            if isprop(obj,'blankingCircuitComPort')
                blankingCircuit = sa_labs.devices.BlankingCircuit(obj.blankingCircuitComPort);
            else
                blankingCircuit = sa_labs.devices.MockBlankingCircuit();
            end
            obj.addDevice(blankingCircuit);
        end
    end
end

