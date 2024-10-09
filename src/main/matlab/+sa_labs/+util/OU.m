function [x,t] = OU(tau,D,dt,T,stream)

nt = round(T/dt);

mu = exp(-dt/tau);

sigma_x = sqrt(D*tau/2*(1-mu^2));

n = sa_labs.util.randn(stream,nt-1,1);

dx = sigma_x*n;

x = zeros(nt,1);

x(1) = sqrt(D*tau/2)*sa_labs.util.randn(stream,1);

for i = 1:nt-1
    x(i+1) = x(i)*mu+dx(i);
end

t = 0:dt:T-dt;