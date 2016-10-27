function [peaks,Ind] = getPeaks(X,dir)
if dir > 0 %local max
    Ind = find(diff(diff(X)>0)<0)+1;
else %local min
    Ind = find(diff(diff(X)>0)>0)+1;
end
peaks = X(Ind);