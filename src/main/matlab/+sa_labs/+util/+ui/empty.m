function h = empty(varargin)
%SA_LABS.UTIL.UI.EMPTY  Invisible spacer child for a box (replacement for uix.Empty).
%   h = sa_labs.util.ui.empty('Parent', box)
    h = uipanel(varargin{:}, 'BorderType', 'none');
end
