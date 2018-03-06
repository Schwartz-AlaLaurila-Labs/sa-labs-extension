% process auto center offline simply

% load('/Users/sam/analysis/cellData/051216Ac4.mat')
% sessionId = 201651215217;

% load('/Users/sam/analysis/cellData/032416Ac9.mat')
% sessionId = 2016324173256;

load('/Users/sam/analysis/cellData/060216Ac2.mat')
sessionId = 2016512181624;

% process

epochData = cell(1);
ei = 1;
for i = 1:length(cellData.epochs)
    epoch = cellData.epochs(i);
    sid = epoch.get('sessionId');
    if sid == sessionId
        sd = ShapeData(epoch, 'offline');
        epochData{ei, 1} = sd;
        ei = 1 + ei;
    end
end

if length(epochData{1}) > 0 %#ok<ISMT>
    % analyze shapedata
    analysisData = processShapeData(epochData);
else
    disp('no epochs found');
    return
end


%% normal plots
figure(10);clf;
plotShapeData(analysisData, 'plotSpatial_mean');
% 
% figure(11);clf;
% plotShapeData(analysisData, 'temporalResponses');



%% new plots
figure(9);clf;
plotShapeData(analysisData, 'adaptationRegion');

% plotShapeData(analysisData, 'temporalComponents');

% figure(11);clf;
% plotShapeData(analysisData, 'subunit');



%% save maps

plotShapeData(analysisData, 'plotSpatial_saveMaps');
