function [Rstar, Mstar, Sstar ] = photoIsom2( bluIntenVal, grnIntenVal, color, fitBlue, fitGreen)
%R*, M*, S* for given intensity parameters


%Written by Adam Mani on 3/31/14   

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
    y = polyval(fitBlue,x);    %any degree
    blueInten_rod = y.*uW_to_Watt.*pr_area_rod;
    blueInten_cone = y.*uW_to_Watt.*pr_area;

    x = grnIntenVal;
    y = polyval(fitGreen,x);  
    greenInten_rod = y.*uW_to_Watt.*pr_area_rod;
    greenInten_cone = y.*uW_to_Watt.*pr_area;

    
    %Spectra pre-factors for LED-photoreceptor combinations
    %calculated using "calbrationPrefactorCalc_Adam"
    %Adam 3/31/14
    
    red_Scone = 8.9029e+16;
    red_Mcone = 4.2808e+17;
    red_Rod = 3.2696e+17;
    
    green_Scone = 1.4226e+14;
    green_Mcone = 5.0880e+18;
    green_Rod = 3.8330e+18;
    
    blue_Scone = 2.4851e+15;
    blue_Mcone = 3.8350e+18;
    blue_Rod = 4.7954e+18;

    %Keep only LEDs that are ON:
    switch color
        case 'blue'
            B_on = 1;
            G_on=0;
        case 'green'
            B_on = 0;
            G_on = 1;
        case 'blue+green'
            G_on = 1;
            B_on = 1;
        otherwise
            G_on = 0;
            B_on = 0;      
    end    
    
    
    %PHOTOISOMERIZATIONS:
    Rstar = blue_Rod.*blueInten_rod.*B_on + green_Rod*greenInten_rod.*G_on;
    Mstar = blue_Mcone.*blueInten_cone.*B_on + green_Mcone*greenInten_cone.*G_on;
    Sstar = blue_Scone.*blueInten_cone.*B_on + green_Scone*greenInten_cone.*G_on;
   
    
end

