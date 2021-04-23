classdef SchwartzLab_Rig_B < sa_labs.rigs.SchwartzLab_Rig_Base
    
    properties
        % properties not accessible here; have to be fed into a device to work
        rigName = 'Schwartz Lab Rig B';
        testMode=false;
        filterWheelNdfValues = [1, 2, 3, 4, 5, 0]; %updated 4/2/21 - David
        filterWheelDefaultValue = 5;
        
        filterWheelAttenuationValues_Blue = [0.085483871	0.007104839	0.000581452	6.26613E-05	4.91935E-06 1];%updated 04/02/21 -David
        filterWheelAttenuationValues_Green = [0.089974684	0.008658228	0.000759494	7.06621E-05	6.48122E-06 1];%updated 02/25/21 -David - NDF 4 & 5 were predicted from lower NDF values
        filterWheelAttenuationValues_UV = [0.035217391	0.002063241	8.60316E-05	3.90679E-06	1.77411E-07 1]; %updated 02/25/21 -David - NDF 3, 4, & 5 were predicted from lower NDF values
        
        fitBlue = [8.93243522328669e-12	-6.33655824874954e-09	2.28583593567928e-06	-5.36819002998869e-05];%updated 04/02/21 -David
        fitGreen =[2.89068828608872e-12	-3.87496510471152e-09	1.82887343961211e-06	-4.47651235638903e-05];%updated 04/02/21 -David
        fitUV = [1.89128424063915e-14	-1.36173777885635e-10	9.89066087064172e-08	4.92915628123552e-06];%updated 04/02/21 -David
        
        micronsPerPixel = 1.65 %updated 2/25/21 -David -- There is a slight discrepancy between X and Y axis.  1.7 is best for X, 1.6 if best for Y.  I split the difference.

        frameTrackerPosition = [0,1280];%updated 02/23/21 -David

        frameTrackerSize = [100,100];%updated 02/23/21 -David
       
        filterWheelComPort = 'COM5';
        orientation = [false, true]; %[flip Y, flip X]
        angleOffset = 0; %Does not actually change presentation.  Is saved in epoch data so it could be used in analysis, but it isn't used now.
        
        %Overlap of the Rod, S_cone, and M_cone spectrum with each LED. Must be in order [1 Rod, 2 S cone, 3 M cone]
        spectralOverlap_Blue = [4.49937844347436e+18,4.24282748934854e+15,3.54491702447797e+18];%updated 11/21/2019 -David
        spectralOverlap_Green = [3.23202384601926e+18,470157632364029,4.54479333609599e+18];%updated 11/21/2019 -David
        spectralOverlap_UV = [9.35392735238728e+17,1.45353301827043e+18,1.11745334749763e+18];%updated 11/21/2019 -David
        
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

