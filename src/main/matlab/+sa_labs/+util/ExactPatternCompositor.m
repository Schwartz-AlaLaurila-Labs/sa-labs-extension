classdef ExactPatternCompositor < stage.builtin.compositors.PatternCompositor
% pattern rendering without multisample-based anti-aliasing
    methods
        function drawFrame(obj, stimuli, controllers, state)
            ms = glIsEnabled(GL.MULTISAMPLE);
            ls = glIsEnabled(GL.LINE_SMOOTH);
            ps = glIsEnabled(GL.POLYGON_SMOOTH);
            d = glIsEnabled(GL.DITHER);
            

            sm = glGetInteger64v(GL.SHADE_MODEL);

            glDisable(GL.MULTISAMPLE);
            glDisable(GL.LINE_SMOOTH);
            glDisable(GL.POLYGON_SMOOTH);
            glDisable(GL.DITHER);
            glShadeModel(GL.FLAT);
            

            glHint(GL.LINE_SMOOTH_HINT, GL_FASTEST);
            glHint(GL.POLYGON_SMOOTH_HINT, GL_FASTEST);
            glHint(GL.PERSPECTIVE_CORRECTION_HINT, GL_FASTEST);

            drawFrame@stage.builtin.compositors.PatternCompositor(obj, stimuli, controllers, state);
            
            if ms
                glEnable(GL.MULTISAMPLE);
            end
            if ls
                glEnable(GL.LINE_SMOOTH);
                glHint(GL.LINE_SMOOTH_HINT, GL_NICEST);
            end
            if ps
                glEnable(GL.POLYGON_SMOOTH);
                glHint(GL.POLYGON_SMOOTH_HINT, GL_NICEST);
            end
            if d
                glEnable(GL.DITHER);
                glHint(GL.PERSPECTIVE_CORRECTION_HINT, GL_NICEST); % ?
            end
            glShadeModel(sm);
        end
    end
end