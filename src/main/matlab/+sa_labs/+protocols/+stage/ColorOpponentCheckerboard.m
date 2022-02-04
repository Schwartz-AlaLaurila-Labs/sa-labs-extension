classdef ColorOpponentCheckerboard < sa_labs.protocols.StageProtocol
    %TODO:
    %   - set up with multiple LEDs
    %   - texture size as a parameter?
    %   - 
    
    properties
        %times in ms
        preTime = 500	% Texture leading duration (ms)
        stimTime = 1000	% Texture duration (ms)
        tailTime = 1000	% Texture trailing duration (ms)
        
        intensity = 0.5
        
        textureSize = 200; % um
        numberOfEpochs = 200

        alternatePatterns = false
    end
    
    properties (Hidden)
        version = 1;
        currentTexturePattern
        responsePlotMode = 'cartesian'; 
        responsePlotSplitParameter = 'currentTexturePattern';
    end
    
    properties (Dependent, Hidden)
        totalNumEpochs
    end
    
    methods
        
        function prepareEpoch(obj, epoch)
            %TODO: remove this?
            obj.currentTexturePattern = obj.primaryObjectPattern;
            if obj.numberOfPatterns > 1
                if obj.alternatePatterns
                    if mod(obj.numEpochsPrepared, 2) == 1
                        obj.currentTexturePattern = obj.secondaryObjectPattern;
                        currentTextureColor = obj.colorPattern2;
                    else
                        obj.currentTexturePattern = obj.primaryObjectPattern;
                        currentTextureColor = obj.colorPattern1;
                    end
                    disp(currentTextureColor)
                end
            end
            epoch.addParameter('currentTexturePattern', obj.currentTexturePattern);
           
            % Call the base method.
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
            
        end
        
        function p = createPresentation(obj)
            p = stage.core.Presentation(obj.preTime + obj.stimTime + obj.tailTime);
            
            % Image is M-by-N (grayscale), M-by-N-by-3 (truecolor)
            texture = stage.builtin.stimuli.Image(randi(255,[200,200],'uint8'));
            texture.color = obj.intensity;
            texture.opacity = 1;
            % texture = stage.builtin.stimuli.Ellipse();
            % texture.radiusX = obj.textureSize;
            % texture.radiusY = obj.textureSize;
            
            
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            texture.position = canvasSize / 2;
            texture.size = [obj.textureSize obj.textureSize]; %TODO: pixels2microns step
            
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

