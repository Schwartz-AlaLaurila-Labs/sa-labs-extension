classdef AutoCenter < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 250
        tailTime = 250
        
        spotDiameter = 22; %um
        searchDiameter = 300; %um
        alignSpotDiam = 150;
        %         numSpots = 100;
        mapResolution = 40; % um
        spotTotalTime = 0.3;
        spotOnTime = 0.1;
        
        numPointSets = 2;
        
        voltages = [-60,20];
        alternateVoltage = false; % WC only
        interactiveMode = false;
        epochTimeLimit = 80; %s
        
        valueMin = 0.1;
        valueMax = 1.0;
        numValues = 1;
        numValueRepeats = 2;
    end
    
    properties (Hidden)
        version = 3
        displayName = 'Auto Center'
        
        shapeDataMatrix
        shapeDataColumns
        sessionId
        epochNum
        autoContinueRun = 1;
        autoStimTime = 1000;
        startTime = 0;
        currentVoltageIndex
        runConfig
        pointSetIndex
        
        responsePlotMode = 'autocenter';
        responsePlotSplitParameter = '';
    end
    
    properties (Dependent)
        stimTime
        intensity
        values
    end
    
    methods
        
        function prepareRun(obj)
            obj.sessionId = str2double(regexprep(num2str(fix(clock),'%1d'),' +','')); % this is how you get a datetime string number in MATLAB
            obj.epochNum = 0;
            %             obj.startTime = clock;
            obj.autoContinueRun = true;
            obj.pointSetIndex = 0;
            
%             if strcmp(obj.ampMode, 'Cell attached')
%                 obj.alternateVoltage = false;
%             end
            if obj.alternateVoltage
                obj.currentVoltageIndex = 1;
            end
            
            prepareRun@sa_labs.protocols.StageProtocol(obj);
        end
        
        
        function prepareEpoch(obj, epoch)
            
            obj.epochNum = obj.epochNum + 1;
            generateNewStimulus = true;
            
            % alternate ex/in for same spots and settings
            if obj.alternateVoltage
                obj.ampHoldSignal = obj.voltages(obj.currentVoltageIndex);
                if obj.currentVoltageIndex ~= 1 % only generate a new stim if we're on the first voltage
                    generateNewStimulus = false;
                end
                fprintf('setting amp voltage: %d mV; waiting 5 sec for stability\n', obj.ampHoldSignal);
                obj.setDeviceBackground(obj.amp, obj.ampHoldSignal, 'mV'); % actually set it
                pause(5)
            end
            
            if generateNewStimulus
                
                analysisData = obj.responseFigure.analysisData;
                
                p = struct();
                p.generatePositions = true;
                obj.pointSetIndex = obj.pointSetIndex + 1;
                p.pointSetIndex = obj.pointSetIndex;
                p.spotDiameter = obj.spotDiameter; %um
                p.mapResolution = obj.mapResolution;
                p.searchDiameter = obj.searchDiameter;
                %                 p.numSpots = obj.numSpots;
                p.spotTotalTime = obj.spotTotalTime;
                p.spotOnTime = obj.spotOnTime;
                p.alignmentSpotDiameter = obj.alignSpotDiam;
                
                p.valueMin = obj.valueMin;
                p.valueMax = obj.valueMax;
                p.numValues = obj.numValues;
                p.numValueRepeats = obj.numValueRepeats;
                p.epochNum = obj.epochNum;
                
                %                 timeElapsed = etime(clock, obj.startTime);
                %                 p.timeRemainingSeconds = obj.runTimeSeconds - timeElapsed; %only update time remaining if new stim, so Inhibitory always runs
                %             obj.runTimeSeconds;
                
                if ~obj.interactiveMode
                    
                    if obj.epochNum == 1
                        p.mode = 'temporalAlignment';
                        runConfig = sa_labs.util.shape.generateShapeStimulus(p, analysisData);
                        
                    else
                        p.mode = 'receptiveField';
                        
                        increasedRes = false;
                        while true;
                            runConfig = generateShapeStimulus(p, analysisData); %#ok<*PROPLC,*PROP>
                            if runConfig.stimTime > 1e3 * obj.epochTimeLimit
                                p.mapResolution = round(p.mapResolution * 1.1);
                                increasedRes = true;
                            else
                                break
                            end
                        end
                        if increasedRes
                            fprintf('Epoch stim time too long (> %d sec); increased map resolution to %d um\n', obj.epochTimeLimit, p.mapResolution)
                        end
                    end
                else
                    % INTERACTIVE MODE
                    % TODO: convert to GUI
                    obj.autoContinueRun = true;
                    while true % loop preference setup until we make the choices we like
                        
                        
                        % choose active point set
                        % TODO: analysisData.pointSets
                        
                        %                         figure(40);
                        %                         plotShapeData(analysisData, 'plotSpatial_mean')
                        %                         disp('chose center then any edge point');
                        %                         [x,y] = ginput(2);
                        
                        
                        % choose next measurement
                        disp('map, curves, adapt, align, refvar, quit');
                        imode = input('measurement? ','s');
                        
                        if strcmp(imode, 'curves') % response curves
                            p.mode = 'responseCurves';
                            p.numSpots = input('num positions? ');
                            p.generatePositions = false;
                            p.numValues = input('num values? ');
                            p.numValueRepeats = input('num value repeats? ');
                            
                        elseif strcmp(imode, 'map')
                            p.mode = 'receptiveField';
                            p.generatePositions = input('generate new positions? ');
                            if p.generatePositions
                                % TODO: display graph of current largest pointset's RF for clicking center and edge
                                p.center = input('center? ');
                                p.searchDiameter = input('search diameter? ');
                                p.spotDiameter = input('spot diameter? ');
                                p.mapResolution = input('map resolution? ');
                            end
                            
                        elseif strcmp(imode, 'align')
                            p.mode = 'temporalAlignment';
                            
                        elseif strcmp(imode, 'adapt')
                            p.mode = 'adaptationRegion';
                            %                             p.adaptationSpotPositions = 100 * [1,1; -1,-1; 1, -1; -1, 1];%input('adaptation spot position [x1, y1]? ');
                            
                            p.adaptationSpotPositions = 100 * [0,0];%input('adaptation spot position [x1, y1]? ');
                            %                             p.adaptationSpotPositions = generatePositions('triangular', [100, 100]);
                            %                             p.adaptationSpotPositions = 120 *
                            p.adaptationSpotFrequency = 12;%input('flicker frequency? ');
                            p.adaptationSpotDiameter = 15; %input('adaptation spot diameter? ');
                            p.adaptationSpotIntensity = 1.0;
                            p.probeSpotDiameter = 12; %input('probe spot diameter? ');
                            p.probeSpotDuration = .3; %input('probe spot duration? (sec) ');
                            p.adaptSpotWarmupTime = 6;
                            p.probeSpotPositionRadius = 80;
                            p.probeSpotSpacing = 25;
                            p.probeSpotRepeats = 2;
                            p.probeSpotValues = [1];
                            
                        elseif strcmp(imode, 'refvar')
                            p.mode = 'refineVariance';
                            p.variancePercentile = input('percentile of highest variance to refine (0-100)? ');
                            p.numValueRepeats = input('num value repeats to add? ');
                            
                        elseif strcmp(imode, 'refedges')
                            p.mode = 'refineEdges';
                            p.slopePercentile = input('percentile of highest slope to refine (0-100)? ');
                            
                        elseif strcmp(imode, 'quit')
                            p.mode = 'null';
                            obj.autoContinueRun = false;
                        end
                        
                        runConfig = generateShapeStimulus(p, analysisData); %#ok<*PROPLC,*PROP>
                        %                         sdm = runConfig.shapeDataMatrix
                        
                        p %#ok<NOPRT>
                        fprintf('Stimulus will run for %d sec.\n', round(runConfig.stimTime / 1000))
                        contin = input('go? ');
                        if contin
                            break;
                        end
                    end % user choice loop
                end
                
                obj.runConfig = runConfig;
                obj.shapeDataColumns = runConfig.shapeDataColumns;
                obj.shapeDataMatrix = runConfig.shapeDataMatrix;
                obj.autoStimTime = runConfig.stimTime;
            end
            
            % always continue if we're alternating and this is not the last
            % voltage to be used
            if obj.alternateVoltage && obj.currentVoltageIndex ~= length(obj.voltages)
                obj.autoContinueRun = true;
            else
                obj.autoContinueRun = obj.runConfig.autoContinueRun || obj.pointSetIndex <= obj.numPointSets;
            end
            
            % set next epoch voltage to alternate
            nextIndices = [(2:length(obj.voltages)), 1];
            obj.currentVoltageIndex = nextIndices(obj.currentVoltageIndex);
            
            epoch.addParameter('sessionId',obj.sessionId);
            epoch.addParameter('presentationId',obj.epochNum);
            epoch.addParameter('epochMode',obj.runConfig.epochMode);
            epoch.addParameter('shapeDataMatrix', obj.runConfig.shapeDataMatrix(:));
            epoch.addParameter('shapeDataColumns', strjoin(obj.runConfig.shapeDataColumns,','));
            %             epoch.addParameter('angleOffsetForRigAndStimulus', obj.rigConfig.projectorAngleOffset);
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            p.setBackgroundColor(obj.meanLevel);
            

            col_intensity = not(cellfun('isempty', strfind(obj.shapeDataColumns, 'intensity')));
            col_diameter = not(cellfun('isempty', strfind(obj.shapeDataColumns, 'diameter')));
            col_startTime = not(cellfun('isempty', strfind(obj.shapeDataColumns, 'startTime')));
            col_endTime = not(cellfun('isempty', strfind(obj.shapeDataColumns, 'endTime')));
            col_flickerFrequency = not(cellfun('isempty', strfind(obj.shapeDataColumns, 'flickerFrequency')));
            
            
            % GENERIC controller
            function c = shapeController(state, preTime, baseLevel, startTime, endTime, shapeData_someColumns, controllerIndex)
                % controllerIndex is to have multiple shapes simultaneously
                t = state.time - preTime * 1e-3;
                activeNow = (t > startTime & t < endTime);
                if any(activeNow)
                    actives = find(activeNow);
                    if controllerIndex <= length(actives)
                        c = shapeData_someColumns(actives(controllerIndex),:);
                    else
                        c = baseLevel;
                    end
                else
                    c = baseLevel;
                end
            end
            
            % Custom controllers
            % flicker
            function c = shapeFlickerController(state, preTime, baseLevel, startTime, endTime, shapeData_someColumns, controllerIndex)
                % controllerIndex is to have multiple shapes simultaneously
                t = state.time - preTime * 1e-3;
                activeNow = (t > startTime & t < endTime);
                if any(activeNow)
                    actives = find(activeNow);
                    if controllerIndex <= length(actives)
                        myActive = actives(controllerIndex);
                        vals = shapeData_someColumns(myActive,:);
                        % [intensity, frequency, start]
                        c = vals(1) * (cos(2 * pi * (t - vals(3)) * vals(2)) > 0);
                    else
                        c = baseLevel;
                    end
                else
                    c = baseLevel;
                end
            end
            
            
            
            %             TODO: change epoch property shapeData to shapeDataMatrix in
            %             analysis
            
            % setup stimulus objects
            numCircles = obj.runConfig.numShapes; % these are in order of shapes being detected in the active shape set from the start & end times
            circles = cell(numCircles, 1);
            for ci = 1:numCircles
                circ = stage.builtin.stimuli.Ellipse();
                circles{ci} = circ;
                p.addStimulus(circles{ci});
                
                % intensity now handled by flicker controller
                %                 controllerIntensity = stage.builtin.controllers.PropertyController(circ, 'color', @(s)shapeController(s, obj.preTime, obj.meanLevel, ...
                %                     obj.shapeDataMatrix(:,col_startTime), ...
                %                     obj.shapeDataMatrix(:,col_endTime), ...
                %                     obj.shapeDataMatrix(:,col_intensity), ci));
                %                 presentation.addController(controllerIntensity);
                
                % diameter X
                controllerDiameterX = stage.builtin.controllers.PropertyController(circ, 'radiusX', @(s)shapeController(s, obj.preTime, 100, ...
                    obj.shapeDataMatrix(:,col_startTime), ...
                    obj.shapeDataMatrix(:,col_endTime), ...
                    obj.shapeDataMatrix(:,col_diameter) / 2, ci));
                p.addController(controllerDiameterX);
                
                % diameter Y
                controllerDiameterY = stage.builtin.controllers.PropertyController(circ, 'radiusY', @(s)shapeController(s, obj.preTime, 100, ...
                    obj.shapeDataMatrix(:,col_startTime), ...
                    obj.shapeDataMatrix(:,col_endTime), ...
                    obj.shapeDataMatrix(:,col_diameter) / 2, ci));
                p.addController(controllerDiameterY);
                
                % position
                poscols = not(cellfun('isempty', strfind(obj.shapeDataColumns, 'X'))) | ...
                    not(cellfun('isempty', strfind(obj.shapeDataColumns, 'Y')));
                positions = obj.shapeDataMatrix(:,poscols);
                positions_transformed = [obj.um2pix(positions(:,1)) + canvasSize(1)/2, obj.um2pix(positions(:,2)) + canvasSize(2)/2];
                controllerPosition = stage.builtin.controllers.PropertyController(circ, 'position', @(s)shapeController(s, obj.preTime, [0, 0], ...
                    obj.shapeDataMatrix(:,col_startTime), ...
                    obj.shapeDataMatrix(:,col_endTime), ...
                    positions_transformed, ci));
                p.addController(controllerPosition);
                
                % flicker
                sdm_intflicstart = obj.shapeDataMatrix(:,[find(col_intensity), find(col_flickerFrequency), find(col_startTime)]);
                controllerFlicker = stage.builtin.controllers.PropertyController(circ, 'color', @(s)shapeFlickerController(s, obj.preTime, obj.meanLevel, ...
                    obj.shapeDataMatrix(:,col_startTime), ...
                    obj.shapeDataMatrix(:,col_endTime), ...
                    sdm_intflicstart, ci));
                p.addController(controllerFlicker);
                
            end % circle loop
            
        end
        
        function stimTime = get.stimTime(obj)
            stimTime = obj.autoStimTime;
        end
        
        function values = get.values(obj)
            values = linspace(obj.valueMin, obj.valueMax, obj.numValues);
            values = mat2str(values, 2);
        end
        
        function intensity = get.intensity(obj)
            intensity = obj.valueMax;
        end
        
        function tf = shouldContinuePreparingEpochs(obj)
            tf = obj.autoContinueRun;
        end
        
        function tf = shouldContinueRun(obj)
            tf = obj.autoContinueRun;
        end
        
    end
    
end

