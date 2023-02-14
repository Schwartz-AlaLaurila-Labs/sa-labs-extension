classdef ExactPatternCompositor < stage.builtin.compositors.PatternCompositor
% pattern rendering without multisample-based anti-aliasing
    methods
        function drawFrame(obj, stimuli, controllers, state)
            s = glIsEnabled(GL.MULTISAMPLE);
            if s == GL.TRUE
                glDisable(GL.MULTISAMPLE);
                drawFrame@stage.builtin.compositors.PatternCompositor(obj, stimuli, controllers, state);
                glEnable(GL.MULTISAMPLE);
            else
                drawFrame@stage.builtin.compositors.PatternCompositor(obj, stimuli, controllers, state);
            end

        end
    end
end