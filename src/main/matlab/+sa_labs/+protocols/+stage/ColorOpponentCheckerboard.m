classdef ColorOpponentCheckerboard < sa_labs.protocols.StageProtocol
       
    properties
        %times in ms
        preTime = 500	% Spot leading duration (ms)
        stimTime = 1000	% Spot duration (ms)
        tailTime = 1000	% Spot trailing duration (ms)
        
        intensity = 0.5
        
        textureSize = 200; % um
        numberOfEpochs = 200
    end
    
    properties (Hidden)
        version = 1;
       responsePlotMode = 'cartesian'; 
        responsePlotSplitParameter = 'currentTextureSize';
    end
    
    properties (Dependent, Hidden)
        totalNumEpochs
    end
    
    methods
        
        function prepareEpoch(obj, epoch)
            %passing for now
            epoch.addParameter('currentTextureSize',obj.textureSize); %temporary
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation(obj.preTime + obj.stimTime + obj.tailTime);
            
            % Image is M-by-N (grayscale), M-by-N-by-3 (truecolor)
            texture = stage.builtin.stimuli.Image(randi(255,[200,200],'uint8'));
            % texture = stage.builtin.stimuli.Ellipse();
            % texture.radiusX = obj.textureSize;
            % texture.radiusY = obj.textureSize;
            
            
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            texture.position = canvasSize / 2;
            texture.size = [obj.textureSize obj.textureSize];
            
            p.addStimulus(texture);
            
            obj.setOnDuringStimController(p, texture);
            
            % shared code for multi-pattern objects
            obj.setColorController(p, texture);
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
    end
end

