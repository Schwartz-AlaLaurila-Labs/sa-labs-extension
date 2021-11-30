classdef Electrophysiology < symphonyui.core.persistent.descriptions.ExperimentDescription
    
    methods
        
        function obj = Electrophysiology()
            import symphonyui.core.*;
            
            obj.addProperty('experimenter', '', ...
                'description', 'Who performed the experiment');
            obj.addProperty('project', '', ...
                'description', 'Project the experiment belongs to');
            obj.addProperty('institution', '', ...
                'description', 'Institution where the experiment was performed');
            obj.addProperty('lab', '', ...
                'description', 'Lab where experiment was performed');
            
            d = pwd;
            cd(fileparts(which(class(obj))))
            [is_uncommitted,~] = system('git diff --exit-code');
            if is_uncommitted
                error('You have uncommitted changes in your sa-labs version. Commit them before proceeding. You can changes branches if necessary, but be sure to upload the branch to github.');
            end
            [~,branch] = system('git rev-parse --abbrev-ref --symbolic-full-name HEAD');
            branch = strtrim(branch);
            if strcmp(branch,'HEAD')
                error('Your sa-labs git HEAD is detached. You must attach to a valid branch before proceeding.');
            end
            
            [~,hash] = system('git rev-parse HEAD');
            hash = strtrim(hash);
            cd(d);
            
            obj.addProperty('branch',branch,...
                'description','The current branch for the sa_labs extension.',...
                'type',PropertyType('char','row',{branch}));
            obj.addProperty('commit',hash,...
                'description','The current git hash for the sa_labs extension.',...
                'type',PropertyType('char','row',{hash}));
            
        end
        
    end
    
end

