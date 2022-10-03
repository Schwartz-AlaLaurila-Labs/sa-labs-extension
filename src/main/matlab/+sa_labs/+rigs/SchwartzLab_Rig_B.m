classdef SchwartzLab_Rig_B < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B';
        testMode=false;
        filterWheelNdfValues = [1, 2, 3, 4, 5, 0]; %updated 4/2/21 - David
        filterWheelDefaultValue = 5;
        
        filterWheelAttenuationValues_Blue = [0.087209302	0.00744186	0.000612403	6.77132E-05	6.47287E-06 1];%updated 7/1/21 - David
        filterWheelAttenuationValues_Green = [0.09226100152 0.009301972686 0.0007905918058 0.00008679817906 0.000007738998483 1];%updated 7/18/22 - Zach
        filterWheelAttenuationValues_UV = [0.05594405594 0.003496503497 0.000201048951 0.0000166958042 0.000001001748252 1]; %updated 7/18/22 - Zach
        
        fitBlue = [0 0 0 0];%updated 6/9/22 - Zach
        fitGreen = 1.0e-11 * [ -0.000000004724626  -0.000066611981518   0.152551895079695  -0.251696442734011];%updated 8/29/22 - Zach
        fitUV = 1.0e-11 * [-0.000000152703718  -0.000044641539479   0.139866315500134  -0.147409969366771];%updated 8/29/22 - Zach
        
        micronsPerPixel = 1.3 %updated 7/18/22 Zach

        frameTrackerPosition = [0, 300]; %updated 9/1/22 David
        frameTrackerDuration = 0.05; %updated 9/1/22 David
        frameTrackerBackgroundSize = [800, 2000]; %updated 9/1/22 David
        frameTrackerSize = [80, 400]; %updated 9/1/22 David
        canvasTranslation = [117, 0]; %updated 6/9/22 Zach
       
        filterWheelComPort = 'COM5';
        orientation = [false, true]; %[flip Y, flip X]
        angleOffset = 180; %Does not actually change presentation.  Is saved in epoch data so it could be used in analysis, but it isn't used now.
        
        %Overlap of the Rod, S_cone, and M_cone spectrum with each LED. Must be in order [1 Rod, 2 S cone, 3 M cone]
        spectralOverlap_Blue = [4.73e+18,2.85e+15,3.76e+18];%updated 7/1/21 - David
        spectralOverlap_Green = [2.50272617664986e+18	1.47464420795067e+15	4.03261286137103e+18];%updated 6/9/22 - Zach
        spectralOverlap_UV = [1.18974879467848e+18	6.55496793103621e+17	1.17668333802297e+18];%updated 6/9/22 - Zach
        
        projectorColorMode = 'uv';
        numberOfAmplifiers = 1;
        
        host = '192.168.0.3'; %What is the ip address to connect to the stage computer?  If Stage is running on this computer, use 'localhost'.
        % host = 'localhost';
        daq_type = 'NI'; %What brand data aquisition board is being used?  'Heka' or 'NI'

        blankingCircuitComPort = 'COM3';
        video_path = 'D:\Movies\'
    end
    
    methods
        
        function obj = SchwartzLab_Rig_B(delayInit)
            %{Port, bit number, unit} for any datastreams. 
            % unit = 0 for unitless.  
            % bit number = -1 for analog.
            % Comment out if you don't want to use.
     
            obj.daqStreams('Oscilloscope Trigger') = {'doport0', 0, 0}; %
            obj.daqStreams('Stim Time Recorder') = {'doport0', 1, 0}; %
            obj.daqStreams('Frame timing') = {'ai3',-1, 'V'};
            %daqStreams('Scanhead Trigger') = {'doport1', 2, 0}; %
            %daqStreams('Optogenetics Trigger') = {'doport1', 3, 0}; %
            %daqStreams('Scanhead Trigger') = {'doport1', 2, 0}; %
            %daqStreams('Excitatory conductance') = {'ao2', -1, 'V'}; %
            %daqStreams('Inhibitory conductance') = {'ao3', -1, 'V'}; %
%             obj.daqStreams('LED_blanking_signal') = {'ai3', -1, 'V'}; %
            
            % obj.daqStreams('Test DI') = {'diport0', 31, 0};
            
            if nargin < 1
                delayInit = false;
            end
            
            if ~delayInit
                obj.initializeRig();
            end
        end

    end
    
end

