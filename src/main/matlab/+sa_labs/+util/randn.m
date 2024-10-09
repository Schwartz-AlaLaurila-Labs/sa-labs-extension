function [o1,o2] = randn(varargin)
% generates random normal values using the Box-Muller transform
% generated values are portable since they are generated directly from rand()

% this implementation is significantly slower than the built-in randn

r1 = rand(varargin{:});
r2 = rand(varargin{:});

r = sqrt(-2*log(r1));

o1 = r .* cos(2*pi*r2);
o2 = r .* sin(2*pi*r2);

end