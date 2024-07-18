classdef NaturalMovingObject < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 50                     % Object leading duration (ms)
        tailTime = 50                    % Object trailing duration (ms)
        stimTime = 10000                  % stimulus duration (ms)
        intensity = 1.0                 % Object light intensity (0-1)
        tau = 0.1;                      %relaxation time
        D = 1;                            % diffusion coefficient
        dt = 1/60;                          % time step
        tauz = 0.25;                       % relaxtion time for z calc
        Dz = 0.125;                          % diffusion coefficient for z calc
        diameter = 50;                
        RFwidth = 200;                  % 95% of the motion will be within RFwidth/2 of the center
        motionSeed = 5;                     % seed 
        motionSeedChangeMode = 'increment only';
        numRepeats = 8;
        numSeeds = 5;
        motionTrajectory = 'natural';
    end
    
    properties (Hidden)
        version = 1                     % v1: initial version
        parameters = []                      % matrix of all epoch params [x,y,u,v,t]
        seedlist = []                   % vector with seeds
        motionSeedChangeModeType = symphonyui.core.PropertyType('char', 'row', {'repeat only', 'repeat & increment', 'increment only'})
        motionTrajectoryType = symphonyui.core.PropertyType('char', 'row', {'natural', 'control'})
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'motionSeed'; 
    end
    
    properties (Dependent)
        omega0                          %critical damping factor
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if strcmp(obj.motionSeedChangeMode, 'repeat & increment')
                for n=1:obj.numRepeats
                    seeds = randperm(obj.numSeeds);
                    obj.seedlist = [obj.seedlist; seeds];
                end
            end
        end     

        function generateParameters(obj)
            [x,y,u,v,~,t,x0,y0,u0,v0] = DHOARGSM(obj.tau, obj.omega0, obj.D, obj.tauz, obj.Dz, obj.dt, obj.stimTime, obj.preTime, obj.motionSeed);

            vstd = std([u; v]); % equalize velocity variance for GSM and control
            % instead of this, std of the vector velocity
%             m = sqrt(u.^2 + v.^2);
%             vstd = std(m)
            
            x = x/vstd;
            y = y/vstd;
            u = u/vstd;
            v = v/vstd;

            v0std = std([u0; v0]);
            x0 = x0/v0std;
            y0 = y0/v0std;
            u0 = u0/v0std;
            v0 = v0/v0std;

            xstd = std([x0; y0]); % normalize by control position variance
            x = x/xstd;
            y = y/xstd;
            u = u/xstd;
            v = v/xstd;
            x0 = x0/xstd;
            y0 = y0/xstd;
            u0 = u0/xstd;
            v0 = v0/xstd;

            mic = obj.RFwidth/4; % scale to microns
            x = x*mic;
            y = y*mic;
            u = u*mic;
            v = v*mic;
            x0 = x0*mic;
            y0 = y0*mic;
            u0 = u0*mic;
            v0 = v0*mic;
            
            x = x(1:length(t));
            y = y(1:length(t));
            u = u(1:length(t));
            v = v(1:length(t));

            % convert from microns to pixels
            [~,x] = obj.um2pix(x);
            [~,y] = obj.um2pix(y);
            [~,u] = obj.um2pix(u);
            [~,v] = obj.um2pix(v);
            
            x0 = x0(1:length(t));
            y0 = y0(1:length(t));
            u0 = u0(1:length(t));
            v0 = v0(1:length(t));

            % convert from microns to pixels
            [~,x0] = obj.um2pix(x0);
            [~,y0] = obj.um2pix(y0);
            [~,u0] = obj.um2pix(u0);
            [~,v0] = obj.um2pix(v0);

            if strcmp(obj.motionTrajectory, 'natural')
                obj.parameters = [x, y, u, v, t']; % has the x,y positions and x,y components of velocity for each time step
            end
            
            if strcmp(obj.motionTrajectory, 'control')
                obj.parameters = [x0, y0, u0, v0, t']; % same but for the control
            end
        end
        
        function prepareEpoch(obj, epoch)
            if strcmp(obj.motionSeedChangeMode, 'repeat only')
                seed = obj.motionSeedStart;
            elseif strcmp(obj.motionSeedChangeMode, 'increment only')
                seed = obj.numEpochsCompleted + obj.motionSeedStart;
            else
                seedIndex = obj.totalNumEpochs - obj.numEpochsPrepared;
                seed = obj.seedlist(seedIndex);
            end
            obj.motionSeed = seed; 
            
            epoch.addParameter('motionSeed', obj.motionSeed);
            obj.generateParameters();
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function p = createPresentation(obj)
            % get parameters for this epoch
            currentx = obj.parameters(:,1);
            currenty = obj.parameters(:,2);
            currentu = obj.parameters(:,3);
            currentv = obj.parameters(:,4);
            tarray = obj.parameters(:,5);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            object = stage.builtin.stimuli.Ellipse();
            object.radiusX = round(obj.um2pix(obj.diameter / 2));
            object.radiusY = object.radiusX;
            object.color = obj.intensity;
            object.opacity = 1;
            object.orientation = 0;
            p.addStimulus(object);
            
            stageDevice = obj.rig.getDevice('Stage');
            canvasSize = stageDevice.getCanvasSize();
            
            pos_c = canvasSize / 2;
            
            function pos = positionController(state)
                currentt = state.time - obj.preTime * 1e-3; % calcs current time
                [~,index] = min(abs(tarray-currentt)); % associates current time with the closest discrete t from the model
                if index > 0 && index <= length(currentx)
                    pos = [currentx(index)+obj.dt*currentu(index) + pos_c(1), currenty(index)+obj.dt*currentv(index) + pos_c(2)];
                end
            end
          
            objectMovement = stage.builtin.controllers.PropertyController(object, 'position', @(state)positionController(state));
            p.addController(objectMovement);
            
            obj.setOnDuringStimController(p, object);
            
            % shared code for multi-pattern objects
            obj.setColorController(p, object);
        end

        function totalNumEpochs = get.totalNumEpochs(obj) % sets num of epochs equal to user input value
            totalNumEpochs = obj.numRepeats * obj.numSeeds; 
        end
        
        function omega0 = get.omega0(obj) % sets omega0 equal to value associated with tau
            omega0 = 1/(2*obj.tau); 
        end       
    end
end

