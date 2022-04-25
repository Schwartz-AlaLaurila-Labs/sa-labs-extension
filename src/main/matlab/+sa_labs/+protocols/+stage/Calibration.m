classdef Calibration < sa_labs.protocols.StageProtocol

properties
    %times in ms
    preTime = 500	% Spot leading duration (ms)
    stimTime = 1000	% Spot duration (ms)
    tailTime = 1000	% Spot trailing duration (ms)
    
    intensity = 0.5;
    
    spotSize = 200; % um
    numberOfEpochs = 500;
end

properties (Hidden)
    version = 4
    
    responsePlotMode = 'cartesian';
    responsePlotSplitParameter = 'spotSize';
end

properties (Hidden, Dependent)
    totalNumEpochs
end

%TODO: use bayesian optimization to select points in which we're not confident
% can we do this while altering a single parameter at a time? otherwise it could get slow?

methods

    function obj = Calibration()
        obj@sa_labs.protocols.StageProtocol();
        %TODO: we want to set certain properties, such as 3 color pattern mode, etc.
        %should also hide some settings...

    end

    function prepareEpoch(obj, epoch)

        %alter the LED values, PWM, NDF, intensity....
        r = rand;
        if r < .33
            i = ceil(r*5); %5 equally likely options
            v = setdiff(1:6,obj.NDF); % exclude the current set point
            obj.NDF = v(i); % select a new value

            obj.rig.getDevice('neutralDensityFilterWheel').setNdfValue(obj.NDF);
            %hangs to completion (3sec)
            %TODO: if we make an async method on the NDF class we can adjust simultaneously...
        elseif r < .66
            r = randi(255,4,1);
            obj.redPWM = r(1)/255;
            obj.bluePWM = r(2)/255;
            obj.greenPWM = r(3)/255;
            obj.uvPWM = r(4)/255;            

            obj.setPWM({'red','blue','green','uv'}, [obj.redPWM, obj.bluePWM, obj.greenPWM, obj.uvPWM]);
            %TODO: make an async method on the blanking circuit class
        else
            r = randi(255,4,1);            
            obj.redLED = r(1);
            obj.blueLED = r(2);
            obj.greenLED = r(3);
            obj.uvLED = r(4);

            obj.rig.getDevice('LightCrafter').setLedCurrents(obj.redLED, obj.greenLED, obj.blueLED, obj.uvLED);
            pause(0.2);
        end

        obj.intensity = randi(127)/127; %no time cost here as long as we're inheriting from stage protocol
        
        epoch.addParameter('intensity',obj.intensity * 127);
        epoch.addParameter('NDF',obj.NDF);
        epoch.addParameter('blueLED',obj.blueLED);
        epoch.addParameter('greenLED',obj.greenLED);
        epoch.addParameter('uvLED',obj.uvLED);
        epoch.addParameter('redLED',obj.redLED);
        epoch.addParameter('bluePWM',obj.bluePWM * 255);
        epoch.addParameter('greenPWM',obj.greenPWM * 255);
        epoch.addParameter('uvPWM',obj.uvPWM * 255);
        epoch.addParameter('redPWM',obj.redPWM * 255);
        % Call the base method.
        prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);        
    end

    function p = createPresentation(obj)
        p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
        
        spot = stage.builtin.stimuli.Ellipse();
        spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
        spot.radiusY = spot.radiusX;
        spot.color = obj.intensity;
        spot.opacity = 1;
        canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
        spot.position = canvasSize / 2;
        p.addStimulus(spot);
        
        obj.setOnDuringStimController(p, spot);
        
        % shared code for multi-pattern objects
        obj.setColorController(p, spot);
    end

    function totalNumEpochs = get.totalNumEpochs(obj)
        totalNumEpochs = obj.numberOfEpochs;
    end
    

end


end