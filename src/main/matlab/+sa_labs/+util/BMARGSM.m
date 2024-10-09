function [x,y,u,v,z,t,x0,y0,u0,v0] = BMARGSM(tau,sigma,tauz,sigmaz,dt,T,Thex,radius,seed)

% tau - velocity time constant
% sigma - velocity variance
% tauz - scale generator time constant
% sigmaz - scale generator variance
% dt - time step (seconds)
% T - trial length (seconds)
% Thex - time at which position is constrained to a hexagon
% radius - hexagon radius
%
% x - horizontal position
% y - vertical position
% u - horizontal velocity
% v - vertical velocity
% z - scale generator
% *0 Gaussian control

s = RandStream('mt19937ar', 'Seed', seed);

D = sigma^2/tau*2;
Dz = sigmaz^2/tauz*2;

[u0,t] = sa_labs.util.OU(tau,D,dt,T,s);
[v0,~] = sa_labs.util.OU(tau,D,dt,T,s);
[z,~] = sa_labs.util.OU(tauz,Dz,dt,T,s);

u = u0.*exp(z)/exp(sigmaz^2);
v = v0.*exp(z)/exp(sigmaz^2);

x = cumsum(u*dt);
x = x-x(Thex/dt,:);
y = cumsum(v*dt);
y = y-y(Thex/dt,:);

p = 1;
q = 1;
while abs(q)>sqrt(3)/2 || q < sqrt(3)*(abs(p)-1) || q > sqrt(3)*(1-abs(p))
    p = 2*rand(s)-1;
    q = 2*rand(s)-1;
end

x = x+radius*p;
y = y+radius*q;

x0 = cumsum(u0*dt);
x0 = x0-x0(Thex/dt,:);
y0 = cumsum(v0*dt);
y0 = y0-y0(Thex/dt,:);

x0 = x0+radius*p;
y0 = y0+radius*q;