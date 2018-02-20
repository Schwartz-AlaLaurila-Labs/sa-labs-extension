classdef FlashingDots < sa_labs.protocols.StageProtocol  & sa_labs.common.ProtocolLogger
    
    properties
        %times in ms
        preTime = 500                   % Spot leading duration (ms)
        stimTime = 500                  % Spot duration (ms)
        tailTime = 500                  % Spot trailing duration (ms)
        
        spotSize = 200;                 % spot diameter (um)
        spotSeparation = 300;           % spot separation (um)
        intensities = [0.25, 0.75];     % intensitites at each position
        numberOfCycles = 2              % repetitions of each pos/int
        randomOrdering = false;         % ramdom presentation order
        horizontalLine = false;         % false: circular / true: line
    end
    
    properties (Hidden)
        version = 1
        order                           % current presetnation order
        nFlashesPerCycle                % total number of flashes per cycle
        positionIntensityIds            % mapping to each pos/int
        positions                       % flash positions
        position                        % current position
        intensity                       % current intensity
        
        responsePlotMode = 'false';
        responsePlotSplitParameter = 'flashIdx';
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            % Generate spot locations
            % Five points along a line
            if obj.horizontalLine
                obj.positions = zeros(5, 2);
                obj.positions(:, 1) = (-2:1:2) * obj.spotSeparation;
            % or a circular flower pattern consisting of seven positions
            else
                obj.positions = zeros(7, 2);
                for i = 0:5
                    obj.positions(i+2, :) = ...
                        [cosd(i*60)*obj.spotSeparation,...
                         sind(i*60)*obj.spotSeparation];
                end
            end
                
            % Create matrix whose rows uniquely identify each posiible
            % position/intensity combination
            nPositions = size(obj.positions, 1);
            [posIds, intIds] = ...
                meshgrid(1:nPositions, 1:length(obj.intensities));
            obj.positionIntensityIds = [posIds(:), intIds(:)];
            obj.nFlashesPerCycle = size(obj.positionIntensityIds, 1);
            
            % Start with the default order
            obj.order = 1:obj.nFlashesPerCycle;
            
        end
            
        function prepareEpoch(obj, epoch)
            
            % Randomize the order if this is a new cycle
            index = mod(obj.numEpochsPrepared, obj.nFlashesPerCycle) + 1;
            if index == 1 && obj.randomOrdering
                obj.order = obj.order(randperm(obj.nFlashesPerCycle)); 
            end
            
            % Get the current position and intensity
            rowIdx = obj.order(index);
            posIdx = obj.positionIntensityIds(rowIdx, 1);
            intIdx = obj.positionIntensityIds(rowIdx, 2);
            obj.position = obj.positions(posIdx, :);
            obj.intensity = obj.intensities(intIdx);
            
            epoch.addParameter('position', obj.position);
            epoch.addParameter('intensity', obj.intensity);
            epoch.addParameter('flashIdx', rowIdx);
            
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
                        
        end     
      
        function p = createPresentation(obj)
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);

            spot = stage.builtin.stimuli.Ellipse();
            spot.radiusX = round(obj.um2pix(obj.spotSize / 2));
            spot.radiusY = spot.radiusX;
            spot.color = obj.intensity;
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spot.position = canvasSize / 2 + round(obj.um2pix(obj.position));
            spot.opacity = 1;
            p.addStimulus(spot);
            
            obj.setOnDuringStimController(p, spot);
            
            % shared code for multi-pattern objects
            obj.setColorController(p, spot);

        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.nFlashesPerCycle;
        end

    end
    
end

