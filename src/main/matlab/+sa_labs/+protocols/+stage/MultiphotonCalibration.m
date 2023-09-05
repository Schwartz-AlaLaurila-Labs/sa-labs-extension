classdef LightStep < sa_labs.protocols.StageProtocol
    
    properties
        %times in ms
        preTime = 500	% Stimulus leading duration (ms)
        stimTime = 1000	% Stimulus duration (ms)
        tailTime = 1000	% Stimulus trailing duration (ms)
        
        numberOfContrastSteps = 5       % Number of contrast steps, not including laser activation
        minContrast = 0.02              % Minimum contrast (0-1)
        maxContrast = 1                 % Maximum contrast (0-1)
        
        intensity = 1;

        numberOfCycles = 3;      

        numericalAperture = 1.0; % NA of microscope objective
        objectiveMagnification = 20; %magnification of the objective, e.g. 20X
        beamWidth = 1.2e-3 * 3.5; %the 1/e^2 width of the beam on the back aperture of the objective, approximately the diameter exiting the laser times the input magnification
        focalPlaneToOuterSegmentDistance = 110; % distance in microns between laser FP and cone OS
        laserPower = 3.0; %laser power in mW, used to fit results

        scanWidth = 700; % width of scanfield in microns
        scanHeight = 700; % height of scanfield in microns

        resonantMode = true; %whether to use resonant scanning
        spatialFillFraction = .9; %the proportion of angular range for which the pockels cell is open (resonant mode)
        
        linesPerFrame = 512; %resolution of scanfield in pixels (resonant mode)
        linePeriod  = 63.21; %period of a line in microseconds (resonant mode)
        pulseRate = 80; %laser frequency, in MHz (resonant mode)      

        
    end
    
    properties (Hidden)
        
        responsePlotMode = 'cartesian';
        responsePlotSplitParameter = 'contrast';

        contrastValues                  % Linspace range between min and max contrast for given contrast steps
        intensityValues                 % Spot meanLevel * (1 + contrast Values)
        contrast                        % Spot contrast value for current epoch @see prepareEpoch
        intensity                       % Spot intensity value for current epoch @see prepareEpoch
    
        sizeX                           % Width of the visual stimulus in um
        sizeY                           % Height of the visual stimulus in um
    end
    
    properties (Hidden, Dependent)
        totalNumEpochs
    end
    
    methods
        
        function prepareRun(obj)
            prepareRun@sa_labs.protocols.StageProtocol(obj);
            
            if obj.meanLevel == 0
                warning('Contrast calculation is undefined when mean level is zero');
            end
            
            obj.contrastValues = [0, 2.^linspace(log2(obj.minContrast), log2(obj.maxContrast), obj.numberOfContrastSteps)];
            
            
            obj.intensityValues = obj.meanLevel + (obj.contrastValues .* obj.meanLevel);

            %% simulate the laser activation field
            dxy = 1e-2; %simulation resolution (um)
            
            % 1) create a matrix, with the profile of the beam on the photoreceptors
            % requires knowing the beam profile, objective NA, refractive index (1.333), and distance to outer segments form focal plane
            % of these, the hardest to measure is the beam profile; can use a 3d psf, a beam profiler device, or assume shape (clipped gaussian) based on magnification, assuming good alignment

            Ar = tan(asin(obj.numericalAperture./1.333)) .* obj.focalPlaneToOuterSegmentDistance; %radius of outer segment activation (um)
            Arq = round(Ar./dxy);% .* dxy;
            [spreadx,spready] = meshgrid((-Arq:Arq)*dxy, (-Arq:Arq)*dxy);
            spreadNorm = (spreadx.^2 + spready.^2);

            %model the beam as a clipped gaussian, squared by the 2 photon effect
            w = obj.beamWidth * obj.objectiveMagnification;
            

            spread =  exp(-2 .* spreadNorm ./ w.^2) .* (spreadNorm < Ar.^2) .^2; 


            % 2) create a scan matrix: 1 where the pulses occur, 0 otherwise
            scanq = round([obj.scanWidth, obj.scanHeight]./dxy);% .* dxy;

            xx = -obj.scanWidth/2 - Ar: dxy: obj.scanWidth/2 + Ar;
            yy = -obj.scanHeight/2 - Ar: dxy: obj.scanHeight/2 + Ar;
            [qx,qy] = meshgrid(xx, yy);
            qa = zeros(size(qx));

            if obj.resonantMode
                pulsePerLine = obj.linePeriod * obj.pulseRate;
                pulsePerFrame = pulsePerLine * obj.linesPerFrame;

                % the y position is linspaced
                y = linspace(-obj.scanHeight / 2, obj.scanHeight/ 2, pulsePerFrame);

                %the x position follows a sinewave
                % phase = -cos
                % amp = obj.scanWidth / obj.spatialFillFraction
                % freq = linesPerFrame / 2
                x = -obj.scanWidth / obj.spatialFillFraction / 2 * cos(linspace(0, pi*obj.linesPerFrame, obj.pulsePerFrame));

                % blank the laser -- assume perfect pockels cell performance
                y((x < -obj.scanWidth/2) | (x > -obj.scanWidth/2)) = [];
                x((x < -obj.scanWidth/2) | (x > -obj.scanWidth/2)) = [];

                %now we just find the closest points in qx/qy...
                [~,sx] = min(abs(x - xx'), [], 1); %TODO: check...
                [~,sy] = min(abs(y - yy'), [], 1);               

            else % we just assume an equal number of pulses per pixel (i.e., laser clock synchronization)
                % [sx,sy] = meshgrid(Ar+1 : dxy : Ar + obj.scanWidth, Ar+1 : dxy : Ar + obj.scanWidth);
                [sx,sy] = meshgrid(Arq + 1 : Arq + scanq(1), Arq+1 :Arq + scanq(2));
            end
            qa(sub2ind(size(qa), sy, sx)) = 1; %scan locations -- should be accumarray?
            

            % 3) convolve and normalize
            obj.imageMatrix = imfilter(qa, spread);
            obj.imageMatrix = obj.imageMatrix / max(obj.imageMatrix,[],'all');
            
            % the stimulus should match the laser up to a normalization factor, to be fit by comparing to contrast steps       

            obj.sizeX = (scanq(1) + 2*Arq) * dxy;
            obj.sizeY = (scanq(2) + 2*Arq) * dxy;


        end

        function prepareEpoch(obj, epoch)

            index = mod(obj.numEpochsPrepared, obj.numberOfContrastSteps + 1);
            if index == 0
                reorder = randperm(obj.numberOfContrastSteps);
                obj.contrastValues = obj.contrastValues(reorder);
                obj.intensityValues = obj.intensityValues(reorder);
            end
            
            obj.contrast = obj.contrastValues(index + 1);
            obj.intensity = obj.intensityValues(index + 1);
            epoch.addParameter('contrast', obj.contrast);
            epoch.addParameter('intensity', obj.intensity);

            if obj.intensity == 0 %trigger the scanhead
                obj.scanHeadTrigger = true;
            else
                obj.scanHeadTrigger = false;
            end
            
            prepareEpoch@sa_labs.protocols.StageProtocol(obj, epoch);
        end
        
        
        function p = createPresentation(obj)
            canvasSize = obj.rig.getDevice('Stage').getCanvasSize();                   
            p = stage.core.Presentation((obj.preTime + obj.stimTime + obj.tailTime) * 1e-3);
            

            stim = stage.builtin.stimuli.Image(obj.imageMatrix * obj.intensity);
            stim.size = obj.um2pix([obj.sizeX, obj.sizeY]);
            stim.position = canvasSize / 2;
            p.addStimulus(stim);
            
            stimVisible = stage.builtin.controllers.PropertyController(stim, 'opacity', ...
                @(state)state.time >= obj.preTime * 1e-3 && state.time < (obj.preTime + obj.stimTime) * 1e-3);
            p.addController(stimVisible);
        end
               
        function totalNumEpochs = get.totalNumEpochs(obj)
            totalNumEpochs = obj.numberOfCycles * (obj.numberOfContrastSteps + 1);
        end
        
    end
    
end