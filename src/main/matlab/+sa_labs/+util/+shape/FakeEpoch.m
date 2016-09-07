classdef FakeEpoch < matlab.mixin.SetGet
    
    properties
        
        sessionId
        presentationId
        shapeDataColumns
        shapeDataMatrix
        
        spotTotalTime
        spotOnTime
        spotDiameter
        numSpots
        ampMode
        ampHoldSignal
        numValues
        numValueRepeats
        epochMode
        stimTime
    end
    
    methods 
        function obj = FakeEpoch(params, runConfig)
            obj.sessionId = 1;
            obj.presentationId = params.epochNum;
            obj.shapeDataColumns = strjoin(runConfig.shapeDataColumns,',');
            obj.shapeDataMatrix = strjoin(cellfun(@num2str, num2cell(runConfig.shapeDataMatrix(:)), 'UniformOutput',0),',');
            obj.epochMode = runConfig.epochMode;
            
            obj.spotTotalTime = params.spotTotalTime;
            obj.spotOnTime = params.spotOnTime;
            obj.spotDiameter = params.spotDiameter;
            obj.numSpots = params.numSpots;
            obj.ampMode = 'emulated';
            obj.numValues = params.numValues;
            obj.numValueRepeats = params.numValueRepeats;
            obj.stimTime = runConfig.stimTime;
            obj.ampHoldSignal = 0;
            
        end
    end
end



% elseif strcmp(runmode, 'emulation')
% 
%                 obj.sessionId = 1;
%                 obj.presentationId = epoch.epochNum;                
%                 sdc = strjoin(p.shapeDataColumns,',');
%                 sdm = strjoin(cellfun(@num2str, num2cell(p.shapeDataMatrix(:)), 'UniformOutput',0),',');
%                 em = epoch.getParameter('epochMode');
%                 obj.spotTotalTime = epoch.getParameter('spotTotalTime');
%                 obj.spotOnTime = epoch.getParameter('spotOnTime');
%                 obj.spotDiameter = epoch.getParameter('spotDiameter');
%                 obj.numSpots = epoch.getParameter('numSpots');
%                 obj.ampMode = epoch.getParameter('ampMode');
%                 obj.numValues = epoch.getParameter('numValues');
% 
%             end