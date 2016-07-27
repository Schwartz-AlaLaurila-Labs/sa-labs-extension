classdef (Abstract) EpochGroup < symphonyui.core.persistent.descriptions.EpochGroupDescription
    
    methods
        
        function obj = EpochGroup()
            import symphonyui.core.*;
            
            obj.addProperty('externalSolutionAdditions', {}, ...
                'type', PropertyType('cellstr', 'row', {'NBQX (10uM)', 'DAPV (50uM)', 'APB (10uM)', 'LY 341495 (10uM)', 'strychnine (0.5uM)', 'strychnine (25uM)', 'gabazine (10uM)', 'gabazine (25uM)', 'TPMPA (50uM)', 'TTX (100nM)', 'TTX (500nM)'}));
            obj.addProperty('pipetteSolution', '', ...
                'type', PropertyType('char', 'row', {'', 'cesium', 'potassium', 'potassium zero calcium buffer', 'full chloride cesium', 'Ames'}));
            obj.addProperty('internalSolutionAdditions', '');
            obj.addProperty('recordingTechnique', '', ...
                'type', PropertyType('char', 'row', {'', 'cell-attached', 'whole-cell', 'perforated patch', 'suction'}));
            obj.addProperty('seriesResistanceCompensation', int32(0), ...
                'type', PropertyType('int32', 'scalar', [0 100]));
        end
        
    end
    
end

