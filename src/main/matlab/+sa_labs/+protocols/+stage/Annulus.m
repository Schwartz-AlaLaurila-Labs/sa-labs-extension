classdef Annulus < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 250                   % Annulus leading duration (ms)
        stimTime = 1000                 % Annulus duration (ms)
        tailTime = 500                 % Annulus trailing duration (ms)
        intensity = 1.0                 % Annulus light intensity (0-1)
        minInnerDiam = 10               % Minimum inner diameter of annulus (um)
        minOuterDiam = 200              % Minimum outer diameter of annulus  (um)
        maxInnerDiam = 400              % Maximum Inner diamater (um)
        numberOfSizeSteps = 10          % Number of steps
        numberOfCycles = 2              % Number of cycles through all annuli
        keepConstant = 'area'           % keep area (or) thickness as constant
    end
    
    properties (Hidden)
        displayName = 'Annulus';
        keepConstantType = symphonyui.core.PropertyType('char', 'row', {'area', 'thickness'})
        innerDiameterVector             % Annulus inner diameter vector, linearly spaced between minInnerDiam and minOuterDiam diameter for numberOfSizeSteps
        curInnerDiameter                % Annulus innner diameter for the current epoch @see prepare epoch
        curOuterDiameter                % Annulus outer diameter for the current epoch @see prepare epoch
    
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'curInnerDiameter';
    end
    
    
    properties (Dependent)
        initArea                        % Initial area
        maxOuterDiam                    % Maximum outer diameter
        initThick                       % Initial thickness
    end
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    methods
                
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);

            obj.innerDiameterVector = linspace(obj.minInnerDiam, obj.maxInnerDiam, obj.numberOfSizeSteps);
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spotDiameterPix = obj.um2pix(obj.curOuterDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            outerCircle = stage.builtin.stimuli.Ellipse();
            outerCircle.radiusX = spotDiameterPix/2;
            outerCircle.radiusY = spotDiameterPix/2;
            outerCircle.position = [canvasSize(1)/2,  canvasSize(2)/2];
            p.addStimulus(outerCircle);
            
            function i = onDuringStim(state)
                i = obj.meanLevel;
                if state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3
                    i = obj.intensity;
                end
            end
            
            outerVisible = stage.builtin.controllers.PropertyController(outerCircle, 'color', @(state)onDuringStim(state));
            p.addController(outerVisible);
            
            spotDiameterPix = obj.um2pix(obj.curInnerDiameter);
            
            innerCircle = stage.builtin.stimuli.Ellipse();
            innerCircle.radiusX = spotDiameterPix/2;
            innerCircle.radiusY = spotDiameterPix/2;
            innerCircle.color = obj.meanLevel;
            innerCircle.position = [canvasSize(1)/2,  canvasSize(2)/2];
            p.addStimulus(innerCircle);
            
%             obj.addFrameTracker(p);
        end
        
        function prepareEpoch(obj, epoch)            
            index = mod(obj.numEpochsPrepared, obj.numberOfSizeSteps);
            if index == 0
                obj.innerDiameterVector = obj.innerDiameterVector(randperm(obj.numberOfSizeSteps));
            end
            
            obj.curInnerDiameter = obj.innerDiameterVector(index+1);
            obj.curOuterDiameter = obj.getOuterDiameter(obj.curInnerDiameter);
            epoch.addParameter('curInnerDiameter', obj.curInnerDiameter);
            epoch.addParameter('curOuterDiameter', obj.curOuterDiameter);

            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfSizeSteps;
        end
        
        function diameter = getOuterDiameter(obj, d)
            
            if strcmp(obj.keepConstant, 'area');
                diameter = round(2 * sqrt((obj.initArea/pi) + (d./ 2) ^2));
            else
                diameter = d + obj.initThick * 2;
            end
        end
        
        function d = get.maxOuterDiam(obj)
            d = obj.getOuterDiameter(obj.maxInnerDiam);
        end
                
        function a = get.initArea(obj)
            a = pi*((obj.minOuterDiam/2) ^2 - (obj.minInnerDiam/2) ^2);
        end
        
        function initThick = get.initThick(obj)
            initThick = (obj.minOuterDiam - obj.minInnerDiam)/2;
        end
        
    end
end

