classdef ReceptiveField1D < sa_labs.protocols.StageProtocol
        
    properties
        preTime = 500 %will be rounded to account for frame rate
        tailTime = 500 %will be rounded to account for frame rate
        
        contrast = 0.5
        frequency = 4; %hz
        numberOfContrastPulses = 4;
        
        probeAxis = 'vertical';
        barSeparation = 40; %microns
        barWidth = 40; %microns
        barLength = 300; %microns
        
        numberOfPositions = 9;
        numberOfCycles = 2;
    end
    
    properties (Dependent)
        stimTime
    end
    
    properties (Hidden)
        displayName = 'Receptive Field 1D'
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
                
            % Call the base method later to let me set the split param
            % first
            prepareRun@sa_labs.protocols.StageProtocol(obj);
        end
        
        function prepareEpoch(obj, epoch)

            % Randomize angles if this is a new set
            index = mod(obj.numEpochsPrepared, obj.numberOfPositions);
            if index == 0
                obj.positions = obj.positions(randperm(obj.numberOfPositions));
            end
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
            p.setBackgroundColor(obj.meanLevel);
            
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
                    if meanLevel < 0.05
                        c = contrast * sin(2*pi*timeVal*freq);
                        if c<0, c = 0; end %rectify
                    else
                        c = meanLevel + meanLevel * contrast * sin(2*pi*timeVal*freq);
                    end
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
            %4 cycles
            stimTime = 1E3*(obj.numberOfContrastPulses/obj.frequency); %ms
        end
    end
    
end