classdef MultiSMSResponseFigure < symphonyui.core.FigureHandler
    
    properties
        protocol;
        
        stimPanel;
        stimAxes;
        stimIm;
        spotsA;
        spotsB;
        rectA;
        rectB;
        ratio = .3;
        opacity = .7;
        colors;
        cycle = 1;
        pyx;
        renderA;
        renderB;
        
        recordPanel;
        recordAxes;
        recordPlotA;
        recordPlotB;
        nChans;
        t;
        
        rightPanel;
        
        axesTitle;
        fmtString;
        
        epochNumber = 0;
    end
    
    methods
        function self = MultiSMSResponseFigure(protocol)
            disp('Creating figure');
            self@symphonyui.core.FigureHandler();
            self.protocol = protocol;
            
            [self.spotsA, self.rectA] = self.protocol.getSpots();
            [rads,~,radI] = unique(self.spotsA(:,3));
            nRads = numel(rads);
            self.spotsA = cat(2, self.spotsA, radI, zeros(size(self.spotsA,1),1));
            self.spotsA(:,3) = self.spotsA(:,3);
            if nRads > 7
                self.colors = colorcube(nRads);
            else
                self.colors = lines(nRads);
            end
            
            delta = 1e3/self.protocol.devices{1}.sampleRate.quantityInBaseUnits;
            self.t = -self.protocol.preTime:delta:self.protocol.stimTime+self.protocol.tailTime - delta; %need sample rate...
            
            set(self.figureHandle,'color',[0,.2,.4]);
            
            self.stimPanel = uipanel('Parent', self.figureHandle, 'Position',[0,.2,.7,.8],'Units','Normalized','backgroundColor','black',...
                'shadowcolor',[0,.8,1], 'highlightcolor',[0,.5,.7]);
            self.stimAxes = axes('Parent', self.stimPanel,'Position',[0,0,1,1],'Units','Normalized');
            self.stimIm = imshow(0, 'Parent', self.stimAxes);
            
            self.recordPanel = uipanel('Parent', self.figureHandle, 'Position',[0,0,.7,.2],'Units','Normalized','backgroundColor','black',...
                'shadowcolor',[0,.8,1], 'highlightcolor',[0,.5,.7]);
            self.recordAxes = axes('Parent', self.recordPanel,'Position',[0,0,1,1],'Units','Normalized',...
                'color','black','xcolor','white','ycolor','white','nextplot','replacechildren');
            box(self.recordAxes,'on');
            
            self.rightPanel = uipanel('Parent', self.figureHandle, 'Position',[.7,0,.3,1],'Units','Normalized','backgroundColor','black',...
                'shadowcolor',[0,.8,1], 'highlightcolor',[0,.5,.7]);
            
            if strcmpi(self.protocol.chan2,'none')
                self.nChans = 1;
                diffModes = false;
            else
                self.nChans = 2; %we will only plot up to 2 channels
                if strcmpi(self.protocol.devices{1}.background.baseUnits, self.protocol.devices{2}.background.baseUnits)
                    diffModes = false;
                else
                    diffModes = true;
                end
            end
            
            if diffModes
                yyaxis(self.recordAxes,'left');
                a = get(self.recordAxes,'yaxis');
                set(a(1),'color','g');
                set(a(2),'color','m');
                self.recordPlotA = plot(self.recordAxes,self.t,nan(size(self.t)),'color','g');
%                 ylabel(self.recordAxes, sprintf('Amplitude (%s)', self.protocol.devices{1}.background.displayUnits),...
%                     'color','g','units','normalized','position', [.025, .5, 0]);
                
                yyaxis(self.recordAxes,'right');
                self.recordPlotB = plot(self.recordAxes,self.t,nan(size(self.t)),'color','m');
%                 ylabel(self.recordAxes, sprintf('Amplitude (%s)', self.protocol.devices{2}.background.displayUnits),...
%                     'color','m','units','normalized','position', [.975, .5, 0]);
                
                yyaxis(self.recordAxes,'left');
            else
                if self.nChans == 1
                    self.recordPlotA = plot(self.recordAxes,self.t,nan(size(self.t)),'color','w');
                else
                    self.recordPlotA = plot(self.recordAxes,self.t,nan(size(self.t)),'color','g');
                    self.recordPlotB = plot(self.recordAxes,self.t,nan(size(self.t)),'color','m');
                end
%                 ylabel(self.recordAxes, sprintf('Amplitude (%s)', self.protocol.devices{1}.background.displayUnits),...
%                     'color','w','units','normalized','position', [.025, .5, 0]);
            end
            xline(self.recordAxes, 0,'color','w');
            xline(self.recordAxes, self.protocol.stimTime,'color','w');
            
            
            set(self.figureHandle,'name','Spots of Multiple Sizes at Multiple Locations')
            self.fmtString = sprintf('Cycle %s of %d, Stimulus %s of %d: cx = %s, cy = %s, diameter = %s',...
                '%d',self.protocol.numberOfCycles,'%d', size(self.spotsA,1), '%.1f', '%.1f', '%.1f');
            
            self.axesTitle = title(self.stimAxes, sprintf(self.fmtString, 0, 0, 0, 0, 0),'units','pixels','color','w','verticalalignment','top');
            set(self.axesTitle,'position',get(self.axesTitle,'position')-[0,10,0]);
            set(self.axesTitle,'units','normalized');
%             xlabel(self.recordAxes, 'Time (sec)', 'color','w','units','normalized','position',[.5,1,0]);
            
        end
        
        function update(self, pyx)
            %when the figure size changes we need to resize the pixel
            %buffer
            
            self.pyx = pyx;
            self.renderA = zeros([pyx, 3]);
            rat = min(self.pyx ./ self.rectA([4,3])) * self.ratio; %take the larger ratio
            
            self.rectB = self.rectA * rat;
            self.rectB(1:2) = self.rectB(1:2) + pyx([2,1])./2;
            
            self.spotsB =  self.spotsA;
            self.spotsB(:,1:2) = self.spotsB(:,1:2) .* rat;
            self.spotsB(:,2) = -self.spotsB(:,2);
            self.spotsB(:,3) = self.spotsB(:,3) .* .5 .* rat;
            
            self.spotsB(:,1:2) = self.spotsB(:,1:2) + pyx([2,1])./2;
            
            redraw = self.spotsB(self.spotsA(:,5) >= self.cycle,:);
            
            self.renderA = insertShape(self.renderA, 'circle', redraw(:,1:3), 'color', self.colors(redraw(:,4),:),'smoothedges', false);
            set(self.stimAxes,'xlim',[.5, size(self.renderA,2)+.5], 'ylim', [.5, size(self.renderA,1)+.5]);
        end
        
        function reset(self)
            %clears the state of the repsonse figure so it can be recycled
            
            self.spotsA(:,5) = 0;
            self.cycle = 1;
            
            set(self.stimPanel,'units','pixels');
            self.update(round(self.stimPanel.Position([4,3])));
            set(self.stimPanel,'units','normalized');
            
            self.renderB = insertShape(self.renderA, 'rectangle', self.rectB, 'color', 'white', 'linewidth', 3);
            
%             self.stimIm = imshow(self.renderB, 'parent', self.stimAxes);
            set(self.stimIm, 'cdata', self.renderB);
        end
        
        function handleEpoch(self, epoch)
            
            [~,thisSpotI] = min(sum(abs(self.spotsA(:,1:3) - [epoch.parameters('cx'), epoch.parameters('cy'), epoch.parameters('curSpotSize')]),2));
            
            if self.spotsA(thisSpotI,5) == self.cycle
                self.cycle = self.cycle + 1;
                self.epochNumber = 0;
            else
                self.epochNumber = self.epochNumber + 1;
            end
            
            self.drawStim(thisSpotI);
            
            
            
            %epoch.getResponse(self.protocol.devices{ci});
            %draw response
            set(self.recordPlotA,'ydata',epoch.getResponse(self.protocol.devices{1}).getData());
            if self.nChans>1
                set(self.recordPlotB,'ydata', epoch.getResponse(self.protocol.devices{2}).getData());
            end
            %draw rf(s)
            
            
            %finish
            set(self.axesTitle,'string',sprintf(self.fmtString, self.cycle, self.epochNumber, epoch.parameters('cx'), epoch.parameters('cy'), epoch.parameters('curSpotSize')));
            self.spotsA(thisSpotI,5) = self.cycle;
            
        end
        
        function drawStim(self, thisSpotI)
            %draws the stimulus illustration
            if self.epochNumber ==0 && self.cycle ~=1
                self.renderA(:) = 0;
            end
            
            
%             cla(self.stimAxes);
            
            set(self.stimPanel,'units','pixels');
            pyxB = round(self.stimPanel.Position([4,3]));
            set(self.stimPanel,'units','normalized');
            
            if any(pyxB ~= self.pyx)
                %we need to update the renderer
                self.update(pyxB);
            end
            
            
            self.renderB = insertShape(self.renderA, 'filledcircle', self.spotsB(thisSpotI,1:3), 'color', self.colors(self.spotsB(thisSpotI,4),:),'smoothedges', false, 'opacity', self.opacity);
            self.renderB = insertShape(self.renderB, 'rectangle', self.rectB, 'color', 'white', 'linewidth', 3);
            self.renderA = insertShape(self.renderA, 'circle', self.spotsB(thisSpotI,1:3), 'color', self.colors(self.spotsB(thisSpotI,4),:),'smoothedges', false);
            
%             imshow(self.renderB, 'parent', self.stimAxes);
            set(self.stimIm,'cdata',self.renderB);
            
        end
    end
end