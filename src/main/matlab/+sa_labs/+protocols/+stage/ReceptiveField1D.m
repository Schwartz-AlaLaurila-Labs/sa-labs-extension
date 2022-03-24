classdef ReceptiveField1D < sa_labs.protocols.StageProtocol
        
    properties
        preTime = 250
        tailTime = 500
        
        contrast = 0.5
        frequency = 4; %hz
        numberOfContrastPulses = 4;
        
        probeAxis = 'vertical';
        barSeparation = 30; %microns
        barWidth = 30; %microns
        barLength = 200; %microns
        
        numberOfPositions = 11;
        numberOfCycles = 2;
    end
    
    properties (Dependent)
        stimTime
    end
    
    properties (Hidden)
        version = 3
        curPosXPx
        curPosYPx
        positions % in microns
        probeAxisType = symphonyui.core.PropertyType('char', 'row', {'horizontal', 'vertical'})
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter; % to be set manually in prepareRun
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            % delay base method to below:
            
            %set positions
            if strcmp(obj.probeAxis, 'horizontal')
                obj.responsePlotSplitParameter = 'positionX';
            else
                obj.responsePlotSplitParameter = 'positionY';
            end
            firstPos = -1*round(floor(obj.numberOfPositions/2)) * obj.barSeparation;
            obj.positions = firstPos:obj.barSeparation:(firstPos+(obj.numberOfPositions-1)*obj.barSeparation);
            
            [~, sortIndices] = sort(abs(obj.positions));
            obj.positions = obj.positions(sortIndices);
                
            % Call the base method later to let me set the split param
            % first
            prepareRun@sa_labs.protocols.StageProtocol(obj);
        end
        
        function prepareEpoch(obj, epoch)

            % For typical use of this stimulus, it makes sense to have a fixed center-out ordering
            % so skip the randomization
            index = mod(obj.numEpochsPrepared, obj.numberOfPositions);
%             if index == 0
%                 obj.positions = obj.positions(randperm(obj.numberOfPositions));
%             end
            index = index + 1;
            
            %get current position
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            centerPx = canvasSize / 2;
            
            if strcmp(obj.probeAxis, 'horizontal')
                obj.curPosXPx = centerPx(1) + obj.um2pix(obj.positions(index));
                obj.curPosYPx = centerPx(2);
                epoch.addParameter('positionX', obj.positions(index));
                epoch.addParameter('positionY', 0);
            else
                obj.curPosXPx = centerPx(1);
                obj.curPosYPx = centerPx(2) + obj.um2pix(obj.positions(index));
                epoch.addParameter('positionX', 0);
                epoch.addParameter('positionY', obj.positions(index));
            end

            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
                        
        end
        
        function p = createPresentation(obj)
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            rect = stage.builtin.stimuli.Rectangle();
            if strcmp(obj.probeAxis, 'horizontal')
                rect.size = obj.um2pix([obj.barWidth, obj.barLength]);
            else
                rect.size = obj.um2pix([obj.barLength, obj.barWidth]);
            end
            rect.position = [obj.curPosXPx, obj.curPosYPx];
            p.addStimulus(rect);
            
            function c = sineWaveStim(state, preTime, stimTime, contrast, meanLevel, freq)
                if state.time>preTime*1e-3 && state.time<=(preTime+stimTime)*1e-3
                    timeVal = state.time - preTime*1e-3; %s
                    %inelegant solution for zero mean
%                     if meanLevel < 0.05
%                         c = contrast * sin(2*pi*timeVal*freq);
%                         if c<0, c = 0; end %rectify
%                     else
%                         c = meanLevel + meanLevel * contrast * sin(2*pi*timeVal*freq);
%                     end
                    c = contrast;
                else
                    c = meanLevel;
                end
            end
            
            controller = stage.builtin.controllers.PropertyController(rect, 'color', @(s)sineWaveStim(s, obj.preTime, obj.stimTime, obj.contrast, obj.meanLevel, obj.frequency));
            p.addController(controller);
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * obj.numberOfPositions;
        end
        
        function stimTime = get.stimTime(obj)
            stimTime = 1E3*(obj.numberOfContrastPulses/obj.frequency);
        end
    end
    
end