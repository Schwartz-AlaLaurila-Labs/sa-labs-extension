function h = vbox(varargin)
%SA_LABS.UTIL.UI.VBOX  Vertical box (replacement for uix.VBox / uix.VBoxFlex).
%   h = sa_labs.util.ui.vbox('Parent', p, 'Spacing', 10, 'Padding', 0, 'Heights', [-1 30])
%   Children stack top to bottom in creation order. See sa_labs.util.ui.box.
    h = sa_labs.util.ui.box('vertical', varargin{:});
end
