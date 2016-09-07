%% Initialize changing parameters
currentTime = 0;
startTime = 0;
epoch_num = 0;

analysisData = struct();
epochData = {};
continueRun = true;

%% Loop

while continueRun

    %% setup fixed params as in autocenter
    epoch_num = epoch_num + 1;

    p = struct();
    runTimeSeconds = 300;
    p.spotDiameter = 30; %um
    p.searchDiameter = 350;
    p.numSpots = 20;
    p.spotTotalTime = .3;
    p.spotOnTime = .1;

    p.valueMin = .1;
    p.valueMax = .5;
    p.numValues = 2;
    p.numValueRepeats = 3;
    p.epochNum = epoch_num;
    p.refineCenter = false;
    p.refineEdges = true;
    

    while true % loop preference setup until we make the choices we like
%         p = struct();
        p.generatePositions = true;

        timeElapsed = currentTime - startTime;
        p.timeRemainingSeconds = runTimeSeconds - timeElapsed;
        
        
        % INTERACTIVE MODE
        % TODO: convert to GUI
        % overwrite above params with custom if interactive
        if true

            % choose active point set
            % TODO: analysisData.pointSets

            figure(40);
            plotShapeData(analysisData, 'plotSpatial_mean')
%                         disp('chose center then any edge point');
%                         [x,y] = ginput(2);


            % choose next measurement
            disp('map, curves, adapt, align, refvar');
            imode = input('measurement? ','s');

            if strcmp(imode, 'curves') % response curves
                mode = 'responseCurves';
                p.numSpots = input('num positions? ');
                p.generatePositions = false;
                p.numValues = input('num values? ');
                p.numValueRepeats = input('num value repeats? ');

            elseif strcmp(imode, 'map')
                mode = 'receptiveField';
                p.generatePositions = input('generate new positions? ');
                if p.generatePositions
                    % TODO: display graph of current largest pointset's RF for clicking center and edge
                    p.center = input('center? ');
                    p.searchDiameter = input('search diameter? ');
                    p.spotDiameter = input('spot diameter? ');
                end

            elseif strcmp(imode, 'align')
                mode = 'temporalAlignment';

            elseif strcmp(imode, 'adapt')
                mode = 'adaptationRegion';
                p.adaptationSpotPositions = input('adaptation spot position [x1, y1]? ');
                p.adaptationSpotFrequency = input('flicker frequency? ');
                p.adaptationSpotDiameter = input('adaptation spot diameter? ');
                p.probeSpotDiameter = input('probe spot diameter? ');
                p.probeSpotDuration = input('probe spot duration? (sec) ');

            elseif strcmp(imode, 'refvar')
                mode = 'refineVariance';
                p.variancePercentile = input('percentile of highest variance to refine (0-100)? ');
                p.numValueRepeats = input('num value repeats to add? ');

            elseif strcmp(imode, 'refedges')
                mode = 'refineEdges';
                p.slopePercentile = input('percentile of highest slope to refine (0-100)? ');
            else
                continue
            end



        end
        
        runConfig = generateShapeStimulus(mode, p, analysisData); %#ok<*PROPLC,*PROP>
        obj.runConfig = runConfig;
        obj.shapeDataColumns = runConfig.shapeDataColumns;
        obj.shapeDataMatrix = runConfig.shapeDataMatrix;
        obj.autoStimTime = runConfig.stimTime;

        sprintf('this will run for %d sec', round(runConfig.stimTime / 1000))
        contin = input('go? ');
        if contin
            break;
        end
    end



    %% generate stimulus

    runConfig = generateShapeStimulus(mode, p, analysisData);
    continueRun = runConfig.autoContinueRun;
    
    disp(runConfig.shapeDataMatrix)

    %% Create fake epoch

    epoch = FakeEpoch(p, runConfig);

    %% create shapedata

    sd = ShapeData(epoch, 'offline');

    %% simulate spike responses

    sd.simulateSpikes();
    epochData{epoch_num, 1} = sd;

    %% analyze shapedata
    analysisData = processShapeData(epochData);

    figure(8);clf;
    plotShapeData(analysisData, 'plotSpatial_mean');

    figure(9);clf;
    plotShapeData(analysisData, 'temporalAlignment');

    figure(10);clf;
    plotShapeData(analysisData, 'subunit');

%     figure(11);clf;
%     plotShapeData(analysisData, '');
    %% pause and repeat

    currentTime = currentTime + 1.0 + sd.stimTime / 1000
%     pause(3)
end

