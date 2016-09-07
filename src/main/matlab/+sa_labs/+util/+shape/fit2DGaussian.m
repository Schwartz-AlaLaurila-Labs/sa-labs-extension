function gaussianFitParams = fit2DGaussian(positions, responses)

%% Fit a 2d gaussian to the data
    function F = gauss_2d(x,xdata)
%          F = x(1)*exp(   -((xdata(:,1)-x(2)).^2/(2*x(3)^2) + (xdata(:,2)-x(4)).^2/(2*x(5)^2) )    );
        xdatarot(:,1)= xdata(:,1)*cos(x(6)) - xdata(:,2)*sin(x(6));
        xdatarot(:,2)= xdata(:,1)*sin(x(6)) + xdata(:,2)*cos(x(6));
        x0rot = x(2)*cos(x(6)) - x(4)*sin(x(6));
        y0rot = x(2)*sin(x(6)) + x(4)*cos(x(6));
        
        F = x(1)*exp(   -((xdatarot(:,1)-x0rot).^2/(2*x(3)^2) + (xdatarot(:,2)-y0rot).^2/(2*x(5)^2) )    );
%         F(F < 0) = 0;
    end

% add zero positions far away in corners to keep gaussian fit reasonable
num_positions = size(positions,1);
g_num_positions = num_positions;% + 4;
g_all_positions = positions;% vertcat(positions, 1000*[-1, -1; -1, 1; 1, 1; 1, -1]);
g_responses = responses - min(responses);%vertcat(responses, zeros(4,1));

x0 = [1,0,50,0,50,pi/4];

lb = [0,-g_num_positions/2,0,-g_num_positions/2,0,0];
ub = [realmax('double'),g_num_positions/2,(g_num_positions/2)^2,g_num_positions/2,(g_num_positions/2)^2,pi/2];
opts = optimset('Display','off');

[gaussianFitParams,~,~,~] = lsqcurvefit(@gauss_2d,x0,g_all_positions,g_responses,lb,ub,opts);

keys = {'amplitude','centerX','sigma2X','centerY','sigma2Y','angle'};
gaussianFitParams = containers.Map(keys, gaussianFitParams);
% [Amplitude, x0, sigmax, y0, sigmay] = x;

end