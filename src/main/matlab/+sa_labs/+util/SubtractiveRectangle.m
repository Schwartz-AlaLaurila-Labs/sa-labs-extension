classdef SubtractiveRectangle < stage.builtin.stimuli.Rectangle

    methods (Access=protected)
        function performDraw(obj)
            glBlendEquation(GL.FUNC_REVERSE_SUBTRACT);
            glBlendFuncSeparate(GL.ONE, GL.SRC_ALPHA, GL.ONE, GL.ZERO);
            %rgb = d_rgb - sa*s_rgb
            %a = d_a
            
            performDraw@stage.builtin.stimuli.Rectangle(obj);

            glBlendEquation(GL.FUNC_ADD);
            obj.canvas.resetBlend();
            
        end
    end
end