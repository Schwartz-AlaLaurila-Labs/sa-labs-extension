function [Rstar, Mstar, Sstar ] = photoIsom2_triColor( bluIntenVal, grnIntenVal, uvIntenVal, color, fitBlue, fitGreen, fitUV, NDF_attenuation_Blue, NDF_attenuation_Green, NDF_attenuation_UV)
%R*, M*, S* for given intensity parameters


% Written by Adam Mani on 3/14
% adapted for Upper Projector TriColor Protocols by TA 3/16
% updated to symphony 2 by Sam 2/17

%intensity vs LED current fit coefficients (2nd deg polynmial)
%measured RigA Adam 3/28/14
%d=400um, units=nW

%4/14/14 photoIsom2, Adam:
%pass fitBlue, fitGreen as parameters, uW PER SQUARE MICRON.
%ANY degree polynomial

%fitBlue and fitGreen =1x(degree of poly+1) double.
%To get coefficients:
%1) Make a table of power vs LED intensity
%2) Divide power by spot area in square microns.
%3) Use cftool to fit a 2nd deg. polynomial and save its coefficients.



%scaling facotrs

uW_to_Watt = 10^(-6);

%photoreceptor area (MICRON^2)

pr_area = 0.37;
pr_area_rod = 0.5;

%INTENSITY IN WATTS PER ROD or CONE:
x = bluIntenVal;
y = polyval(fitBlue,x) * NDF_attenuation_Blue;
blueInten_rod = y.*uW_to_Watt.*pr_area_rod;
blueInten_cone = y.*uW_to_Watt.*pr_area;

x = grnIntenVal;
y = polyval(fitGreen,x) * NDF_attenuation_Green;
greenInten_rod = y.*uW_to_Watt.*pr_area_rod;
greenInten_cone = y.*uW_to_Watt.*pr_area;

x = uvIntenVal;
y = polyval(fitUV,x) * NDF_attenuation_UV;
uvInten_rod = y.*uW_to_Watt.*pr_area_rod;
uvInten_cone = y.*uW_to_Watt.*pr_area;

%Spectra pre-factors for LED-photoreceptor combinations
%calculated using "calbrationPrefactorCalc_Adam"


% Values from Rig A UV projector, Sam 12/2018
blue_Scone = 5.1711e+15;
blue_Mcone = 3.7352e+18;
blue_Rod = 4.6671e+18;

uv_Scone = 1.6347e+18;
uv_Mcone = 1.1163e+18;
uv_Rod = 9.0849e+17;

green_Scone = 1.5964e+14;
green_Mcone = 3.3599e+18;
green_Rod = 2.2422e+18;




switch color
    case 'blue'
        B_on = 1;
        G_on=0;
        UV_on = 0;
    case 'green'
        B_on = 0;
        G_on = 1;
        UV_on = 0;
    case 'uv'
        G_on = 0;
        B_on = 0;
        UV_on = 1;
    case 'blue+green'
        G_on = 1;
        B_on = 1;
        UV_on = 0;
    case 'green+uv'
        G_on = 1;
        B_on = 0;
        UV_on = 1;
    case 'blue+uv'
        G_on = 0;
        B_on = 1;
        UV_on = 1;
    case 'blue+uv+green'
        G_on = 1;
        B_on = 1;
        UV_on = 1;
    otherwise
        G_on = 0;
        B_on = 0;
        UV_on = 0;
end

%PHOTOISOMERIZATIONS:
Rstar = blue_Rod.*blueInten_rod.*B_on + green_Rod.*greenInten_rod.*G_on + uv_Rod*uvInten_rod.*UV_on;
Mstar = blue_Mcone.*blueInten_cone.*B_on + green_Mcone.*greenInten_cone.*G_on + uv_Mcone.*uvInten_cone.*UV_on;
Sstar = blue_Scone.*blueInten_cone.*B_on + green_Scone.*greenInten_cone.*G_on + uv_Scone.*uvInten_cone.*UV_on;

end

