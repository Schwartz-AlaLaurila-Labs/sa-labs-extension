classdef AlignmentCross < sa_labs.protocols.StageProtocol
    
    properties
        preTime = 500                   % Cross leading duration (ms)
        stimTime = 500                  % Cross duration (ms)
        tailTime = 0                    % Cross trailing duration (ms)
        intensity = 1.0                 % Cross light intensity (0-1)
        width = 40                      % Width of the cross in (um)
        length = 400                    % Length of the cross in  (um)
        numberOfEpochs = 5              % Number of epochs
        asymmetricShape = false         % Display asymmetric cross
    end
    
    properties(Hidden)
        responsePlotMode = false
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function didSetRig(obj)
            didSetRig@sa_labs.protocols.StageProtocol(obj);
            obj.NDF = 2;
        end

        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();
            
            armWidthPix = obj.um2pix(obj.width);
            armLengthPix = obj.um2pix(obj.length);
            
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            
            if obj.asymmetricShape
                armLengthPix = armLengthPix / 2;
                
                asymmHbar = stage.builtin.stimuli.Rectangle();
                asymmHbar.color = obj.intensity;
                asymmHbar.size = [armWidthPix * .6, armLengthPix];
                asymmHbar.position = canvasSize/2 + [0, armLengthPix / 2];
                p.addStimulus(asymmHbar);
                
                hbar = stage.builtin.stimuli.Rectangle();
                hbar.color = obj.intensity;
                hbar.size = [armWidthPix, armLengthPix];
                hbar.position = canvasSize/2 + [0, -armLengthPix / 2];
                p.addStimulus(hbar);
                
                asymmVbar = stage.builtin.stimuli.Rectangle();
                asymmVbar.color = obj.intensity;
                asymmVbar.size = [armLengthPix, armWidthPix * 1.5];
                asymmVbar.position = canvasSize/2 + [armLengthPix / 2, 0];
                p.addStimulus(asymmVbar);
                
                vbar = stage.builtin.stimuli.Rectangle();
                vbar.color = obj.intensity;
                vbar.size = [armLengthPix, armWidthPix];
                vbar.position = canvasSize/2 + [-armLengthPix / 2, 0];
                p.addStimulus(vbar);
            else
                
                hbar = stage.builtin.stimuli.Rectangle();
                hbar.size = [armWidthPix, armLengthPix];
                hbar.color = obj.intensity;
                hbar.position = [canvasSize(1)/2, canvasSize(2)/2];
                p.addStimulus(hbar);
                
                vbar = stage.builtin.stimuli.Rectangle();
                vbar.size = [armLengthPix, armWidthPix];
                vbar.color = obj.intensity;
                vbar.position = [canvasSize(1)/2, canvasSize(2)/2];
                p.addStimulus(vbar);
            end
            
        end
        
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfEpochs;
        end
        
    end
    
end

