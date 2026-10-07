function h = hbox(varargin)
%SA_LABS.UTIL.UI.HBOX  Horizontal box (replacement for uix.HBox / uix.HBoxFlex).
%   h = sa_labs.util.ui.hbox('Parent', p, 'Spacing', 10, 'Padding', 0, 'Widths', [-3 80])
%   Children sit left to right in creation order. See sa_labs.util.ui.box.
    h = sa_labs.util.ui.box('horizontal', varargin{:});
end
