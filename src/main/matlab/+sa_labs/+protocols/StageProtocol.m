classdef (Abstract) StageProtocol < sa_labs.protocols.BaseProtocol
% this class handles protocol control which is visual stimulus specific

    properties
        meanLevel = 0.0       % Background light intensity (0-1)
        offsetX = 0
        offsetY = 0
    end
        
    properties (Transient, Hidden)
        responseFigure
    end
        
    methods (Abstract)
        p = createPresentation(obj);
    end
    
    methods
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@sa_labs.protocols.BaseProtocol(obj, name);
            
            switch name
                case {'meanLevel', 'offsetX', 'offsetY', 'intensity'}
                    d.category = '1 Basic';
            end
        end
        
        function p = getPreview(obj, panel)
            if isempty(obj.rig.getDevices('Stage'))
                p = [];
                return;
            end
            p = io.github.stage_vss.previews.StagePreview(panel, @()obj.createPresentation(), ...
                'windowSize', obj.rig.getDevice('Stage').getCanvasSize());
        end
               
        function controllerDidStartHardware(obj)
            controllerDidStartHardware@sa_labs.protocols.BaseProtocol(obj);
            obj.rig.getDevice('Stage').play(obj.createPresentation(), obj.preTime);
        end
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.BaseProtocol(obj);
            
            devices = {};
            for ci = 1:4
                ampName = obj.(['chan' num2str(ci)]);
                if ~strcmp(ampName, 'None');
                    device = obj.rig.getDevice(ampName);
                    devices{end+1} = device; %#ok<AGROW>
                end
            end
            
            if obj.responsePlotMode ~= false
                obj.responseFigure = obj.showFigure('sa_labs.figures.ResponseAnalysisFigure', devices, ...
                    'activeFunctionNames', {'mean'}, ...
                    'baselineRegion', [0 obj.preTime], ...
                    'measurementRegion', [obj.preTime obj.preTime+obj.stimTime],...
                    'epochSplitParameter',obj.responsePlotSplitParameter, 'plotMode',obj.responsePlotMode);
            end
            
%             obj.showFigure('io.github.stage_vss.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));
        end
            
        function tf = shouldContinuePreloadingEpochs(obj) %#ok<MANU>
            tf = false;
        end
        
        function tf = shouldWaitToContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared > obj.numEpochsCompleted || obj.numIntervalsPrepared > obj.numIntervalsCompleted;
        end
        
        function completeRun(obj)
            completeRun@sa_labs.protocols.BaseProtocol(obj);
            obj.rig.getDevice('Stage').clearMemory();
        end
        
        function [tf, msg] = isValid(obj)
            [tf, msg] = isValid@sa_labs.protocols.BaseProtocol(obj);
            if tf
                tf = ~isempty(obj.rig.getDevices('Stage'));
                msg = 'No stage';
            end
        end
        
    end
    
    methods (Access = protected)
        
        function p = um2pix(obj, um)
            stages = obj.rig.getDevices('Stage');
            if isempty(stages)
                micronsPerPixel = 1;
            else
                micronsPerPixel = stages{1}.getConfigurationSetting('micronsPerPixel');
            end
            p = round(um / micronsPerPixel);
        end
        
    end
    
end

