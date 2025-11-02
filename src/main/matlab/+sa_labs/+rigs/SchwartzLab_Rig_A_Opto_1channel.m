classdef SchwartzLab_Rig_A_Opto_1channel < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig A Opto 1 channel';
        testMode = false;
        filterWheelNdfValues = [1, 2, 3, 4, 5, 0];
        filterWheelDefaultValue = 5;
        
        filterWheelAttenuationValues_Blue = [1.58e-1, 11.2e-3, 9.01e-4, 8.23e-5, 6.96e-6, 1.582];%updated 6/1/2022 -David
        filterWheelAttenuationValues_Green = [1e-1, 1e-2 , 1e-3 , 1.1e-4 , 1.1e-5, 1];%updated 5/26/2022 -David
        filterWheelAttenuationValues_UV = [5.8e-02, 1.7e-03, 1.2e-04, 0.6e-5, 0.3e-6, 1];%updated 11/15/2022 -David
        
        fitBlue = [9.10317387691189e-18	-1.18865973635156e-14	3.85486264901338e-12	-1.66847157811571e-11];%updated 5/26/2022 -David
        fitGreen =[1.21309650979622e-18	-4.08598841738357e-16	3.78474579983637e-14	-4.17594216385694e-14];%updated 5/26/2022 -David (Green projector not modulating current and is dim)
        fitUV =   [-1.03e-18, -1.07e-16, 1.89e-13, 1.76e-11];%updated 11/15/2022 -David
        
        micronsPerPixel = 1.3; %updated 6/1/2022 -David
        frameTrackerPosition = [10,50]; %updated 5/26/2022 -David
        frameTrackerSize = [200,100]; %updated 5/26/2022 -David
        frameTrackerBackgroundSize = [200, 100]; %updated 7/28/2022 - Zach
        
        filterWheelComPort = 'COM7';
        orientation = [false, true];%[flip Y, flip X]
        angleOffset = 0; %Does not actually change presentation.  Is saved in epoch data so it could be used in analysis, but it isn't used now.
        
        %Overlap of the Rod, S_cone, and M_cone spectrum with each LED. Must be in order [1 Rod, 2 S cone, 3 M cone]
        spectralOverlap_Blue = [4.76558684709051e+18	6.55091000309801e+15	3.81318946776386e+18];%updated 5/26/2022 -David
        spectralOverlap_Green = [2.66406358405798e+18	1.10188075264679e+15	3.77493986028575e+18];%updated 5/26/2022 -David
        spectralOverlap_UV = [9.68180413015343e+17	1.31761176294673e+18	1.12668172298288e+18];%updated 5/26/2022 -David
        
        projectorColorMode = 'uv2'; % Rig A has MkII projector
        numberOfAmplifiers = 1;
        daq_name = 'Dev1';
        
        host = '192.168.0.3'; %What is the ip address to connect to the stage computer?  If Stage is running on this computer, use 'localhost'.
        daq_type = 'NI'; %What brand data aquisition board is being used?  'Heka' or 'NI'
    end
    
    methods
        
        function obj = SchwartzLab_Rig_A_Opto_1channel(delayInit)
            %{Port, bit number, unit} for any datastreams. 
            % unit = 0 for unitless.  
            % bit number = -1 for analog.
            % Comment out if you don't want to use.
     
            obj.daqStreams('Oscilloscope Trigger') = {'doport0', 0, 0}; %
            obj.daqStreams('Stim Time Recorder') = {'doport0', 1, 0}; %
            obj.daqStreams('Optogenetics Trigger') = {'doport0', 6, 0}; %
%             obj.daqStreams('Scanhead Trigger') = {'doport1', 2, 0}; %
%             obj.daqStreams('ScanImageShutter') = {'diport0', 2, 0};
            obj.daqStreams('Opto Trigger testing') = {'ai6', -1, 'V'};
            obj.daqStreams('Bath Temperature') = {'ai2',-1,'degC'};
            obj.daqStreams('Bath Temperature Control') = {'ai3',-1,'degC'};
            
            
            % Sophia changes 12/14/21
%             obj.daqStreams('Excitatory conductance') = {'ao2', -1, 'V'}; %
%             obj.daqStreams('Inhibitory conductance') = {'ao3', -1, 'V'}; %
            
            if nargin < 1
                delayInit = false;
            end
            
            if ~delayInit
                obj.initializeRig();
            end
        end
        
    end
    
end

