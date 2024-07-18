function [x,y,u,v,z,t,x0,y0,u0,v0] = DHOARGSM(tau,omega0,D,tauz,Dz,dt,T,Tburn, seed)

% Discrete approximation to 2D damped harmonic oscillator driven by
% Gaussian scale-mixture noise with an Ornstein-Uhlenbeck scale generator 
% process and exponential nonlinearity
%
% DHO: dv/dt = -1/tau*v-omega0^2*x+sqrt(2*D)/tau*exp(z)*eta
%      dx/dt = v
% OU:  dz/dt = -1/tauz*z+sqrt(2*Dz)/tauz*etaz
%
% dt: time step
% T: simulation time
% Tburn: burn-in time
%
% (x,y): horizontal and vertical position
% (u,v): horizontal and vertical velocity
% z: scale generator
% t: time
% *0: non-GSM process with the same randomly generated noise scaled to
% average GSM scale

rng(seed);

n1 = randn(round(Tburn/dt)-1,1);
n2 = randn(round(Tburn/dt)-1,1);
n3 = randn(round(Tburn/dt)-1,1);

x = zeros(round(Tburn/dt),1);
y = zeros(round(Tburn/dt),1);
u = zeros(round(Tburn/dt),1);
v = zeros(round(Tburn/dt),1);
z = zeros(round(Tburn/dt),1);

x0 = zeros(round(Tburn/dt),1);
y0 = zeros(round(Tburn/dt),1);
u0 = zeros(round(Tburn/dt),1);
v0 = zeros(round(Tburn/dt),1);

for i = 1:Tburn/dt-1
    x(i+1) = x(i)+dt*u(i);
    u(i+1) = u(i)+dt*(-1/tau*u(i)-omega0^2*x(i))+sqrt(2*D*dt)/tau*exp(z(i))*n1(i);
    y(i+1) = y(i)+dt*v(i);
    v(i+1) = v(i)+dt*(-1/tau*v(i)-omega0^2*y(i))+sqrt(2*D*dt)/tau*exp(z(i))*n2(i);
    z(i+1) = z(i)+dt*(-1/tauz*z(i))+sqrt(2*Dz*dt)/tauz*n3(i);
    x0(i+1) = x0(i)+dt*u0(i);
    u0(i+1) = u0(i)+dt*(-1/tau*u0(i)-omega0^2*x0(i))+sqrt(2*D*dt)/tau*n1(i);
    y0(i+1) = y0(i)+dt*v0(i);
    v0(i+1) = v0(i)+dt*(-1/tau*v0(i)-omega0^2*y0(i))+sqrt(2*D*dt)/tau*n2(i);
end

x_ = x(end);
y_ = y(end);
u_ = u(end);
v_ = v(end);
z_ = z(end);

x0_ = x0(end);
y0_ = y0(end);
u0_ = u0(end);
v0_ = v0(end);

n1 = randn(round(T/dt)-1,1);
n2 = randn(round(T/dt)-1,1);
n3 = randn(round(T/dt)-1,1);

x = zeros(round(T/dt),1);
y = zeros(round(T/dt),1);
u = zeros(round(T/dt),1);
v = zeros(round(T/dt),1);
z = zeros(round(T/dt),1);

x0 = zeros(round(T/dt),1);
y0 = zeros(round(T/dt),1);
u0 = zeros(round(T/dt),1);
v0 = zeros(round(T/dt),1);

x(1) = x_;
y(1) = y_;
u(1) = u_;
v(1) = v_;
z(i) = z_;

x0(1) = x0_;
y0(1) = y0_;
u0(1) = u0_;
v0(1) = v0_;

for i = 1:T/dt-1
    x(i+1) = x(i)+dt*u(i);
    u(i+1) = u(i)+dt*(-1/tau*u(i)-omega0^2*x(i))+sqrt(2*D*dt)/tau*exp(z(i))*n1(i);
    y(i+1) = y(i)+dt*v(i);
    v(i+1) = v(i)+dt*(-1/tau*v(i)-omega0^2*y(i))+sqrt(2*D*dt)/tau*exp(z(i))*n2(i);
    z(i+1) = z(i)+dt*(-1/tauz*z(i))+sqrt(2*Dz*dt)/tauz*n3(i);
    x0(i+1) = x0(i)+dt*u0(i);
    u0(i+1) = u0(i)+dt*(-1/tau*u0(i)-omega0^2*x0(i))+sqrt(2*D*dt)/tau*exp(Dz/(2*tauz))*n1(i);
    y0(i+1) = y0(i)+dt*v0(i);
    v0(i+1) = v0(i)+dt*(-1/tau*v0(i)-omega0^2*y0(i))+sqrt(2*D*dt)/tau*exp(Dz/(2*tauz))*n2(i);
end

t = 0:dt:T-dt;