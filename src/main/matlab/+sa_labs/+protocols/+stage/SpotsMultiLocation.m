classdef SpotsMultiLocation < sa_labs.protocols.StageProtocol
properties
    % chirpSize = 100
    
    spotSize = 30

    extentX = 200 %um
    extentY = 200 %um
    
    % barLength = 600                 % Bar length size (um)
    % barWidth = 200                  % Bar Width size (um)

    spotStimFrames = 15
    spotPreFrames = 15
    spotTailFrames = 45

    intensity = 0.5
    % spotIntensity = .5
    % chirpIntensity = .5
    % barIntensity = .5
    % TODO: need to set the obj.intensity to match stimulus type every
    % epoch

    numberOfFields = 20
    % numberOfChirps = 0
    % numberOfBars = 0

    gridMode = true
    coverage =.9069                 % For grid mode. No overlap in spots if .9069 or lower. Represents the number of spots which intersect the average pixel.
    
    %TODO: calculate spot spacing

    seed = -1                       % non-negative integer, or negative to use global seed

    % spotLED
    % chirpLED
    % barLED
end
properties (Hidden)

    chirpPattern = [];
    trialTypes = [];
    trialType = 0;

    cx = [];
    cy = [];

    grid = [];

    randStream

    % theta = [];

    responsePlotMode = false;

    % barSpeed = 1000 % um / s
    % barDistance = 3000 % um
end

properties (Dependent) 
    stimTime
    preTime
    tailTime

    % RstarIntensitySpot
    % MstarIntensitySpot
    % SstarIntensitySpot
    
    % RstarIntensityChirp
    % MstarIntensityChirp
    % SstarIntensityChirp
    
    % RstarIntensityBar
    % MstarIntensityBar
    % SstarIntensityBar
    
    numSpotsPerEpoch
    
    spotOverlap % For grid mode. The amount of overlap between neighboring spots along the diameter, in um. Adjust the coverage factor or spot size to change.

end

properties (Hidden, Dependent)
    totalNumEpochs
end

methods

    function d = getPropertyDescriptor(obj, name)
        d = getPropertyDescriptor@sa_labs.protocols.StageProtocol(obj, name);
        switch name
        % case {'spotLED','chirpLED','barLED'}
        %     d.category = '7 Projector';
        % case {'uvLED','redLED','greenLED','blueLED','RstarIntensity1','MstarIntensity1','SstarIntensity1'}
        %     d.isHidden = true;
        case {'coverage'}
            if obj.gridMode
                d.isHidden = false;
            else
                d.isHidden = true;
            end
        % case {'RstarIntensitySpot','MstarIntensitySpot','SstarIntensitySpot',
        %     'RstarIntensityChirp','MstarIntensityChirp','SstarIntensityChirp',
        %     'RstarIntensityBar','MstarIntensityBar','SstarIntensityBar'}
        %     d.category = '6 Isomerizations';
        end

    end

    function prepareRun(obj)
        prepareRun@sa_labs.protocols.StageProtocol(obj);

        % dt = 1/obj.frameRate; % assume frame rate in Hz
        
        % % *0.001 is to make in terms of seconds
        % prePattern = zeros(1, round(2*obj.frameRate));
        % interPattern = ones(1, round(2*obj.frameRate))*obj.chirpIntensity;
        % tailPattern = zeros(1, round(5*obj.frameRate));
        % posStepPattern = ones(1, round(3*obj.frameRate))*2*obj.chirpIntensity;
        % negStepPattern = zeros(1, round(3*obj.frameRate));
        
        % freqT = dt:dt:8;
        % freqChange = linspace(0, 8, length(freqT));
        % freqPhase = cumsum(freqChange*dt);
        % freqPattern = obj.chirpIntensity*-sin(2*pi*freqPhase + pi) + obj.chirpIntensity;
        
        % contrastT = dt:dt:8;
        % contrastChange = linspace(0, 1, length(contrastT));
        % contrastPattern = contrastChange.*obj.chirpIntensity.*-sin(4*pi.*contrastT + pi) + obj.chirpIntensity;

        % obj.chirpPattern = [prePattern, posStepPattern, negStepPattern, interPattern...
        %     freqPattern, interPattern, contrastPattern, interPattern, tailPattern];


        % obj.theta = linspace(0,2*pi,11);
        % obj.theta(end) = [];
        
        
        if obj.gridMode
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

        end

        if obj.seed >= 0
            obj.randStream = RandStream('mt19937ar','seed',obj.seed);
        else
            obj.randStream = RandStream.getGlobalStream();
            obj.seed = obj.randStream.Seed;
        end

        % obj.trialTypes = vertcat(zeros(obj.numberOfChirps,1), ones(obj.numberOfFields,1), 2*ones(obj.numberOfBars,1));
        % obj.trialTypes = obj.trialTypes(randperm(obj.randStream, length(obj.trialTypes)));

        devices = {};
        modes = {};
        for ci = 1:4
            ampName = obj.(['chan' num2str(ci)]);
            ampMode = obj.(['chan' num2str(ci) 'Mode']);
            if ~(strcmp(ampName, 'None') || strcmp(ampMode, 'Off'));
                device = obj.rig.getDevice(ampName);
                devices{end+1} = device; %#ok<AGROW>
                modes{end+1} = ampMode; %#ok<AGROW>
            end
        end

        obj.showFigure('sa_labs.figures.SpotsMultiLocationFigure', devices, modes, ...
                'totalNumEpochs', obj.totalNumEpochs,...
                'preTime', obj.spotPreFrames / obj.frameRate,...
                'stimTime', obj.spotStimFrames / obj.frameRate,...
                'tailTime', obj.spotTailFrames / obj.frameRate,...
                'spotsPerEpoch', obj.numSpotsPerEpoch, ...
                'spikeThreshold', obj.spikeThreshold, 'spikeDetectorMode', obj.spikeDetectorMode); 
    end

    function prepareEpoch(obj, epoch)
        % index = obj.numEpochsPrepared + 1;
        % obj.trialType = obj.trialTypes(index);
        % if obj.trialType == 1
        epoch.addParameter('trialType', 'field');

        if obj.gridMode
            gridSize = size(obj.grid,1);
            if gridSize < obj.numSpotsPerEpoch
                nPerms = ceil(obj.numSpotsPerEpoch / gridSize);
                spots = zeros(gridSize * nPerms,1);
                for n = 1:nPerms
                    spots((1+gridSize*(n-1)):(gridSize*n)) = randperm(obj.randStream, gridSize);
                end
            else
                spots = randperm(obj.randStream, gridSize, obj.numSpotsPerEpoch);
            end
            obj.cx = obj.grid(spots,1);
            obj.cy = obj.grid(spots,2);
        else
            obj.cx = rand(obj.randStream, obj.numSpotsPerEpoch, 1) * obj.extentX - obj.extentX/2;
            obj.cy = rand(obj.randStream, obj.numSpotsPerEpoch, 1) * obj.extentY - obj.extentY/2;
        end

        epoch.addParameter('cx', obj.cx);
        epoch.addParameter('cy', obj.cy);
            
        % elseif obj.trialType == 2
        %     epoch.addParameter('trialType', "bars");

        %     obj.theta = obj.theta(randperm(length(obj.theta)));

        %     epoch.addParameter('theta', obj.theta)

        % else
        %     epoch.addParameter('trialType', "chirp");
        % end

        % Call the base method.
        prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);

    end

    function p = createPresentation(obj)
            
        canvasSize = reshape(obj.rig.getDevice('Stage').getCanvasSize(),2,1);
        [~,cx_] = obj.um2pix(obj.cx);
        [~,cy_] = obj.um2pix(obj.cy);
        
        % nFrames = numel(obj.chirpPattern);            
        % chirpPattern_ = obj.chirpPattern;
        % function i = getChirpIntensity(state)
        %     %clip the time axis to [1, T]
        %     frame=max(1, min(state.frame+1, nFrames));
        %     i = chirpPattern_(frame);
        % end

        spotPre = obj.spotPreFrames;
        spotPreStim = obj.spotPreFrames+ obj.spotStimFrames;
        spotPreStimPost = obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames;
        grid_ = repmat(canvasSize/2,1,length(cx_)) + [cx_, cy_]';
        function xy = getSpotPosition(state, spotPreStimPost, grid)
            i = min(floor(state.frame / spotPreStimPost) + 1, size(grid, 2));
            % i = min(mod(state.frame, obj.spotPreFrames+ obj.spotStimFrames + obj.spotTailFrames) + 1, length(obj.cx));
            
            % canvasSize / 2 + obj.um2pix(obj.currSpot(1:2));
%             xy = canvasSize/2 + [cx_(i); cy_(i)];
            xy = grid(:,i);
        end
        
        sI = obj.intensity;
        bg = obj.meanLevel;
        nFrames = obj.frameRate * 35;
        function c = getSpotIntensity(state, spotPre, spotPreStim, spotPreStimPost, intensity_, bg_, nFrames_)
            if state.frame >= nFrames_ - 1
                c = bg_;
                return
            end
            
            i = mod(state.frame, spotPreStimPost);

            if (i < spotPre) || (i >= spotPreStim)
                c = bg_;
            else
                c = intensity_;
            end
        end
        
        % bI = obj.barIntensity;
        % function c = getBarIntensity(state)
        %     if state.frame >= nFrames - 1
        %         c = 0;
        %         return
        %     end

        %     i = mod(state.frame, 210); % TODO: this assumes frame rate of 60 / bar speed 1mm/s
        %     if i < 15 || i >= 195
        %         c = 0;
        %     else
        %         c = bI;
        %     end

        % end

        % [~, pixelSpeed] = obj.um2pix(obj.barSpeed); %pix/s
        % pixelSpeed = pixelSpeed / obj.frameRate; % pix/frame
        % [~, pixelDistance] = obj.um2pix(obj.barDistance); %pix
        % xStep = pixelSpeed * cos(obj.theta);
        % yStep = pixelSpeed * sin(obj.theta);

        % xStartPos = canvasSize(1)/2 - (pixelDistance / 2) * cos(obj.theta);
        % yStartPos = canvasSize(2)/2 - (pixelDistance / 2) * sin(obj.theta);
       

        % function xy = getBarPosition(state)
        %     xy = [NaN, NaN];

        %     i = mod(state.frame, 210); % TODO: this assumes frame rate of 60 / bar speed 1mm/s
        %     t = floor(state.frame / 210) + 1;

        %     if i >= 15 && i < 195
        %         xy = [xStartPos(t) + (i-15) * xStep(t), yStartPos(t) + (i-15) * yStep(t)];
        %     end
        % end
        
        % theta_ = rad2deg(obj.theta);
        % function th = getBarOrientation(state)
        %     t = floor(state.frame / 210) + 1;
        %     th = theta_(t);
        % end

        p = stage.core.Presentation(35);

        % if obj.trialType == 1 % grid
        spot = stage.builtin.stimuli.Ellipse();
    
        [~,spot.radiusX] = obj.um2pix(obj.spotSize / 2);
        spot.radiusY = spot.radiusX;
        spot.opacity = 1;
        spot.color = 0;
        
        p.addStimulus(spot);
        
        spotIntensity_ = stage.builtin.controllers.PropertyController(spot, 'color',...
            @(state)getSpotIntensity(state, spotPre, spotPreStim, spotPreStimPost, sI, bg, nFrames));
%         getSpotIntensity(state, spotPre, spotPreStim, spotPreStimPost, intensity)
        spotPosition = stage.builtin.controllers.PropertyController(spot, 'position',...
            @(state)getSpotPosition(state, spotPreStimPost, grid_));

        p.addController(spotIntensity_);
        p.addController(spotPosition);
        % elseif obj.trialType == 2
        %     bar = stage.builtin.stimuli.Rectangle();

        %     bar.color = 0;
        %     bar.opacity = 1;
        %     % bar.orientation = obj.barAngle;
        %     [~, barLength_] = obj.um2pix(obj.barLength);
        %     [~, barWidth_] = obj.um2pix(obj.barWidth);
        %     bar.size = [barLength_, barWidth_];
        %     p.addStimulus(bar);

        %     barIntensity_ = stage.builtin.controllers.PropertyController(bar, 'color',...
        %         @(state)getBarIntensity(state));
        %     barPosition = stage.builtin.controllers.PropertyController(bar, 'position',...
        %         @(state)getBarPosition(state));
        %     barOrientation = stage.builtin.controllers.PropertyController(bar, 'orientation',...
        %         @(state)getBarOrientation(state));
                

        %     p.addController(barIntensity_);
        %     p.addController(barPosition);
        %     p.addController(barOrientation);
        % else %chirp
        %     spot = stage.builtin.stimuli.Ellipse();
        
        %     [~,spot.radiusX] = obj.um2pix(obj.chirpSize / 2);
        %     spot.radiusY = spot.radiusX;
        %     spot.opacity = 1;
        %     spot.color = 0;
        %     spot.position = canvasSize/2;
        %     spotIntensity_ = stage.builtin.controllers.PropertyController(spot, 'color',...
        %         @(state)getChirpIntensity(state));                    
            
        %     p.addStimulus(spot);
        %     p.addController(spotIntensity_);
        % end

    end

    function preTime = get.preTime(obj)
        preTime = 0;
    end
    
    function tailTime = get.tailTime(obj)
        tailTime = 0;
    end

    function stimTime = get.stimTime(obj)
        stimTime = 35000;
    end

    function totalNumEpochs = get.totalNumEpochs(obj)
        % totalNumEpochs = obj.numberOfChirps + obj.numberOfFields + obj.numberOfBars;
        totalNumEpochs = obj.numberOfFields;
    end
    
    function numSpotsPerEpoch = get.numSpotsPerEpoch(obj)
        numSpotsPerEpoch = floor(35 * obj.frameRate / (obj.spotPreFrames + obj.spotStimFrames + obj.spotTailFrames));
    end
    
    function spotOverlap = get.spotOverlap(obj)
        spaceFactor = sqrt(3*pi/4 / obj.coverage / (3*sqrt(3)/2));
        %spot diameter - distance between spot centers in microns
        spotOverlap = obj.spotSize* (1 - spaceFactor);
       
    end

end

end