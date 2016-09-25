classdef SimulatedDaqWithStage < symphonyui.core.descriptions.RigDescription
    
    methods
        
        function obj = SimulatedDaqWithStage()
            import symphonyui.builtin.daqs.*;
            import symphonyui.builtin.devices.*;
            import symphonyui.core.*;
            
            daq = HekaSimulationDaqController();
            obj.daqController = daq;
            
            amp1 = MultiClampDevice('Amp1', 1).bindStream(daq.getStream('ANALOG_OUT.0')).bindStream(daq.getStream('ANALOG_IN.0'));
            obj.addDevice(amp1);
            
            amp2 = MultiClampDevice('Amp2', 2).bindStream(daq.getStream('ANALOG_OUT.1')).bindStream(daq.getStream('ANALOG_IN.1'));
            obj.addDevice(amp2);
            
            stage = io.github.stage_vss.devices.StageDevice('localhost');
            stage.addConfigurationSetting('micronsPerPixel', 1.6, 'isReadOnly', true);
            obj.addDevice(stage);
            
            propertyDevice = sa_labs.devices.RigPropertyDevice('test', true);
            obj.addDevice(propertyDevice);
        end
        
    end
    
end

