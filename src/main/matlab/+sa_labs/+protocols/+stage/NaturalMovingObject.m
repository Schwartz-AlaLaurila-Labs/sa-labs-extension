classdef NaturalMovingObject < sa_labs.protocols.StageProtocol
    
    properties
        preFrames = 30                          % burn-in frames
        stimFrames = 60                         % frames before hexagon constraint
        tailFrames = 60                         % frames after hexagon constraint
        intensity = 1.0                         % Object light intensity (0-1)
        tau = 0.25                              % velocity time constant (sec)
        tauz = 0.50                             % scale time constant (sec)
        sigma = 200                             % velocity variance (um/sec)
        sigmaz = 2/3                            % scale variance
        diameter = 30                           % spot size (um)          
        mosaicSpacing = 168                     % distance (um) between cells in simulated mosaic
        mosaicDegree = int8(1)                 % 0: centered only, 1: centered + 6 nearest neighbors, 2: centered + 18 nearest neighbors 
        seedStartValue = 1                      % seed 
        numSeeds = 1000                         % number of seeds to test
        numRepeats = 1                          % number of repeats per seed
        motionTrajectory = 'natural+control'    % which kind of trajectory
    end
    
    properties (Dependent)
        preTime
        stimTime
        tailTime
        totalNumEpochs
        numTranslations
    end

    properties (Hidden)
        version = 2                     % v2: brownian motion constrained to hexagon
    end
    
    properties (Hidden, Transient)
        seedList = []                   % seed values
        motionType = []                 % natural (1) or control (0) 
        translation = []                % offset for trial
        xy = []                         % trajectories
        i_ = []                         % current trajectory
        tr_ = []                        % current offset
        motionTrajectoryType = symphonyui.core.PropertyType('char', 'row', {'natural', 'control', 'natural+control'})
        responsePlotMode = 'cartesian' %TODO...
        responsePlotSplitParameter = 'curMotionType'
        mosaicDegreeType = symphonyui.core.PropertyType('int8', 'scalar')
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if strcmp(obj.motionTrajectory, 'natural+control')
                nSeeds = obj.numSeeds * 2;
            else
                nSeeds = obj.numSeeds;
            end

            nSeeds = nSeeds * obj.numTranslations;

            obj.seedList = zeros(nSeeds, obj.numRepeats);
            obj.motionType = zeros(nSeeds, obj.numRepeats);
            obj.translation = zeros(nSeeds, obj.numRepeats);
            for r=1:obj.numRepeats
                s = randperm(nSeeds) - 1;
                obj.seedList(:,r) = mod(s, obj.numSeeds);
                obj.translation(:,r) = mod(floor(s / obj.numSeeds), obj.numTranslations) + 1;
                obj.motionType(:,r) = floor(floor(s / obj.numSeeds) / obj.numTranslations);
            end
            if strcmp(obj.motionTrajectory, 'natural')
                obj.motionType = obj.motionType + 1;
            end
            obj.seedList = obj.seedList + obj.seedStartValue;
            [~,obj.xy] = obj.um2pix(obj.generateParameters(1/obj.frameRate));

            grid = obj.generateGrid();
            obj.translation = grid(obj.translation,:);
        end     

        function xy = generateGrid(obj)
            %cubic coordinates -- to filter on degree
            [Q,R] = meshgrid(-obj.mosaicDegree:obj.mosaicDegree);
            S = -Q -R; 
            %the valid points are those where |S,Q,R| < deg
            Q = Q(abs(S) <= obj.mosaicDegree);
            R = R(abs(S) <= obj.mosaicDegree);

            %convert to square grid coordinates
            col = Q + (R - bitand(R, 1, 'int8'))/2 + obj.mosaicDegree + 1;
            row = R + obj.mosaicDegree + 1;

            %convert to cartesian coordinates
            qx = double(-obj.mosaicDegree:obj.mosaicDegree);
            qy = qx * 3/2 / sqrt(3);
            [QX,QY] = meshgrid(qx,qy);
            if mod(abs(obj.mosaicDegree),2)
                QX(1:2:end,:) = QX(1:2:end,:) + 1/2;
            else
                QX(2:2:end,:) = QX(2:2:end,:) + 1/2;
            end
            linind = sub2ind(size(QX),row,col);
            %rescale by spacing to obtain retinal coordinates
            xy = [QX(linind),QY(linind)] * obj.mosaicSpacing;
        end

        function xy = generateParameters(obj, dt)
            %NOTE: dt is precalculated so that this can be run offline
            %NOTE: we add one additional frame at the end for clearing the projector
            Nsamp = obj.preFrames + obj.stimFrames + obj.tailFrames + 1;
            total_time = Nsamp * dt;
            t_hex = (obj.preFrames + obj.stimFrames) * dt;
            
            if strcmp(obj.motionTrajectory, 'natural+control')
                xy = zeros(Nsamp, 2, obj.numSeeds * 2);
                for i = 1:obj.numSeeds
                    [xy(:,1,i),xy(:,2,i),~,~,~,~,xy(:,1,i+obj.numSeeds),xy(:,2,i+obj.numSeeds),~,~] ...
                        = sa_labs.util.BMARGSM(obj.tau,obj.sigma,obj.tauz,obj.sigmaz,dt,...
                        total_time,t_hex,obj.mosaicSpacing, i + obj.seedStartValue - 1);
                end
            elseif strcmp(obj.motionTrajectory, 'natural')
                xy = zeros(Nsamp, 2, obj.numSeeds);
                for i = 1:obj.numSeeds
                    [xy(:,1,i),xy(:,2,i)] ...
                        = sa_labs.util.BMARGSM(obj.tau,obj.sigma,obj.tauz,obj.sigmaz,dt,...
                        total_time,t_hex,obj.mosaicSpacing, i + obj.seedStartValue - 1);
                end
            else
                xy = zeros(Nsamp, 2, obj.numSeeds);
                for i = 1:obj.numSeeds
                    [~,~,~,~,~,~,xy(:,1,i),xy(:,2,i),~,~] ...
                        = sa_labs.util.BMARGSM(obj.tau,obj.sigma,obj.tauz,obj.sigmaz,dt,...
                        total_time,t_hex,obj.mosaicSpacing, i + obj.seedStartValue - 1);
                end
            end

            % size(obj.xy) ==  [numSamples , 2, nSeeds];
        end
        
        function prepareEpoch(obj, epoch)
            
            obj.tr_ = obj.translation(obj.numEpochsPrepared+1,:);
            epoch.addParameter('cx',obj.tr_(1));
            epoch.addParameter('cy',obj.tr_(2));
            
            seed = obj.seedList(obj.numEpochsPrepared+1);
            epoch.addParameter('motionSeed', seed);
            
            if strcmp(obj.motionTrajectory,'natural+control')
                mtype = obj.motionType(obj.numEpochsPrepared+1);
                if mtype
                    epoch.addParameter('curMotionType', 'natural');
                else
                    epoch.addParameter('curMotionType', 'control');
                end
                obj.i_ = seed - obj.seedStartValue + 1 + (1-mtype) * obj.numSeeds;
                fprintf('Using seed %d (%s [%d]): i = %d; +(%0.02f,%0.02f)\n', seed, epoch.parameters('curMotionType'), mtype, obj.i_, obj.tr_(1),obj.tr_(2));
            else
                epoch.addParameter('curMotionType',obj.motionTrajectory);
                obj.i_ = seed - obj.seedStartValue + 1;
            end
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function p = createPresentation(obj)            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            object = stage.builtin.stimuli.Ellipse();
            
            [~,object.radiusX] = obj.um2pix(obj.diameter / 2);
            object.radiusY = object.radiusX;
            object.color = obj.intensity;
            object.opacity = 1;
            object.orientation = 0;
            p.addStimulus(object);
            
            stageDevice = obj.rig.getDevice('Stage');
            canvasSize = stageDevice.getCanvasSize();
            
            xyi = obj.xy(:,:, obj.i_);
            [~,tr] = obj.um2pix(obj.tr_);
            center = canvasSize / 2 + tr;
            function pos = positionController(state)
                pos = xyi(state.frame+1,:) + center;
            end
          
            objectMovement = stage.builtin.controllers.PropertyController(object, 'position', @positionController);
            p.addController(objectMovement);
          
            nFrames = obj.preFrames + obj.stimFrames + obj.tailFrames;
            function o = opacityController(state)
                o = 1.0* ((state.frame + 1) < nFrames);
            end
            objectOpacity = stage.builtin.controllers.PropertyController(object, 'opacity', @opacityController);
            p.addController(objectOpacity);
            
        end

        function totalNumEpochs = get.totalNumEpochs(obj) % sets num of epochs equal to user input value
            totalNumEpochs = obj.numRepeats * obj.numSeeds * (1 + strcmp(obj.motionTrajectory, 'natural+control')) * obj.numTranslations; 
        end

        function preTime = get.preTime(obj)
            preTime = obj.preFrames / obj.frameRate * 1e3;
        end

        function stimTime = get.stimTime(obj)
            stimTime = obj.stimFrames / obj.frameRate * 1e3;
        end

        function tailTime = get.tailTime(obj)
            %add an extra frame at the end to turn off the spot during inter-trial time
            tailTime = (obj.tailFrames + 1) / obj.frameRate * 1e3;
        end

        function numTranslations = get.numTranslations(obj)
            numTranslations = 1 + sum(0:6:6*obj.mosaicDegree); %there is surely a more efficient way...
        end
        
    end
end

