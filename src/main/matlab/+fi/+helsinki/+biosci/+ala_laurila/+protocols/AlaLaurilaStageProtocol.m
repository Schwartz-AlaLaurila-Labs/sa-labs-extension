classdef (Abstract) AlaLaurilaStageProtocol < fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol
% this class handles protocol control which is visual stimulus specific

    properties
        meanLevel = 0.0       % Background light intensity (0-1)
        offsetX = 0
        offsetY = 0
    end
        
    methods (Abstract)
        p = createPresentation(obj);
    end
    
    methods
        
        function d = getPropertyDescriptor(obj, name)
            d = getPropertyDescriptor@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj, name);
            
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
            controllerDidStartHardware@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj);
            obj.rig.getDevice('Stage').play(obj.createPresentation(), obj.preTime);
        end
        
        function prepareRun(obj)
            prepareRun@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj);            
%             obj.showFigure('io.github.stage_vss.figures.FrameTimingFigure', obj.rig.getDevice('Stage'));
        end
        
%         function addFrameTracker(obj,presentation)
%             stages = obj.rig.getDevices('Stage');
%             if isempty(stages)
%                 frameTrackerPosition = [20,20];
%             else
%                 frameTrackerPosition = stages{1}.getConfigurationSetting('frameTrackerPosition');
%             end
%             
%             frameTracker = stage.builtin.stimuli.FrameTracker();
%             pixelOffsetX = round(obj.um2pix(obj.offsetX)); % reverse the canvas offset to keep it in the corner
%             pixelOffsetY = round(obj.um2pix(obj.offsetY));
%             frameTracker.position = frameTrackerPosition - [pixelOffsetX, pixelOffsetY]; %gets this from RigConfig, and undoes canvas offset
%             controller = stage.builtin.controllers.PropertyController(frameTracker, 'color', @(s)double(255.*repmat(s.time<obj.preTime*1E-3, 1, 3))); %temp hack, frametracker only for preTime
%             presentation.addController(controller);
%             presentation.addStimulus(frameTracker);
%         end
            
        function tf = shouldContinuePreloadingEpochs(obj) %#ok<MANU>
            tf = false;
        end
        
        function tf = shouldWaitToContinuePreparingEpochs(obj)
            tf = obj.numEpochsPrepared > obj.numEpochsCompleted || obj.numIntervalsPrepared > obj.numIntervalsCompleted;
        end
        
        function completeRun(obj)
            completeRun@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj);
            obj.rig.getDevice('Stage').clearMemory();
        end
        
        function [tf, msg] = isValid(obj)
            [tf, msg] = isValid@fi.helsinki.biosci.ala_laurila.protocols.AlaLaurilaProtocol(obj);
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

