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
                    
                    Stream = UnitConvertingDevice(names{ii}, unit).bindStream(daq.getStream(port));
                    
                    if bit ~= -1
                        daq.getStream(port).setBitPosition(Stream, bit); %Set bit depth for Digital signal
                    end                
                    obj.addDevice(Stream);
                end
            end
            
            neutralDensityFilterWheel = sa_labs.devices.NeutralDensityFilterWheelDevice(obj.filterWheelComPort);
            neutralDensityFilterWheel.setConfigurationSetting('filterWheelNdfValues', obj.filterWheelNdfValues);
            neutralDensityFilterWheel.addResource('filterWheelAttenuationValues_Blue', obj.filterWheelAttenuationValues_Blue);
            neutralDensityFilterWheel.addResource('filterWheelAttenuationValues_Green', obj.filterWheelAttenuationValues_Green);
            neutralDensityFilterWheel.addResource('filterWheelAttenuationValues_UV', obj.filterWheelAttenuationValues_UV);
            neutralDensityFilterWheel.addResource('defaultNdfValue', obj.filterWheelDefaultValue);
            obj.addDevice(neutralDensityFilterWheel);
            
            lightCrafter = sa_labs.devices.LightCrafterDevice(obj, obj.lcr);
            obj.addDevice(lightCrafter);
        end
    end
end

