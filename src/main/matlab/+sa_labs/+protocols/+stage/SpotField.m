classdef SpotField < sa_labs.protocols.StageProtocol

    properties
        spotSize = 30

        extentX = 60 %um
        extentY = 60 %um
        
        arms = 6; %only for radial
        spotsPerArm = 6; %only for radial

        spotStimFrames = 15
        spotPreFrames = 15
        spotTailFrames = 45

        spotIntensity = .5
        n_intensities = 4; %we do this on a log scale by taking n-1 halvings of spotIntensity

        gridMode = 'radial'
        coverage = .9069

        seed = -1                       % set to negative value to not use a seed, otherwise use a non-negative integer

        numberOfFields = 20

        spotLED
    end
    
    properties (Hidden)
        numSpotsPerEpoch = NaN;
        
        cx = [];
        cy = [];
        grid = [];

        theta = [];

        % responsePlotMode = 'cartesian';
        % responsePlotSplitParameter = 'trialType';

        randStream

        responsePlotMode = false;

        gridModeType = symphonyui.core.PropertyType('char', 'row', {'grid','random','rings','radial'});
        
        % nSpotsPresented = 0;
    end
    
    properties (Dependent) 
        stimTime
        preTime
        tailTime

        RstarIntensitySpot
        MstarIntensitySpot
        SstarIntensitySpot

    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        function obj = SpotField(obj)
            obj@sa_labs.protocols.StageProtocol();
            obj.colorPattern1 = 'uv';
            obj.colorPattern2 = 'none';
            obj.spotLED = obj.uvLED;
        end


        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            switch name
            case 'spotLED'
                d.category = '7 Projector';
            case {'uvLED','redLED','greenLED','blueLED','RstarIntensity1','MstarIntensity1','SstarIntensity1'}
                d.isHidden = true;
            case {'coverage'}
                if obj.gridMode
                    d.isHidden = false;
                else
                    d.isHidden = true;
                end
            case {'RstarIntensitySpot','MstarIntensitySpot','SstarIntensitySpot'}
                d.category = '6 Isomerizations';
            end

        end
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);

            dt = 1/obj.frameRate; % assume frame rate in Hz
            
            % *0.001 is to make in terms of seconds

            obj.theta = linspace(0,2*pi,11);
            obj.theta(end) = [];
            if obj.n_intensities > 1
                obj.intesity_vec = 2.^linspace(log2(obj.spotIntensity)-obj.n_intensities+1,log2(obj.spotIntensity),obj.n_intensities);
            else
                obj.intesity_vec = obj.spotIntensity;
            end
            
            obj.numSpotsPerEpoch = floor(36 * obj.frameRate / (obj.spotPreFrames + obj.spotStimFrames + obj.spotTailFrames));
            
            if strcmp(obj.gridMode,'grid')
                %space the spots to achieve the desired coverage factor
                %uses the ratio of the area of a hexagon to that of a circle
                spaceFactor = sqrt(3*pi/4 / obj.coverage / (3*sqrt(3)/2));
                spacing = spaceFactor * obj.spotSize;
    
                %find the x and y coordinates for the hex grid
                xa = [0:-spacing:-obj.extentX/2-spacing, spacing:spacing:obj.extentX/2+spacing];
                xb= [xa - spacing/2, xa(end)+spacing/2];
                yspacing = cos(pi/6)*spacing;
                ya = [0:-2*yspacing:-obj.extentY/2-yspacing, 2*yspacing:2*yspacing:obj.extentY/2+yspacing];
                yb = [ya - yspacing, ya(end) + yspacing];
    
                %create the grid
                [xqa, yqa] = meshgrid(xa,ya);
                [xqb, yqb] = meshgrid(xb,yb);
                locs = [xqa(:), yqa(:); xqb(:), yqb(:)];
    
                halfGrids = [obj.extentX, obj.extentY]/2;
                %remove any circles that don't intersect the grid rectangle
                % 1) the bounding box of the circle must intersect the rectangle
                locs = locs(all(abs(locs) < repmat(halfGrids, size(locs,1),1) + obj.spotSize/2, 2), :);
    
                % 2) circles near the corners might have an intersecting
                %       bounding box but not actually intersect
                % - if either of the coordinates is inside the box, it
                %       definitely intersects
                % - otherwise it must intersect the corner
                halfGrids = repmat(halfGrids, size(locs,1),1);
                obj.grid = locs(any(abs(locs) < halfGrids, 2) | 4*sum((abs(locs)-halfGrids).^2,2) <= obj.spotSize.^2 , :);
                
                %repmat by n_intensities
                obj.grid = repmat(obj.grid, obj.n_intensities, 1);
                
                %make intensity vec
                grid_size = size(obj.grid,1);
                obj.spot_intesnity_vec = repmat(obj.intesity_vec,1,ceil(grid_size/obj.n_intensities));
                obj.spot_intesnity_vec = obj.spot_intesnity_vec(1:grid_size);
                
                if obj.numSpotsPerEpoch > size(obj.grid,1)
                    obj.spot_intesnity_vec =  repmat(obj.spot_intesnity_vec, ceil(obj.numSpotsPerEpoch / size(obj.grid,1)), 1);
                    obj.grid = repmat(obj.grid, ceil(obj.numSpotsPerEpoch / size(obj.grid,1)), 1);                    
                end
                
            elseif strcmp(obj.gridMode,'rings')
                N = cumsum([6, 10, 14, 8, 16, 30]);
                R = [8, 9, 12, 22, 24, 28] / 60; % * obj.extentX;
                obj.grid = [];
                for i = 1:numel(N)
                    th = linspace(0, 2*pi, N(i) + 1)';
                    obj.grid = vertcat(obj.grid, R(i)*[cos(th(1:end-1)), sin(th(1:end-1))]);
                end
                obj.grid(:,1) = obj.grid(:,1) * obj.extentX;
                obj.grid(:,2) = obj.grid(:,2) * obj.extentY;
            elseif strcmp(obj.gridMode,'radial') 
                    angles = linspace(0,2*pi,obj.arms+1);
                    angles = angles(1:obj.arms);
                    
                    arm_spots = linspace(0, obj.extentX, obj.spotsPerArm);
                
                    N = obj.arms * obj.spotsPerArm;
                    obj.grid = zeros(N,2);
                    for i=1:obj.arms
                        for j=1:obj.spotsPerArm
                            [x, y] = pol2cart(angles(i), arm_spots(j));
                            obj.grid((i-1)*obj.spotsPerArm+j,1) = x;
                            obj.grid((i-1)*obj.spotsPerArm+j,2) = y;
                        end
                    end 
                    size(obj.grid)
            end

            if obj.seed >= 0
                obj.randStream = RandStream('mt19937ar','seed',obj.seed);
            else
                obj.randStream = RandStream.getGlobalStream();
            end

            devices = {};
            modes = {};
            for ci = 1:4
                ampName = obj.(['chan' num2str(ci)]);
                ampMode = obj.(['chan' num2str(ci) 'Mode']);
                if ~(strcmp(ampName, 'None') || strcmp(ampMode, 'Off'))
                    device = obj.rig.getDevice(ampName);
                    devices{end+1} = device; %#ok<AGROW>
                    modes{end+1} = ampMode;
                end
            end

            obj.responseFigure = obj.showFigure('sa_labs.figures.SpotsMultiLocationFigure', devices, modes, ...
                    'totalNumEpochs', obj.totalNumEpochs,...
                    'preTime', obj.spotPreFrames / obj.frameRate,...
                    'stimTime', obj.spotStimFrames / obj.frameRate,...
                    'tailTime', obj.spotTailFrames / obj.frameRate,...
                    'spotsPerEpoch', obj.numSpotsPerEpoch, ...
                    'spikeThreshold', obj.spikeThreshold, 'spikeDetectorMode', obj.spikeDetectorMode);
                
            total_spots = obj.numSpotsPerEpoch * obj.totalNumEpochs;
            num_repeats = ceil(total_spots / size(obj.grid,1));
            total_spots_up = num_repeats * size(obj.grid,1);
            spot_index = mod(0:total_spots_up-1, size(obj.grid,1)) + 1; % 1...77, 1...77, 1...77, ...., 1...77
            rand_index = randperm(obj.randStream, total_spots_up, total_spots);
            obj.grid = obj.grid(spot_index(rand_index), :);
            
         end
        
        function prepareEpoch(obj, epoch)
            si = obj.numEpochsPrepared * obj.numSpotsPerEpoch + 1 : (obj.numEpochsPrepared+1) * obj.numSpotsPerEpoch;
            if strcmp(obj.gridMode,'random')                
                obj.cx = rand(obj.randStream, obj.numSpotsPerEpoch, 1) * obj.extentX - obj.extentX/2;
                obj.cy = rand(obj.randStream, obj.numSpotsPerEpoch, 1) * obj.extentY - obj.extentY/2;
            else                %would be better to do a complete permutation...                
                obj.cx = obj.grid(si,1);
                obj.cy = obj.grid(si,2);
                obj.current_spot_intensity = obj.spot_intesnity_vec(si);
            end
            
            epoch.addParameter('cx', obj.cx);
            epoch.addParameter('cy', obj.cy);
            epoch.addParameter('current_spot_intensity', obj.current_spot_intensity);

            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function controllerDidStartHardware(obj)
            lightCrafter = obj.rig.getDevice('LightCrafter');
            LED = obj.spotLED;
            lightCrafter.setLedCurrents(0, 0, 0, LED);
            controllerDidStartHardware@sa_labs.protocols.StageProtocol(obj);
        end

        function completeRun(obj)
            lightCrafter = obj.rig.getDevice('LightCrafter');
            lightCrafter.setLedCurrents(0, 0, 0, obj.spotLED); %final level is deterministic
            completeRun@sa_labs.protocols.StageProtocol(obj);
        end

        function p = createPresentation(obj)
            
            canvasSize = reshape(obj.rig.getDevice('Stage').getCanvasSize(),2,1);
            [~,cx_] = obj.um2pix(obj.cx);
            [~,cy_] = obj.um2pix(obj.cy);
                       
            spotPre = obj.spotPreFrames;
            spotPreStim = obj.spotPreFrames+ obj.spotStimFrames;
            spotPreStimPost = obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames;
                        
            function xy = getSpotPosition(state)
                i = min(floor(state.frame / spotPreStimPost) + 1, length(cx_));
                % i = min(mod(state.frame, obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames) + 1, length(obj.cx));
                
                % canvasSize / 2 + self.um2pix(self.currSpot(1:2));
                xy = canvasSize/2 + [cx_(i); cy_(i)];
            end
            
            sI = obj.current_spot_intensity;
            function c = getSpotIntensity(state)
                i = mod(state.frame, spotPreStimPost);
                if (i < spotPre) || (i >= spotPreStim)
                    c = 0;
                else
                    c = sI;
                end
            end
            
            p = stage.core.Presentation(36);

                spot = stage.builtin.stimuli.Ellipse();
            
                [~,spot.radiusX] = obj.um2pix(obj.spotSize / 2);
                spot.radiusY = spot.radiusX;
                spot.opacity = 1;
                spot.color = 0;
                
                spotIntensity_ = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getSpotIntensity(state));
                spotPosition = stage.builtin.controllers.PropertyController(spot, 'position',...
                    @(state)getSpotPosition(state));
                
                p.addStimulus(spot);

                p.addController(spotIntensity_);
                p.addController(spotPosition);

        end

        function preTime = get.preTime(~)
            % if strcmp(obj.trialType,'chirp')
            %     preTime = 2000;
            % else
                preTime = 0;
            % end
        end
        
        function tailTime = get.tailTime(~)
            % if strcmp(obj.trialType,'chirp')
            %     tailTime = 2000;
            % else
                tailTime = 0;
            % end
        end

        function stimTime = get.stimTime(~)
            
            % if strcmp(obj.trialType,'chirp')
                stimTime = 35000;
            % else
            %     stimTime = obj.spotCountInX * obj.spotCountInY * (obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames) / obj.frameRate * 1e3;
            % end
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfFields;
        end
        
        function RstarIntensity = get.RstarIntensitySpot(obj)
            params = obj.isomerizationParameters();
            params.uvLED = obj.spotLED;
            [RstarIntensity, ~, ~] = obj.convertIntensityToIsomerizations(obj.spotIntensity, 'uv', params);
        end
        
        function MstarIntensity = get.MstarIntensitySpot(obj)
            params = obj.isomerizationParameters();
            params.uvLED = obj.spotLED;
            [~, MstarIntensity, ~] = obj.convertIntensityToIsomerizations(obj.spotIntensity, 'uv', params);
        end
        
        function SstarIntensity = get.SstarIntensitySpot(obj)
            params = obj.isomerizationParameters();
            params.uvLED = obj.spotLED;
            [~, ~, SstarIntensity] = obj.convertIntensityToIsomerizations(obj.spotIntensity, 'uv', params);
        end

    end
    
end