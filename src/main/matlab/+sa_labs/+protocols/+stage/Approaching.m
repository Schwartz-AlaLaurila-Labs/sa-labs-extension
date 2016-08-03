classdef Approaching < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500 %will be rounded to account for frame rate
        tailTime = 1000 %will be rounded to account for frame rate
        %stimTime = 2000; % = static+changing
        staticTimePre = 1000;
        dynamicTime = 1000;
        staticTimePost = 1000;
        
        %speedApproach = 1; %units??
        initSizeX = 200; initSizeY = 200; %microns
        finalScaleFactor = 2;
        speedLateral = 500; %microns/s
        directionLateral = 0; %deg.
        imageFileName = '....';
        numSquares = 10;
        intensity = 0.5;
        %randSeed = 1;
        randPermut = false;
        receding = false;
        instantaneous = false;
        centerChecker = 'dark';
    end
    
    properties (Hidden)
        version = 1
        displayName = 'Approaching'        
        
        randSeed;
        interleave
        curEpStim
        trueNumSquares
        trueDynamicTime
        trueStimTime
        trueRescalingRate
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'curEpStim';
    end
    
    
    properties (Dependent)
        squareSizeX;
        rescalingRate;
        stimTime;
    end
    
    methods
                
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);

% Randomize
            scurr = rng('shuffle');
            obj.randSeed = scurr.Seed;
            
            %             % Random interleaving of epochs
            %             interleaveIndex = randsample(obj.numberOfAverages, floor(obj.numberOfAverages/2));
            %             localInterleave = zeros(obj.numberOfAverages, 1);
            %             localInterleave(interleaveIndex) = 1;
            %             obj.interleave = localInterleave;
            %             disp(localInterleave)
            
            % Random interleaving of epochs
            stimIsChecked = [obj.randPermut; obj.receding; obj.instantaneous];
            numInterleavedStimuli = double(1 + obj.randPermut + obj.receding + obj.instantaneous); %1 is default - approaching.
            numSingleStimEpochs = floor(double(obj.numberOfAverages)/numInterleavedStimuli);
            localInterleave = zeros(obj.numberOfAverages, 1);
            for I = 1:length(stimIsChecked)
                if stimIsChecked(I)
                    localInterleave(1+numSingleStimEpochs*(I-1):numSingleStimEpochs*I) = I;
                    %0  -approaching
                    %1  -shuffled
                    %2  -receding
                    %3  -instantaneous
                end;
            end;
            obj.interleave = localInterleave(randperm(obj.numberOfAverages));
            disp(obj.interleave)
            disp(stimIsChecked)
        end
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            spotDiameterPix = obj.um2pix(obj.curOuterDiameter);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.meanLevel);
            
       %%% constants: initial conditions for controllers
            pixInitSize = [obj.initSizeX, obj.initSizeY]./obj.rigConfig.micronsPerPixel;
            initPosition = [obj.windowSize(1)/2, obj.windowSize(2)/2];
            pixSpeedLat = obj.speedLateral./obj.rigConfig.micronsPerPixel;
            %%%
            
            
            %set bg
            obj.setBackground(presentation);
            
            %%%% Make a checkerboard stimulus object %%%%
            % Create an initial checkerboard image matrix.
            %RANDOM CHECKERBOARD
            %             rng(obj.randSeed);
            %             checkerboardMatrix = uint8(randi([0,1],(obj.numSquares)) * 255);
            %             %was rand(10).*255
            
            if ~strcmp(obj.centerChecker,'random')
                %REGULAR CHECKERBOARD                
                

                
                %modifiedNumSquares = obj.numSquares;
                tNumSquares = obj.trueNumSquares;
                if mod(tNumSquares, 2) == 0
                    cb = mod(1:(tNumSquares+1)^2,2);
                    cb = reshape(cb, [(tNumSquares+1),(tNumSquares+1)]);
                    cb = cb(1:end-1,1:end-1);
                else
                    cb = mod(1:tNumSquares^2,2);
                    cb = reshape(cb, [tNumSquares,tNumSquares]);
                end;
                if strcmp(obj.centerChecker,'dark')
                    cb = 1-cb;
                end;
                
            else
               %RANDOM CHECKERBOARD
               cb = randi([0,1],(obj.numSquares));
            end;
            
            checkerboardMatrix = uint8(cb.*255);
%             disp(checkerboardMatrix);
            % % %
            
            
            
            % Create the checkerboard stimulus.
            checkerboard = Image(checkerboardMatrix);
            checkerboard.position = initPosition;
            %             % Create an aperture (masked rectangle) stimulus to sit on top of the image stimulus.
            %             aperture = Rectangle();
            %             aperture.color = 0;
            %             aperture.size = [500, 500];
            %             mask = Mask.createCircularAperture(0.4);
            %             aperture.setMask(mask);
            %             %%%
            
            unitStep = [cosd(obj.directionLateral), sind(obj.directionLateral)];
            
            %%%% Set the minifying and magnifying functions to form discrete stixels.
            checkerboard.setMinFunction(GL.NEAREST);
            checkerboard.setMagFunction(GL.NEAREST);
            %%%%
            
            %%% function to modify simulus property %%%
            function sz = modifyScaleFactor(state, pixInitSize, obj)
                
                %                 function scFac = scFactor(dynamicTime,finalFactor)
                %                     %linear spacing
                %                     scFac = (1+dynamicTime*(finalFactor-1));
                %                 end
                
                function scFac = scFactor(t_dynamic,finalFactor,maxDynamicTime,curEpStim,patternRate)
                    %log spacing; random permutation option
                    alpha = log(finalFactor)/maxDynamicTime;
                    
                    %Add shuffled and receding versions of stimulus
                    nFrames = round(maxDynamicTime*patternRate);
                    dynTimeAxis = (1:nFrames)/patternRate;
                    if curEpStim == 1
                        dynTimeAxisPerm = randperm(nFrames)./patternRate;
                        shuffledTime = dynTimeAxisPerm(round(dynTimeAxis*10^5) == round(t_dynamic*10^5));
                        t_dynamic = shuffledTime;
                    elseif curEpStim == 2
                        dynTimeAxisPerm = (nFrames:-1:1)./patternRate;
                        reveresedTime = dynTimeAxisPerm(round(dynTimeAxis*10^5) == round(t_dynamic*10^5));
                        t_dynamic = reveresedTime;
                    end;
                    % %
                    
                    scFac = exp(alpha*t_dynamic);
                end
                
                
                if state.time<=(obj.preTime+obj.staticTimePre)/1E3
                    if obj.curEpStim~=2
                        sz = pixInitSize;
                    else
                        sz = pixInitSize * obj.finalScaleFactor;
                    end;
                elseif  state.time<=(obj.preTime+obj.staticTimePre+obj.trueDynamicTime)/1E3 %stimulus varying with time
                    t_dynamic = (state.time-(obj.preTime+obj.staticTimePre)/1E3);
                    sz = pixInitSize * scFactor(t_dynamic,obj.finalScaleFactor,obj.trueDynamicTime/1E3,obj.curEpStim, obj.patternRate);
                else
                    if obj.curEpStim~=2
                        sz = pixInitSize * obj.finalScaleFactor;
                    else
                        sz = pixInitSize;
                    end;
                end;

            end
            
            % % % Make a property controller to propagate property of checkerboard % % %
            %checkerboardImageController = PropertyController(checkerboard, 'imageMatrix', @(s)uint8(rand(10, 10) * 255));
            scaleFactorController = PropertyController(checkerboard, 'size', @(s)modifyScaleFactor(s, pixInitSize, obj));
            
            function pos = changePosition(state, obj, initPosition, unitStep, pixSpeedLat)
                if state.time<=obj.preTime/1E3
                    pos = [NaN,NaN];
                elseif state.time<=(obj.preTime+obj.staticTimePre)/1E3
                    pos = initPosition;
                elseif state.time<=(obj.preTime+obj.staticTimePre+obj.trueDynamicTime)/1E3
                    pos = initPosition+(state.time-(obj.preTime+obj.staticTimePre)/1E3)*pixSpeedLat.*unitStep;
                elseif state.time<=(obj.preTime+obj.stimTime)/1E3
                    pos = initPosition+(obj.trueDynamicTime/1E3)*pixSpeedLat.*unitStep;
                else
                    pos = [NaN,NaN];
                end;
                
            end
            
            positionController = PropertyController(checkerboard, 'position', @(s)changePosition(s, obj, initPosition, unitStep, pixSpeedLat));
            
            % % % Add checkerboard stimulus and controller to presentation % % %
            presentation.addStimulus(checkerboard);
            
            %presentation.addController(checkerboardImageController);
            presentation.addController(scaleFactorController);
            presentation.addController(positionController);
            %             presentation.addStimulus(aperture);
            
            
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
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared < obj.numberOfCycles * obj.numberOfSizeSteps;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.numEpochsCompleted < obj.numberOfCycles * obj.numberOfSizeSteps;
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

