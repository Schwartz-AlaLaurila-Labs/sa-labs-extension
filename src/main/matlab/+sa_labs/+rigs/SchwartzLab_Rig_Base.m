classdef SchwartzLab_Rig_Base < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function initializeRig(obj)
            
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            if obj.testMode
                daq = HekaSimulationDaqController();
            else
                daq = HekaDaqController(HekaDeviceType.USB18);
            end
            
            obj.daqController = daq;
            
            for i = 1:obj.numberOfAmplifiers
                amp = MultiClampDevice(sprintf('Amp%g', i), i).bindStream(daq.getStream(sprintf('ao%g', i-1))).bindStream(daq.getStream(sprintf('ai%g', i-1)));
                obj.addDevice(amp);
            end
            
            propertyDevice = sa_labs.devices.RigPropertyDevice(obj.rigName, obj.testMode);
            obj.addDevice(propertyDevice);
            
            if ~obj.testMode
                oscopeTrigger = UnitConvertingDevice('Oscilloscope Trigger', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
                daq.getStream('doport1').setBitPosition(oscopeTrigger, 0);
                obj.addDevice(oscopeTrigger);
                
                scanTrigger = UnitConvertingDevice('Scanhead Trigger', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
                daq.getStream('doport1').setBitPosition(scanTrigger, 2);
                obj.addDevice(scanTrigger);
                
                optoTrigger = UnitConvertingDevice('Optogenetics Trigger', symphonyui.core.Measurement.UNITLESS).bindStream(daq.getStream('doport1'));
                daq.getStream('doport1').setBitPosition(optoTrigger, 3);
                obj.addDevice(optoTrigger);
                
                if obj.enableDynamicClamp
                   % Dynamic clamp
                   gExc = UnitConvertingDevice('Excitatory conductance', 'V').bindStream(daq.getStream('ao2'));
                   obj.addDevice(gExc);
                   gInh = UnitConvertingDevice('Inhibitory conductance', 'V').bindStream(daq.getStream('ao3'));
                   obj.addDevice(gInh);
                end
                
            end            
            
            neutralDensityFilterWheel = sa_labs.devices.NeutralDensityFilterWheelDevice(obj.filterWheelComPort);
            neutralDensityFilterWheel.setConfigurationSetting('filterWheelNdfValues', obj.filterWheelNdfValues);
            neutralDensityFilterWheel.addResource('filterWheelAttenuationValues_Blue', obj.filterWheelAttenuationValues_Blue);
            neutralDensityFilterWheel.addResource('filterWheelAttenuationValues_Green', obj.filterWheelAttenuationValues_Green);
            neutralDensityFilterWheel.addResource('filterWheelAttenuationValues_UV', obj.filterWheelAttenuationValues_UV);
            neutralDensityFilterWheel.addResource('defaultNdfValue', obj.filterWheelDefaultValue);
            obj.addDevice(neutralDensityFilterWheel);
            
            lightCrafter = sa_labs.devices.LightCrafterDevice('colorMode', obj.projectorColorMode, 'orientation', obj.orientation);
            lightCrafter.setConfigurationSetting('micronsPerPixel', obj.micronsPerPixel);
            lightCrafter.setConfigurationSetting('angleOffset', obj.angleOffset);
            lightCrafter.setConfigurationSetting('frameTrackerPosition', obj.frameTrackerPosition);
            lightCrafter.setConfigurationSetting('frameTrackerSize', obj.frameTrackerSize);
            lightCrafter.addResource('fitBlue', obj.fitBlue);
            lightCrafter.addResource('fitGreen', obj.fitGreen);
            lightCrafter.addResource('fitUV', obj.fitUV);
            obj.addDevice(lightCrafter);
            
        end
        
        
%         function [rstar, mstar, sstar] = getIsomerizations(obj, intensity, parameter)
%             rstar = [];
%             mstar = [];
%             sstar = [];
%             if isempty(intensity)
%                 return
%             end
%             
%             NDF_attenuation = obj.filterWheelAttenuationValues(obj.filterWheelNdfValues == parameter.NDF);
%             
%             if strcmp('standard', obj.projectorColorMode)
%                 [R, M, S] = sa_labs.util.photoIsom2(parameter.blueLED, parameter.greenLED, ...
%                     parameter.color, obj.fitBlue, obj.fitGreen);
%             else
%                 % UV mode
%                 [R, M, S] = sa_labs.util.photoIsom2_triColor(parameter.blueLED, parameter.greenLED, parameter.uvLED, ...
%                     parameter.color, obj.fitBlue, obj.fitGreen, obj.fitUV);
%             end
%             
%             rstar = round(R * intensity * NDF_attenuation / parameter.numberOfPatterns, 1);
%             mstar = round(M * intensity * NDF_attenuation / parameter.numberOfPatterns, 1);
%             sstar = round(S * intensity * NDF_attenuation / parameter.numberOfPatterns, 1);
%         end
        
    end
    
end

