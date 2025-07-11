classdef SchwartzLab_Rig_B < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B';
        testMode=false;
        filterWheelNdfValues = [1, 2, 3, 4, 5, 0]; %updated 4/2/21 - David
        filterWheelDefaultValue = 5;
        
        filterWheelAttenuationValues_Blue = [0.087209302	0.00744186	0.000612403	6.77132E-05	6.47287E-06 1];%updated 7/1/21 - David
        filterWheelAttenuationValues_Green = [0.09226100152 0.009301972686 0.0007905918058 0.00008679817906 0.000007738998483 1];%updated 7/18/22 - Zach
        % filterWheelAttenuationValues_UV = [0.05592417062 0.003601895735 0.0002180094787 0.0001943127962 0.000001815165877 0.00000005473933649 1] %updated 9/6/23 - Raphael Julia no filters
        %filterWheelAttenuationValues_UV = [0.05463414634, 0.003398373984, 0.0001918699187, 0.00001536585366, 0.0000007512195122, 1]; %updated 10/25/23 - Zach & Trung
        filterWheelAttenuationValues_UV = [0.05446927374	0.004476256983	0.0001330307263	0.00001143505587	0.000001138268156	1] %updated 060624 Trung
        
        fitBlue = [0 0 0 0];%updated 6/9/22 - Zach
        fitGreen = [0 0 0 0];%updated 8/01/23 - Zach
        % fitUV = 1.0e-11 *[ 0.000000792067937, -0.001815711190665, 1.929889803588720, -0.83029837531757]; %updated 9/06/23 - Raphael Julia no filters
        %fitUV = 1.0e-11 *[-0.000000222416821,  -0.000023093679523,   0.132667150269873,  -0.062845871410866];  %updated 10/25/23 - Zach & Trung
        fitUV = 1.0e-11 * [-0.000000380375886   0.000050547685006   0.128270248164492   0.003224096869558] %update 060624 Trung & Ralph
        micronsPerPixel = 1.6 %updated 7/31/23 Zach

        frameTrackerPosition = [0, 300]; %updated 9/1/22 David
        frameTrackerDuration = 0.05; %updated 9/1/22 David

        frameTrackerBackgroundSize = [800, 2000]; %updated 9/1/22 David
        frameTrackerSize = [80, 400]; %updated 9/1/22 David
        canvasTranslation = [117, 0]; %updated 6/9/22 Zach
       
        filterWheelComPort = 'COM5';
        orientation = [false, true]; %[flip Y, flip X]
        angleOffset = 180; %Does not actually change presentation.  Is saved in epoch data so it could be used in analysis, but it isn't used now.
        
        %Overlap of the Rod, S_cone, and M_cone spectrum with each LED. Must be in order [1 Rod, 2 S cone, 3 M cone]
        spectralOverlap_Blue = [4.86e+18,5.57e+15,3.87e+18];%updated 7/1/21 - David
        spectralOverlap_Green = [2.47e+18,2.65e+17,2.36e+18];%updated 7/1/21 - David
        % spectralOverlap_UV = 1.0e+18 *[1.664963607035264256   0.229857695610952384   1.390285909043689984]; %updated 9/6/23 Raphael -- no filters
        %spectralOverlap_UV = 1.0e+18 *[1.317131095011983   0.388339837907882   1.209319067404767];%updated 8=10/20/23 Zach
        spectralOverlap_UV = 1.0e+18 * [1.3351167602045    0.382428032582483   1.220702730457848]; % 060524 Trung
        projectorColorMode = 'uv';
        numberOfAmplifiers = 1;
        
        
        host = '192.168.0.3'; %What is the ip address to connect to the stage computer?  If Stage is running on this computer, use 'localhost'.
       
         daq_type = 'NI'; %What brand data aquisition board is being used?  'Heka' or 'NI'

        blankingCircuitComPort = 'COM3';
        
        video_path = 'D:\Movies\';
    end
    
    methods
        
        function obj = SchwartzLab_Rig_B(delayInit)
            %{Port, bit number, unit} for any datastreams. 
            % unit = 0 for unitless.  
            % bit number = -1 for analog.
            % Comment out if you don't want to use.
     
            obj.daqStreams('Oscilloscope Trigger') = {'doport0', 0, 0}; %
            obj.daqStreams('Stim Time Recorder') = {'doport0', 1, 0}; %
            obj.daqStreams('Frame Timing') = {'ai3',-1, 'V'};
            %obj.daqStreams('picospritz_trigger') = {'ao1',-1,'V'};
            %daqStreams('Scanhead Trigger') = {'doport1', 2, 0}; %
            %daqStreams('Optogenetics Trigger') = {'doport1', 3, 0}; %
            %daqStreams('Scanhead Trigger') = {'doport1', 2, 0}; %
            obj.daqStreams('Excitatory conductance') = {'ao0', -1, 'V'}; %
            obj.daqStreams('Inhibitory conductance') = {'ao1', -1, 'V'}; %
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

