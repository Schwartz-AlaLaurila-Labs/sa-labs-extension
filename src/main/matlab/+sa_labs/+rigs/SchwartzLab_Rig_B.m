classdef SchwartzLab_Rig_B < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B';
        testMode=false;
        filterWheelNdfValues = [1, 2, 3, 4, 5, 0]; %updated 4/2/21 - David
        filterWheelDefaultValue = 5;
        
        filterWheelAttenuationValues_Blue = [0.087209302	0.00744186	0.000612403	6.77132E-05	6.47287E-06 1];%updated 7/1/21 - David
        filterWheelAttenuationValues_Green = [0.089974684	0.008658228	0.000759494	7.06621E-05	6.48122E-06 1];%updated 02/25/21 -David - NDF 4 & 5 were predicted from lower NDF values
        filterWheelAttenuationValues_UV = [0.035217391	0.002063241	8.60316E-05	3.90679E-06	1.77411E-07 1]; %updated 02/25/21 -David - NDF 3, 4, & 5 were predicted from lower NDF values
        
        fitBlue = [5.01054711270044e-18	-2.21188541610487e-15	5.27272199418043e-13	-1.20400470830141e-11];%updated 10/05/21 - David
        fitGreen = [4.49248176839518e-18,-4.34318771541836e-15,1.82493374651640e-12,-4.51382977537234e-11];%updated 7/1/21 - David
        fitUV = [1.26531855824211e-19,-1.62979438916323e-16,1.00928035139656e-13,4.87488460073430e-12];%updated 7/1/21 - David
        
        micronsPerPixel = 1.45 %updated 9/10/21 -Davide.

        frameTrackerPosition = [0,1280];%updated 02/23/21 -David

        frameTrackerSize = [100,100];%updated 02/23/21 -David
       
        filterWheelComPort = 'COM5';
        orientation = [false, true]; %[flip Y, flip X]
        angleOffset = 0; %Does not actually change presentation.  Is saved in epoch data so it could be used in analysis, but it isn't used now.
        
        %Overlap of the Rod, S_cone, and M_cone spectrum with each LED. Must be in order [1 Rod, 2 S cone, 3 M cone]
        spectralOverlap_Blue = [4.73e+18,2.85e+15,3.76e+18];%updated 7/1/21 - David
        spectralOverlap_Green = [3.41e+18,1730000000000,4.56e+18];%updated 7/1/21 - David
        spectralOverlap_UV = [1.09e+18,1.15e+18,1.17e+18];%updated 7/1/21 - David
        
        projectorColorMode = 'uv';
        numberOfAmplifiers = 2;
        
        host = '192.168.0.3'; %What is the ip address to connect to the stage computer?  If Stage is running on this computer, use 'localhost'.
        daq_type = 'NI'; %What brand data aquisition board is being used?  'Heka' or 'NI'
    end
    
    methods
        
        function obj = SchwartzLab_Rig_B(delayInit)
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
            
            if nargin < 1
                delayInit = false;
            end
            
            if ~delayInit
                obj.initializeRig();
            end
        end

    end
    
end

