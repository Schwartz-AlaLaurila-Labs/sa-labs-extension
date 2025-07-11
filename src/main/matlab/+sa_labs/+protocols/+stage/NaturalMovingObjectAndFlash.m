classdef NaturalMovingObjectAndFlash < sa_labs.protocols.StageProtocol
    
    properties
        preFrames = 15                          % burn-in frames
        stimFrames = 30                         % frames before hexagon constraint
        tailFrames = 30                         % frames after hexagon constraint
        intensity = 1.0                         % Object light intensity (0-1)
        tau = 0.25                              % velocity time constant (sec)
        tauz = 0.50                             % scale time constant (sec)
        sigma = 150                             % velocity variance (um/sec)
        sigmaz = 2/3                            % scale variance
        diameter = 30                           % spot size (um)
        Tburn = 5                               % burn-in time for stochastic motion generator
        mosaicSpacing = 168                     % distance (um) between cells in simulated mosaic
        mosaicDegree = int8(1)                  % 0: centered only, 1: centered + 6 nearest neighbors, 2: centered + 18 nearest neighbors 
        leeway = 20                             % increase stim hex radius by this amount to account for uncertainty in centering
        seedStartValue = 1                      % seed 
        numSeeds = 300                          % number of seeds to test
        seedBlockSize = 10                      % number of seeds per randomized block (must evenly divide numSeeds)
        numRepeats = 1                          % number of repeats per seed
        motionTrajectory = 'natural+control+flash'    % which kind of trajectory
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
        mo_ = []                        % current motion type
        motionTrajectoryType = symphonyui.core.PropertyType('char', 'row', {'natural', 'control', 'natural+control','natural+control+flash'})
        responsePlotMode = 'cartesian' %TODO...
        responsePlotSplitParameter = 'curMotionType'
        mosaicDegreeType = symphonyui.core.PropertyType('int8', 'scalar')
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if mod(obj.numSeeds,obj.seedBlockSize) == 0
                nBlocks = obj.numSeeds/obj.seedBlockSize;
            else
                error('numSeeds must be a multiple of seedBlockSize')
            end

            if strcmp(obj.motionTrajectory, 'natural+control+flash')
                nmotype = 3;
            elseif strcmp(obj.motionTrajectory, 'natural+control')
                nmotype = 2;
            else
                nmotype = 1;
            end
            
            
%             nSeeds = obj.numSeeds/obj.seedBlockSize * nmotype;
% 
%             nSeeds = nSeeds * obj.numTranslations;
%             
%             obj.seedList = zeros(obj.seedBlockSize*nSeeds, obj.numRepeats);
%             obj.motionType = zeros(obj.seedBlockSize*nSeeds, obj.numRepeats);
%             obj.translation = zeros(obj.seedBlockSize*nSeeds, obj.numRepeats);
%             for r=1:obj.numRepeats
%                 
%                 for b = 1:nBlocks
%                     
%                     
%                     s_sub = randperm(obj.numSeeds);
%                     [seedsub,transsub,mosub] = ind2sub([obj.seedBlockSize obj.numTranslations nmotype],s_sub);
%                     obj.seedList(idx,r) ...
%                         = seedsub-1+(b-1)*obj.seedBlockSize;
%                     obj.translation(idx,r) ...
%                         = transsub;
%                     obj.motionType(idx,r) ...
%                         = mosub-1;
%                 end
%             end
%             
            seed_array = [obj.seedStartValue : obj.seedStartValue + obj.numSeeds - 1];
            n_epoch = obj.totalNumEpochs;
            obj.seedList = zeros(n_epoch, 1);
            obj.motionType = zeros(n_epoch, 1);
            obj.translation = zeros(n_epoch, 1);
            motion_type_array = sort(repmat([1:nmotype], 1, obj.numTranslations * obj.seedBlockSize));
            translation_array = repmat([1:obj.numTranslations], nmotype * obj.seedBlockSize, 1);
            n_epoch_per_repeat = obj.numSeeds * ...
                (1 + strcmp(obj.motionTrajectory, 'natural+control') + ...
                2*strcmp(obj.motionTrajectory, 'natural+control+flash')) * obj.numTranslations; 
            for r = 1 : obj.numRepeats
                for b = 1:nBlocks    
                    seeds_in_block = seed_array((b-1)*obj.seedBlockSize +1 : b*obj.seedBlockSize);
                    idx = [(b-1)*obj.seedBlockSize*obj.numTranslations*nmotype+1 : b*obj.seedBlockSize*obj.numTranslations*nmotype] ...
                                        + (r - 1) * n_epoch_per_repeat;
                    seeds = repmat(seeds_in_block, 1, obj.numTranslations * nmotype);
                    seed_randperm = randperm(length(seeds));
                    obj.seedList(idx) = seeds(seed_randperm);
                    obj.translation(idx)= translation_array(seed_randperm);
                    obj.motionType(idx) = motion_type_array(seed_randperm);
                end
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
            
            if strcmp(obj.motionTrajectory, 'natural+control+flash')
                xy = zeros(Nsamp, 2, obj.numSeeds * 3);
                for i = 1:obj.numSeeds
                    [xy(:,1,i),xy(:,2,i),~,~,~,~,xy(:,1,i+obj.numSeeds),xy(:,2,i+obj.numSeeds),~,~,xhex,yhex] ...
                        = sa_labs.util.BMARGSMv2(obj.tau,obj.sigma,obj.tauz,obj.sigmaz,dt,...
                        total_time,t_hex,obj.mosaicSpacing/sqrt(3)+obj.leeway,obj.Tburn, i + obj.seedStartValue - 1);
                    xy(:,1,i+2*obj.numSeeds) = xhex;
                    xy(:,2,i+2*obj.numSeeds) = yhex;
                end
            elseif strcmp(obj.motionTrajectory, 'natural+control')
                xy = zeros(Nsamp, 2, obj.numSeeds * 2);
                for i = 1:obj.numSeeds
                    [xy(:,1,i),xy(:,2,i),~,~,~,~,xy(:,1,i+obj.numSeeds),xy(:,2,i+obj.numSeeds),~,~] ...
                        = sa_labs.util.BMARGSMv2(obj.tau,obj.sigma,obj.tauz,obj.sigmaz,dt,...
                        total_time,t_hex,obj.mosaicSpacing/sqrt(3)+obj.leeway,obj.Tburn, i + obj.seedStartValue - 1);
                end
            elseif strcmp(obj.motionTrajectory, 'natural')
                xy = zeros(Nsamp, 2, obj.numSeeds);
                for i = 1:obj.numSeeds
                    [xy(:,1,i),xy(:,2,i)] ...
                        = sa_labs.util.BMARGSMv2(obj.tau,obj.sigma,obj.tauz,obj.sigmaz,dt,...
                        total_time,t_hex,obj.mosaicSpacing/sqrt(3)+obj.leeway,obj.Tburn, i + obj.seedStartValue - 1);
                end
            else
                xy = zeros(Nsamp, 2, obj.numSeeds);
                for i = 1:obj.numSeeds
                    [~,~,~,~,~,~,xy(:,1,i),xy(:,2,i),~,~] ...
                        = sa_labs.util.BMARGSMv2(obj.tau,obj.sigma,obj.tauz,obj.sigmaz,dt,...
                        total_time,t_hex,obj.mosaicSpacing/sqrt(3)+obj.leeway,obj.Tburn, i + obj.seedStartValue - 1);
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
            
            mtype = obj.motionType(obj.numEpochsPrepared+1);
            obj.mo_ = mtype;

            if strcmp(obj.motionTrajectory,'natural+control+flash')
                mtype = obj.motionType(obj.numEpochsPrepared+1);
                if mtype == 1
                    epoch.addParameter('curMotionType', 'natural');
                    obj.i_ = seed - obj.seedStartValue + 1;
                elseif mtype == 0
                    epoch.addParameter('curMotionType', 'control');
                    obj.i_ = seed - obj.seedStartValue + 1 + obj.numSeeds;
                else
                    epoch.addParameter('curMotionType', 'flash');
                    obj.i_ = seed - obj.seedStartValue + 1 + 2 * obj.numSeeds;
                end
                fprintf('Using seed %d (%s [%d]): i = %d; +(%0.02f,%0.02f)\n', seed, epoch.parameters('curMotionType'), mtype, obj.i_, obj.tr_(1),obj.tr_(2));
            elseif strcmp(obj.motionTrajectory,'natural+control')
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
        
        function p = createPresentation(obj)            %% EDIT HERE
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
                if (obj.mo_ == 2) && ((state.frame+1) < obj.preFrames)
                    o = 0;
                end
            end
            objectOpacity = stage.builtin.controllers.PropertyController(object, 'opacity', @opacityController);
            p.addController(objectOpacity);
            
        end

        function totalNumEpochs = get.totalNumEpochs(obj) % sets num of epochs equal to user input value
            totalNumEpochs = obj.numRepeats * obj.numSeeds * ...
                (1 + strcmp(obj.motionTrajectory, 'natural+control') + ...
                2*strcmp(obj.motionTrajectory, 'natural+control+flash')) * obj.numTranslations; 
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

