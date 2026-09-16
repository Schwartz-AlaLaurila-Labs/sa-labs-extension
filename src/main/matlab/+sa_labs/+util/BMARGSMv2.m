function [x,y,u,v,z,t,x0,y0,u0,v0,xhex,yhex] = BMARGSMv2(tau,sigma,tauz,sigmaz,dt,T,Thex,radius,Tburn,seed)

% tau - velocity time constant
% sigma - velocity variance
% tauz - scale generator time constant
% sigmaz - scale generator variance
% dt - time step (seconds)
% T - trial length (seconds)
% Thex - time at which position is constrained to a hexagon
% radius - hexagon radius
% Tburn - burn-in time
%
% x - horizontal position
% y - vertical position
% u - horizontal velocity
% v - vertical velocity
% z - scale generator
% *0 Gaussian control
% xhex,yhex - position at time Thex

s = RandStream('mt19937ar', 'Seed', seed);

nt = round((T+Tburn)/dt);
t = -Tburn:dt:T-dt;

phi = exp(-dt/tau);
phiz = exp(-dt/tauz);

unoise = sa_labs.util.randn(s,nt,1);
vnoise = sa_labs.util.randn(s,nt,1);
znoise = sa_labs.util.randn(s,nt,1);

u = zeros(nt,1);
v = zeros(nt,1);
u0 = zeros(nt,1);
v0 = zeros(nt,1);
z = zeros(nt,1);

z(1) = sigmaz*znoise(1);
u(1) = exp(z(1)-sigmaz^2)*sigma*unoise(1);
v(1) = exp(z(1)-sigmaz^2)*sigma*vnoise(1);
u0(1) = sigma*unoise(1);
v0(1) = sigma*vnoise(1);

for i = 2:nt
    u(i) = phi*u(i-1)+exp(z(i-1)-sigmaz^2)*sqrt(1-phi^2)*sigma*unoise(i);
    v(i) = phi*v(i-1)+exp(z(i-1)-sigmaz^2)*sqrt(1-phi^2)*sigma*vnoise(i);
    u0(i) = phi*u0(i-1)+sqrt(1-phi^2)*sigma*unoise(i);
    v0(i) = phi*v0(i-1)+sqrt(1-phi^2)*sigma*vnoise(i);
    z(i) = phiz*z(i-1)+sqrt(1-phiz^2)*sigmaz*znoise(i);
end

t = t(t>=0);
u = u(t>=0);
v = v(t>=0);
u0 = u0(t>=0);
v0 = v0(t>=0);
z = z(t>=0);

x = cumsum(u*dt);
x = x-x(Thex/dt,:);
y = cumsum(v*dt);
y = y-y(Thex/dt,:);

x0 = cumsum(u0*dt);
x0 = x0-x0(Thex/dt,:);
y0 = cumsum(v0*dt);
y0 = y0-y0(Thex/dt,:);

% switching p and q so that hex orientation is rotated 90 degrees relative
% to cell grid
p = 1;
q = 1;
while abs(q)>sqrt(3)/2 || q < sqrt(3)*(abs(p)-1) || q > sqrt(3)*(1-abs(p))
    p = 2*rand(s)-1;
    q = 2*rand(s)-1;
end

xhex = radius*q;
yhex = radius*p;

x = x+xhex;
y = y+yhex;

x0 = x0+xhex;
y0 = y0+yhex;