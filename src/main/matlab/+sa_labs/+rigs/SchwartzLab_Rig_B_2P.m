classdef SchwartzLab_Rig_B_2P < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        % This rigConfiguration is for use when the blue passband filter (ET460) is
        % swiveled into place to allow for simultaneous 2P imaging and projector stimulation.
        % Only blue projector light should be used.
        rigName = 'Schwartz Lab Rig B 2P';
        testMode=false;
        filterWheelNdfValues = [1, 2, 3, 4, 5, 0]; %updated 4/2/21 - David
        filterWheelDefaultValue = 5;
        
        filterWheelAttenuationValues_Blue = [0,0,0,0,0,0];%updated 8/8/22 - Zach
        filterWheelAttenuationValues_Green = [0,0,0,0,0,0];%Only use uv LED when uvpass filter is in place. - Zach
        filterWheelAttenuationValues_UV = [0.05434782609 0.003333333333 0.0001893719807 0.00001572463768 0.000001132850242 1]; %updated 8/8/22 - Zach
        
        fitBlue = 0;%updated 8/8/22 - Zach
        
        fitGreen = 0;%updated 8/8/22 - Zach
        fitUV = 1.0e-11 *[-0.000000122471269  -0.000012818464172   0.097151912916748  -0.118471538418705];%updated 8/8/22 - Zach

        micronsPerPixel = 1.3 %updated 7/18/22 Zach

        frameTrackerPosition = [160, 1280]; %updated 7/25/22 Zach
        frameTrackerDuration = 0.1; %updated 5/26/22 Zach
        frameTrackerBackgroundSize = [360, 2560]; %updated 7/25/22 Zach
        frameTrackerSize = [240, 640]; %updated 7/25/22 Zach
        canvasTranslation = [117, 0]; %updated 6/9/22 Zach
       
        filterWheelComPort = 'COM5';
        orientation = [false, true]; %[flip Y, flip X]
        angleOffset = 180; %Does not actually change presentation.  Is saved in epoch data so it could be used in analysis, but it isn't used now.
        
        %Overlap of the Rod, S_cone, and M_cone spectrum with each LED. Must be in order [1 Rod, 2 S cone, 3 M cone]
        spectralOverlap_Blue = [4.86e+18,5.57e+15,3.87e+18];%updated 7/1/21 - David
        spectralOverlap_Green = [2.47e+18,2.65e+17,2.36e+18];%updated 7/1/21 - David
        spectralOverlap_UV = 1.0e+18 *[1.283430135114683   0.435136715498093   1.197782733955319];%updated 8/8/22 Zach
        
        projectorColorMode = 'uv';
        numberOfAmplifiers = 1;
        
        host = '192.168.0.3'; %What is the ip address to connect to the stage computer?  If Stage is running on this computer, use 'localhost'.
        daq_type = 'NI'; %What brand data aquisition board is being used?  'Heka' or 'NI'

        video_path = 'D:\Movies\'
        
        blankingCircuitComPort = 'COM3';
    end
    
    methods
        
        function obj = SchwartzLab_Rig_B_2P(delayInit)
            %{Port, bit number, unit} for any datastreams. 
            % unit = 0 for unitless.  
            % bit number = -1 for analog.
            % Comment out if you don't want to use.
     
            obj.daqStreams('Oscilloscope Trigger') = {'doport0', 0, 0}; %
            obj.daqStreams('Stim Time Recorder') = {'doport0', 1, 0}; %
            %daqStreams('Scanhead Trigger') = {'doport1', 2, 0}; %
            %daqStreams('Optogenetics Trigger') = {'doport1', 3, 0}; %
            %daqStreams('Scanhead Trigger') = {'doport1', 2, 0}; %
            %daqStreams('Excitatory conductance') = {'ao2', -1, 'V'}; %
            %daqStreams('Inhibitory conductance') = {'ao3', -1, 'V'}; %
            obj.daqStreams('LED_blanking_signal') = {'ai3', -1, 'V'}; %
            
            if nargin < 1
                delayInit = false;
            end
            
            if ~delayInit
                obj.initializeRig();
            end
        end

    end
    
end

