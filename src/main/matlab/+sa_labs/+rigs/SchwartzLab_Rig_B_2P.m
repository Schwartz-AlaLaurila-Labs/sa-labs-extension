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
        
        filterWheelAttenuationValues_Blue = [0.087209302	0.00744186	0.000612403	6.77132E-05	6.47287E-06 1];%updated 7/1/21 - David
        filterWheelAttenuationValues_Green = [0,0,0,0,0,0];%Only use blue LED when bluepass filter is in place. - David
        filterWheelAttenuationValues_UV = [0,0,0,0,0,0]; %Only use blue LED when bluepass filter is in place. - David
        
        fitBlue = [5.01054711270044e-18	-2.21188541610487e-15	5.27272199418043e-13	-1.20400470830141e-11];%updated 10/05/21 - David
        
        fitGreen = 0;%Only use blue LED when bluepass filter is in place. - David
        fitUV = 0;%Only use blue LED when bluepass filter is in place. - David
        
        micronsPerPixel = 1.45 %updated 9/10/21 -David

        frameTrackerPosition = [0,1280];%updated 02/23/21 -David

        frameTrackerSize = [100,100];%updated 02/23/21 -David
       
        blankingFactor = .4 %assumes line rate > 600 Hz. updated 09/09/21 - David and Zach

        filterWheelComPort = 'COM5';
        orientation = [false, true]; %[flip Y, flip X]
        angleOffset = 0; %Does not actually change presentation.  Is saved in epoch data so it could be used in analysis, but it isn't used now.
        
        %Overlap of the Rod, S_cone, and M_cone spectrum with each LED. Must be in order [1 Rod, 2 S cone, 3 M cone]
        spectralOverlap_Blue = [4.86e+18,5.57e+15,3.87e+18];%updated 7/1/21 - David
        spectralOverlap_Green = [2.47e+18,2.65e+17,2.36e+18];%updated 7/1/21 - David
        spectralOverlap_UV = [1.35e+18,3.02e+17,1.41e+18];%updated 7/1/21 - David
        
        projectorColorMode = 'uv';
        numberOfAmplifiers = 2;
        
        host = '192.168.0.3'; %What is the ip address to connect to the stage computer?  If Stage is running on this computer, use 'localhost'.
        daq_type = 'NI'; %What brand data aquisition board is being used?  'Heka' or 'NI'

        
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

