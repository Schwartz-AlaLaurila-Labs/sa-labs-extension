% Add the script in symphony startup path
%   Wait till you start the stage server and select the rig configuration
%   from the symphony
 
!matlab -nodesktop -nosplash -r "info = matlab.apputil.getInstalledAppInfo; addpath(genpath(info(ismember({info.name}, 'Symphony')).location)); addpath(genpath(fileparts(which('startStage.m')))); matlab.apputil.run(info(ismember({info.name}, 'Stage Server')).id);" &