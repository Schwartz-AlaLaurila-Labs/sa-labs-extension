classdef SpotFieldAndChirpAndBars < sa_labs.protocols.StageProtocol

    properties
        chirpSize = 100
        spotSize = 30

        extentX = 60 %um
        extentY = 60 %um
        
        barLength = 600                 % Bar length size (um)
        barWidth = 200                  % Bar Width size (um)

        spotStimFrames = 15
        spotPreFrames = 15
        spotTailFrames = 45

        spotIntensity = .5
        chirpIntensity = .5
        barIntensity = .5

        gridMode = 'rings'
        coverage = .9069

        seed = -1                       % set to negative value to not use a seed, otherwise use a non-negative integer

        numberOfFields = 20
        numberOfChirps = 8
        numberOfBars = 2

        spotLED
        chirpLED
        barLED
    end
    
    properties (Hidden)
        chirpPattern = [];
        trialTypes = [];
        trialType = 0;
        numSpotsPerEpoch = NaN;
        
        cx = [];
        cy = [];
        grid = [];

        theta = [];

        % responsePlotMode = 'cartesian';
        % responsePlotSplitParameter = 'trialType';

        randStream

        responsePlotMode = false;

        barSpeed = 500; % um / s
%         barDistance = 1500; % um % derived based on 3s duration

        gridModeType = symphonyui.core.PropertyType('char', 'row', {'grid','random','rings'});
        
        % nSpotsPresented = 0;
    end
    
    properties (Dependent) 
        stimTime
        preTime
        tailTime

        RstarIntensitySpot
        MstarIntensitySpot
        SstarIntensitySpot
        
        RstarIntensityChirp
        MstarIntensityChirp
        SstarIntensityChirp
        
        RstarIntensityBar
        MstarIntensityBar
        SstarIntensityBar

    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        function obj = SpotFieldAndChirpAndBars(obj)
            obj@sa_labs.protocols.StageProtocol();
            obj.colorPattern1 = 'uv';
            obj.colorPattern2 = 'none';
            obj.spotLED = obj.uvLED;
            obj.chirpLED = obj.uvLED;
            obj.barLED = obj.uvLED;
        end


        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
            switch name
            case {'spotLED','chirpLED','barLED'}
                d.category = '7 Projector';
            case {'uvLED','redLED','greenLED','blueLED','RstarIntensity1','MstarIntensity1','SstarIntensity1'}
                d.isHidden = true;
            case {'coverage'}
                if obj.gridMode
                    d.isHidden = false;
                else
                    d.isHidden = true;
                end
            case {'RstarIntensitySpot','MstarIntensitySpot','SstarIntensitySpot',
                'RstarIntensityChirp','MstarIntensityChirp','SstarIntensityChirp',
                'RstarIntensityBar','MstarIntensityBar','SstarIntensityBar'}
                d.category = '6 Isomerizations';
            end

        end
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);

            dt = 1/obj.frameRate; % assume frame rate in Hz
            
            % *0.001 is to make in terms of seconds
            prePattern = zeros(1, round(2*obj.frameRate));
            interPattern = ones(1, round(2*obj.frameRate))*obj.chirpIntensity;
            tailPattern = zeros(1, round(5*obj.frameRate));
            posStepPattern = ones(1, round(3*obj.frameRate))*2*obj.chirpIntensity;
            negStepPattern = zeros(1, round(3*obj.frameRate));
            
            freqT = dt:dt:8;
            freqChange = linspace(0, 8, length(freqT));
            freqPhase = cumsum(freqChange*dt);
            freqPattern = obj.chirpIntensity*-sin(2*pi*freqPhase + pi) + obj.chirpIntensity;
            
            contrastT = dt:dt:8;
            contrastChange = linspace(0, 1, length(contrastT));
            contrastPattern = contrastChange.*obj.chirpIntensity.*-sin(4*pi.*contrastT + pi) + obj.chirpIntensity;

            obj.chirpPattern = [prePattern, posStepPattern, negStepPattern, interPattern...
                freqPattern, interPattern, contrastPattern, interPattern, tailPattern];


            obj.theta = linspace(0,2*pi,11);
            obj.theta(end) = [];
            
            obj.numSpotsPerEpoch = floor(35 * obj.frameRate / (obj.spotPreFrames + obj.spotStimFrames + obj.spotTailFrames));

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
                
                if obj.numSpotsPerEpoch > size(obj.grid,1)
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
                
            end

            if obj.seed >= 0
                obj.randStream = RandStream('mt19937ar','seed',obj.seed);
            else
                obj.randStream = RandStream.getGlobalStream();
            end

            obj.trialTypes = vertcat(zeros(obj.numberOfChirps,1), ones(obj.numberOfFields,1), 2*ones(obj.numberOfBars,1));
            obj.trialTypes = obj.trialTypes(randperm(obj.randStream, length(obj.trialTypes)));

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
        end
        
        function prepareEpoch(obj, epoch)
            index = obj.numEpochsPrepared + 1;
            obj.trialType = obj.trialTypes(index);
            if obj.trialType == 1
                epoch.addParameter('trialType', 'field');
                if strcmp(obj.gridMode,'random')                    
                    obj.cx = rand(obj.randStream, obj.numSpotsPerEpoch, 1) * obj.extentX - obj.extentX/2;
                    obj.cy = rand(obj.randStream, obj.numSpotsPerEpoch, 1) * obj.extentY - obj.extentY/2;
                else
                    spots = randperm(obj.randStream, size(obj.grid,1), obj.numSpotsPerEpoch);
                    %would be better to do a complete permutation...
                    obj.cx = obj.grid(spots,1);
                    obj.cy = obj.grid(spots,2);
                end

                epoch.addParameter('cx', obj.cx);
                epoch.addParameter('cy', obj.cy);
                
            elseif obj.trialType == 2
                epoch.addParameter('trialType', 'bars');

                obj.theta = obj.theta(randperm(length(obj.theta)));

                epoch.addParameter('theta', obj.theta)

            else
                epoch.addParameter('trialType', 'chirp');
            end

            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        function controllerDidStartHardware(obj)
            
            lightCrafter = obj.rig.getDevice('LightCrafter');
            if obj.trialType == 1
                LED = obj.spotLED;
            elseif obj.trialType == 2
                LED = obj.barLED;
            else
                LED = obj.chirpLED;
            end
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
            
            nFrames = numel(obj.chirpPattern);            
            chirpPattern_ = obj.chirpPattern;
            function i = getChirpIntensity(state)
                %clip the time axis to [1, T]
                frame=max(1, min(state.frame+1, nFrames));
                i = chirpPattern_(frame);
            end

            spotPre = obj.spotPreFrames;
            spotPreStim = obj.spotPreFrames+ obj.spotStimFrames;
            spotPreStimPost = obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames;
            function xy = getSpotPosition(state)
                i = min(floor(state.frame / spotPreStimPost) + 1, length(cx_));
                % i = min(mod(state.frame, obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames) + 1, length(obj.cx));
                
                % canvasSize / 2 + self.um2pix(self.currSpot(1:2));
                xy = canvasSize/2 + [cx_(i); cy_(i)];
            end
            
            sI = obj.spotIntensity;
            function c = getSpotIntensity(state)
                if state.frame >= (nFrames - 1)
                    c = 0;
                    return
                end
                
                i = mod(state.frame, spotPreStimPost);

                if (i < spotPre) || (i >= spotPreStim)
                    c = 0;
                else
                    c = sI;
                end
            end
            
            bI = obj.barIntensity;
            function c = getBarIntensity(state)
                if state.frame >= (nFrames - 1)
                    c = 0;
                    return
                end

                i = mod(state.frame, 210); % TODO: this assumes frame rate of 60
                if (i < 15) || (i >= 195)
                    c = 0;
                else
                    c = bI;
                end

            end

            [~, pixelSpeed] = obj.um2pix(obj.barSpeed); %pix/s
            pixelSpeed = pixelSpeed / obj.frameRate; % pix/frame
            % [~, pixelDistance] = obj.um2pix(obj.barDistance); %pix
            pixelDistance = pixelSpeed * 3; %pix, assumes 3 seconds
            xStep = pixelSpeed * cos(obj.theta);
            yStep = pixelSpeed * sin(obj.theta);

            xStartPos = canvasSize(1)/2 - (pixelDistance / 2) * cos(obj.theta);
            yStartPos = canvasSize(2)/2 - (pixelDistance / 2) * sin(obj.theta);
           

            function xy = getBarPosition(state)
                xy = [NaN, NaN];

                i = mod(state.frame, 210); % TODO: this assumes frame rate of 60
                t = floor(state.frame / 210) + 1;

                if i >= 15 && i < 195 %i.e., 3sec per bar
                    xy = [xStartPos(t) + (i-15) * xStep(t), yStartPos(t) + (i-15) * yStep(t)];
                end
            end
            
            theta_ = rad2deg(obj.theta);
            function th = getBarOrientation(state)
                t = floor(state.frame / 210) + 1;
                th = theta_(t);
            end

            p = stage.core.Presentation(35);

            if obj.trialType == 1 % grid
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
            elseif obj.trialType == 2
                bar = stage.builtin.stimuli.Rectangle();

                bar.color = 0;
                bar.opacity = 1;
                % bar.orientation = obj.barAngle;
                [~, barLength_] = obj.um2pix(obj.barLength);
                [~, barWidth_] = obj.um2pix(obj.barWidth);
                bar.size = [barLength_, barWidth_];
                p.addStimulus(bar);

                barIntensity_ = stage.builtin.controllers.PropertyController(bar, 'color',...
                    @(state)getBarIntensity(state));
                barPosition = stage.builtin.controllers.PropertyController(bar, 'position',...
                    @(state)getBarPosition(state));
                barOrientation = stage.builtin.controllers.PropertyController(bar, 'orientation',...
                    @(state)getBarOrientation(state));
                    

                p.addController(barIntensity_);
                p.addController(barPosition);
                p.addController(barOrientation);
            else %chirp
                spot = stage.builtin.stimuli.Ellipse();
            
                [~,spot.radiusX] = obj.um2pix(obj.chirpSize / 2);
                spot.radiusY = spot.radiusX;
                spot.opacity = 1;
                spot.color = 0;
                spot.position = canvasSize/2;
                spotIntensity_ = stage.builtin.controllers.PropertyController(spot, 'color',...
                    @(state)getChirpIntensity(state));                    
                
                p.addStimulus(spot);
                p.addController(spotIntensity_);
            end

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
            totalNumEpochs = obj.numberOfChirps + obj.numberOfFields + obj.numberOfBars;
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

        function RstarIntensity = get.RstarIntensityChirp(obj)
            params = obj.isomerizationParameters();
            params.uvLED = obj.chirpLED;
            [RstarIntensity, ~, ~] = obj.convertIntensityToIsomerizations(obj.chirpIntensity, 'uv', params);
        end
        
        function MstarIntensity = get.MstarIntensityChirp(obj)
            params = obj.isomerizationParameters();
            params.uvLED = obj.chirpLED;
            [~, MstarIntensity, ~] = obj.convertIntensityToIsomerizations(obj.chirpIntensity, 'uv', params);
        end
        
        function SstarIntensity = get.SstarIntensityChirp(obj)
            params = obj.isomerizationParameters();
            params.uvLED = obj.chirpLED;
            [~, ~, SstarIntensity] = obj.convertIntensityToIsomerizations(obj.chirpIntensity, 'uv', params);
        end

        function RstarIntensity = get.RstarIntensityBar(obj)
            params = obj.isomerizationParameters();
            params.uvLED = obj.barLED;
            [RstarIntensity, ~, ~] = obj.convertIntensityToIsomerizations(obj.barIntensity, 'uv', params);
        end
        
        function MstarIntensity = get.MstarIntensityBar(obj)
            params = obj.isomerizationParameters();
            params.uvLED = obj.barLED;
            [~, MstarIntensity, ~] = obj.convertIntensityToIsomerizations(obj.barIntensity, 'uv', params);
        end
        
        function SstarIntensity = get.SstarIntensityBar(obj)
            params = obj.isomerizationParameters();
            params.uvLED = obj.barLED;
            [~, ~, SstarIntensity] = obj.convertIntensityToIsomerizations(obj.barIntensity, 'uv', params);
        end

    end
    
end