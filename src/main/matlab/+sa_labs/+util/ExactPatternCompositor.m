classdef ExactPatternCompositor < stage.builtin.compositors.PatternCompositor
% pattern rendering without multisample-based anti-aliasing
    methods
        function drawFrame(obj, stimuli, controllers, state)
            ms = glIsEnabled(GL.MULTISAMPLE);
            ls = glIsEnabled(GL.LINE_SMOOTH);
            ps = glIsEnabled(GL.POLYGON_SMOOTH);

            glDisable(GL.MULTISAMPLE);
            glDisable(GL.LINE_SMOOTH);
            glDisable(GL.POLYGON_SMOOTH);

            drawFrame@stage.builtin.compositors.PatternCompositor(obj, stimuli, controllers, state);
            
            if ms
                glEnable(GL.MULTISAMPLE);
            end
            if ls
                glEnable(GL.LINE_SMOOTH);
            end
            if ps
                glEnable(GL.POLYGON_SMOOTH);
            end
        end
    end
end