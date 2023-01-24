classdef RigCameraControl < symphonyui.ui.Module

    properties
        display
        nrows = 3
        ncols = 3
        overlap = .1
        width = 720
        height = 480
        correction = false
    end
    
    properties(Access = private)
        img = []
        frms = {};
        tforms = {};
        
        lastx = [];
        lasty = [];
        lastpos = [];
        lastmag = ''; 
        
    end

    properties (Dependent)
        mag
    end

    properties (Hidden)
        mags = {'10X','60X'}
        mag_ind = 1
        
    end

    methods
        function createUi(self, figure_handle)
            set(figure_handle,...
                'Name','Rig Camera',...
                'Position', appbox.screenCenter(500, 550));

            layout = uix.VBox(...
                'parent', figure_handle,...
                'padding', 8);

            menu = uix.HBox(...
                'parent', layout,...
                'padding', 8);

            uicontrol(...
                'parent',menu,...
                'style','edit',...
                'string',self.nrows,...
                'Callback', @self.onSetNRows);

            uicontrol(...
                'parent',menu,...
                'style','text',...
                'string','-by-');
            
            uicontrol(...
                'parent',menu,...
                'style','edit',...
                'string',self.ncols,...
                'Callback',@self.onSetNCols);
            
            uicontrol(...
                'parent',menu,...
                'style','togglebutton',...
                'string','Illumination filter',...
                'value', self.correction,...
                'Callback', @self.onSetCorrection);
            
            uicontrol(...
                'parent',menu,...
                'style','text',...
                'string','Relative overlap: ');            
            
            uicontrol(...
                'parent',menu,...
                'style','edit',...
                'string',self.overlap,...
                'Callback',@self.onSetOverlap);
            
            uicontrol(...
                'parent',menu,...
                'style','listbox',...
                'string',self.mags,...
                'value',self.mag_ind,...
                'Callback',@self.onSetMag);   
            
            buttons = uix.VBox(...
                'parent', menu,...
                'padding', 1);

            uicontrol(...
                'parent',buttons,...
                'style','pushbutton',...
                'string','Start',...
                'Callback',@self.start);

            uicontrol(...
                'parent',buttons,...
                'style','pushbutton',...
                'string','Save',...
                'Callback',@self.save);

            self.display = axes(...
                'parent',layout);

            set(layout, 'Heights', [50, -1]);
            
            
        end

        function self = onSetNRows(self, e, ~)
            self.nrows = str2double(e.String);
        end
        
        function self = onSetNCols(self, e, ~)
            self.ncols = str2double(e.String);
        end
        
        function self = onSetCorrection(self, e, ~)
            self.correction = e.Value;
        end

        function self = onSetOverlap(self, e, ~) 
            self.overlap = str2double(e.String);
        end
        
        function self = onSetMag(self, e, ~) 
            self.mag_ind = e.Value;
        end        

        function mag = get.mag(self)
            mag = self.mags{self.mag_ind};
        end

        function um = pix2um(self, pix)
            %% TODO: these need to be calibrated appropriately
            % ideally as part of the rig config
            
            switch self.lastmag
            case '10X'
                um = 1.3783 * pix;
%                 um = 1.5 * pix;
            case '60X'
                um = 0.2417 * pix;
%                 um = 0.65 * pix;
            otherwise
                error('Unknown magnification');
            end
        end
        
        %%
        function start(self, ~, ~)      
            %% clear the display
            cla(self.display);
            set(self.display,'color','none');
            drawnow;

            %% get handles to the devices
            camera = self.configurationService.getDevice('RigCamera');
            stage = Stage.Stage();
            self.lastpos = stage.pos;


            %% configure the image settings
            self.lastmag = self.mag;
            scale = (1-self.overlap) .* self.pix2um([self.width, self.height]);
            [x,y] = meshgrid( - (self.ncols/2 - .5) :  (self.ncols/2 - .5), - (self.nrows/2 - .5) :  (self.nrows/2 - .5));
            
            self.lastx = round(- x .* scale(1))';
            self.lasty = round(y .* scale(2))';
            x = [self.lastx(:); 0];
            y = [self.lasty(:); 0];
            
            stage.pos = self.lastpos + [x(1), y(1), 0]'; %initiate the first movement, while we continue setting up

            %% configure the stitching settings
            glob = imref2d([... %the global view onto which images will be warped
                round((self.width * self.ncols) - (self.overlap* self.width * (self.ncols-1))), ...
                round((self.height * self.nrows) - (self.overlap* self.height * (self.nrows-1)))]);
            [opt, met] = imregconfig('monomodal');
            grads = cell(self.nrows, self.ncols);
            self.tforms = cell(self.nrows, self.ncols);
            self.frms = cell(self.nrows, self.ncols);
            
            imgs = nan(...
                round((self.width * self.ncols) - (self.overlap* self.width * (self.ncols-1))), ...
                round((self.height * self.nrows) - (self.overlap* self.height * (self.nrows-1))), ...
                self.nrows * self.ncols, 'single');

            dr = self.height * (1 - self.overlap);% + 50;
            dc = self.width * (1 - self.overlap);% + 50; 
            pause(0.05);
            for r = 1:self.nrows
                for c = 1:self.ncols
                    %% move to (x,y)
                    while stage.status % make sure we've finished moving
%                         pause(1-self.overlap); %helps with motion blur
                    end
                    pause(1-self.overlap);
                    
                    %% take image   
                    frm = camera.getFrame();
                    self.frms{r,c} = single(squeeze(frm(1,:,:)));
                    for n = 1:4
                        frm = camera.getFrame();
                        self.frms{r,c} = self.frms{r,c} + single(squeeze(frm(1,:,:)));
                    end
                    self.frms{r,c} = self.frms{r,c} / 5;
                    
                    %% initiate move to next location
                    stage.pos = self.lastpos + [x(c + self.ncols*(r-1) + 1), y(c + self.ncols*(r-1) + 1), 0]';
                    
                    %% prepare image for stitching image
                    grads{r,c} = imgradient(self.frms{r,c});
                    %NOTE: we use the gradient to filter out lowpass artifacts
                    % these are mostly due to uneven illumination of the imaging field

                    %% align image
                    if r == 1 && c == 1
                        self.tforms{r,c} = affine2d([1,0,0;0,1,0;0,0,1]);                        
                    else                        
                        if c == 1
                            g = grads{r-1,c};
                            t = self.tforms{r-1,c};
                            a = affine2d([1,0,0;0,1,0;dr,0,1]);
                        else
                            g = grads{r,c-1};
                            t = self.tforms{r,c-1};
                            a = affine2d([1,0,0;0,1,0;0,dc,1]);
                        end
                        tform = imregtform(...
                                grads{r,c}(50:end-50,50:end-50),g(50:end-50,50:end-50),... 
                                'translation', opt, met,...
                                'initialtransformation',a...
                                );
                        self.tforms{r,c} = affine2d(tform.T * t.T); %compose the transforms
                    end
                    imgs(:,:,c + self.ncols*(r-1)) = imwarp(self.frms{r,c}, self.tforms{r,c}, 'outputview', glob, 'fillvalues', nan);
                    
                    %% stitch
                    self.img = nanmean(imgs, 3)';

                    %% display
                    imagesc(self.display,self.img);
                    axis(self.display, 'xy')
                    colormap(self.display, gray(256));
                    drawnow;
                end
            end
            
            %% remove illumination artifact
            if self.correction
                frms_ = cat(3,self.frms{:});
                artifact = imgaussfilt(median(frms_,3),5);
                for i=1:size(imgs,3)
                    imgs(:,:,i) = imwarp(self.frms{i}-artifact, self.tforms{i}, 'outputview',glob,'fillvalues',nan);
                end
                self.img = nanmean(imgs, 3)';
                self.img = self.img - min(self.img,[],'all') + min(frms_,[],'all');

                imagesc(self.display,self.img);
                axis(self.display, 'xy')
                colormap(self.display, gray(256));
                drawnow;
            end
            %% clean up
            delete(stage);

        end
        
        function save(self, ~, ~)
            %mkdir
            [fname, path] = uiputfile('*.tif','Select location for stitched image',sprintf('%s_stitched.tif',datestr(datetime('today'), 'mmddyyB')));
            [~,fname_noext,~] = fileparts(fname);
            
            tif = Tiff(sprintf('%s%s%s',path,filesep,fname), 'w');
            tif.setTag('ImageLength', size(self.img,1));
            tif.setTag('ImageWidth', size(self.img,2));
            tif.setTag('Photometric', Tiff.Photometric.MinIsBlack);
            tif.setTag('BitsPerSample', 8);
            tif.setTag('SamplesPerPixel', 1);
            tif.setTag('PlanarConfiguration', Tiff.PlanarConfiguration.Chunky);
            tif.setTag('RowsPerStrip', 16);
            tif.setTag('ResolutionUnit',Tiff.ResolutionUnit.Centimeter);
            tif.setTag('XResolution', 10000/self.pix2um(1));
            tif.setTag('YResolution', 10000/self.pix2um(1));
            
            tif.write(flipud(uint8(self.img)));
            
            tif.close();
            if numel(self.frms) == 1
                return
            end
            for i=1:numel(self.frms)
                
                
                comment = sprintf(...
                    'Stage coordinates (um): %d,%d,%d. Relative coordinates (um): %d,%d. Estimated translation (um): %f,%f.',...
                    self.lastpos(1) + self.lastx(i), self.lastpos(2) + self.lasty(i), self.lastpos(3),...
                    self.lastx(i), self.lasty(i),...
                    self.pix2um(self.tforms{i}.T(3)), self.pix2um(self.tforms{i}.T(6))... 
                    );
                tif = Tiff(sprintf('%s%s%s_%03d.tif',path,filesep,fname_noext,i), 'w');
                
                tif.setTag('ImageLength', size(self.frms{i},2));
                tif.setTag('ImageWidth', size(self.frms{i},1));
                tif.setTag('Photometric', Tiff.Photometric.MinIsBlack);
                tif.setTag('BitsPerSample', 8);
                tif.setTag('SamplesPerPixel', 1);
                tif.setTag('PlanarConfiguration', Tiff.PlanarConfiguration.Chunky);
                tif.setTag('RowsPerStrip', 16);
                tif.setTag('ResolutionUnit',Tiff.ResolutionUnit.Centimeter);
                tif.setTag('XResolution', 10000/self.pix2um(1));
                tif.setTag('YResolution', 10000/self.pix2um(1));
                tif.setTag('ImageDescription', comment);
                
                tif.write(flipud(uint8(self.frms{i})'));
                
                tif.close();
            end
            
            
        end
    end

end