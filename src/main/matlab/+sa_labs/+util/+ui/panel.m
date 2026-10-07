function h = panel(varargin)
%SA_LABS.UTIL.UI.PANEL  Titled panel whose single child fills it (replacement for uix.Panel).
%   h = sa_labs.util.ui.panel('Parent', p, 'Title', 'Settings', 'Padding', 5)
%   Put one child in it (typically a vbox/hbox); it is stretched to the panel.

    ip = inputParser();
    ip.KeepUnmatched = true;
    ip.addParameter('Parent', [], @(x) isempty(x) || isgraphics(x));
    ip.addParameter('Title', '', @(x) ischar(x) || isstring(x));
    ip.addParameter('Padding', 0, @(x) isnumeric(x) && isscalar(x));
    ip.addParameter('BorderType', 'etchedin', @ischar);
    ip.parse(varargin{:});
    r = ip.Results;

    args = {'Title', char(r.Title), 'BorderType', r.BorderType, 'Units', 'normalized', 'Position', [0 0 1 1]};
    if ~isempty(r.Parent)
        args = [{'Parent', r.Parent}, args];
    end
    extra = ip.Unmatched;
    fn = fieldnames(extra);
    for i = 1:numel(fn)
        args = [args, {fn{i}, extra.(fn{i})}]; %#ok<AGROW>
    end
    h = uipanel(args{:});

    spec = struct();
    spec.kind = 'fill';
    spec.padding = r.Padding;
    spec.spacing = 0;
    sa_labs.util.ui.internal.attach(h, spec);
end
