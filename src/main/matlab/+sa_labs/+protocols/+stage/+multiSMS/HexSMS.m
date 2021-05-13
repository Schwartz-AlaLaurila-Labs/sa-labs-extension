classdef HexSMS < sa_labs.protocols.stage.MultiSMS
    
    properties
        coverage = 2.5; % The average number of spots at each point in space for a given spot size. At ~0.9069 there is 0 overlap.
        
    end
    
    methods
        
        function spots = updateSpots(self)
            if self.logScaling
                S = logspace(log10(self.minSize), log10(self.maxSize), self.numberOfSizeSteps);
            else
                S = linspace(self.minSize, self.maxSize, self.numberOfSizeSteps);
            end
            spots = [];
            
            %coverage = 3pi/4 * spacing / (3sqrt(3)/2* diameter)
            spaceFactor = sqrt(3*pi/4 / self.coverage / (3*sqrt(3)/2));
            halfGrids = [self.gridX, self.gridY]/2;
            
            
            for i = numel(S):-1:1
                s = S(i);
                
                %space the spots to achieve the desired coverage factor
                %uses the ratio of the area of a hexagon to that of a circle
                spacing = spaceFactor * s;
                
                %find the x and y coordinates for the hex grid
                xa = [0:-spacing:-self.gridX/2-spacing, spacing:spacing:self.gridX/2+spacing];
                xb= [xa - spacing/2, xa(end)+spacing/2];
                
                yspacing = cos(pi/6)*spacing;
                
                ya = [0:-2*yspacing:-self.gridY/2-yspacing, 2*yspacing:2*yspacing:self.gridY/2+yspacing];
                yb = [ya - yspacing, ya(end) + yspacing];
                
                %create the grid
                [xqa, yqa] = meshgrid(xa,ya); %doing it in this order causes larger spots to be centered
                [xqb, yqb] = meshgrid(xb,yb);
                locs = [xqa(:), yqa(:); xqb(:), yqb(:)];
                
                %remove any circles that don't intersect the viewing rectangle
                % the bounding box of the circle must intersect the rectangle
                locs = locs(all(abs(locs) < halfGrids + s/2, 2), :);
                
                % circles near the corners might have an intersecting
                % bounding box but not actually intersect
                % if either of the coordinates is inside the box, it
                % definitely intersects
                % otherwise it must intersect the corner
                locs = locs(any(abs(locs) < halfGrids, 2) | 4*sum((abs(locs)-halfGrids).^2,2) <= s.^2 , :);
                
                spots=vertcat(spots,[locs, ones(size(locs,1),1)*s]); %#ok<AGROW>
            end
            
            self.spots = spots;
            
        end
    
        function setProperty(self, name, value)
            switch name
                case {'minSize', 'maxSize', 'numberOfSizeSteps',...
                        'gridX', 'gridY', 'coverage', 'logScaling'}
                    self.updated = false;
            end
            setProperty@sa_labs.protocols.stage.MultiSMS(self, name, value);
        end
        
    end
end
