function h = box(orientation, varargin)
%SA_LABS.UTIL.UI.BOX  GUI-Layout-Toolbox-free replacement for uix.HBox / uix.VBox.
%
%   h = sa_labs.util.ui.box('vertical',   'Parent', fig, 'Spacing', 10)
%   h = sa_labs.util.ui.box('horizontal', 'Parent', fig, 'Spacing', 10, 'Padding', 5)
%
%   Returns a plain uipanel (no border). Its children are laid out top-to-bottom
%   (vertical) or left-to-right (horizontal) in creation order, exactly like the
%   uix boxes: use sa_labs.util.ui.setSizes(h, sizes) where a negative value is a
%   weight for the remaining space (-1, -2, ...) and a positive value is a fixed
%   size in pixels. Children added later get weight -1. Layout re-runs on resize
%   and whenever a child is added or removed.
%
%   Children can be axes (laid out by OuterPosition so labels stay inside),
%   uicontainer / uipanel wrappers, uicontrols, or nested boxes. Works in both
%   classic figures (Symphony 3 figure handlers) and uifigures (modules).
%
%   See also sa_labs.util.ui.vbox, sa_labs.util.ui.hbox, sa_labs.util.ui.setSizes,
%   sa_labs.util.ui.buttonbox, sa_labs.util.ui.empty, sa_labs.util.ui.panel.

    ip = inputParser();
    ip.KeepUnmatched = true;
    ip.addParameter('Parent', [], @(x) isempty(x) || isgraphics(x));
    ip.addParameter('Spacing', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    ip.addParameter('Padding', 0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
    ip.addParameter('Heights', [], @isnumeric);
    ip.addParameter('Widths', [], @isnumeric);
    ip.addParameter('BackgroundColor', [], @(x) isempty(x) || ischar(x) || isnumeric(x));
    ip.parse(varargin{:});
    r = ip.Results;

    args = {'BorderType', 'none', 'Units', 'normalized', 'Position', [0 0 1 1]};
    if ~isempty(r.Parent)
        args = [{'Parent', r.Parent}, args];
    end
    if ~isempty(r.BackgroundColor)
        args = [args, {'BackgroundColor', r.BackgroundColor}];
    end
    extra = ip.Unmatched;
    fn = fieldnames(extra);
    for i = 1:numel(fn)
        args = [args, {fn{i}, extra.(fn{i})}]; %#ok<AGROW>
    end
    h = uipanel(args{:});

    spec = struct();
    spec.kind = 'box';
    spec.orientation = validatestring(orientation, {'vertical', 'horizontal'});
    spec.spacing = r.Spacing;
    spec.padding = r.Padding;
    if strcmp(spec.orientation, 'vertical')
        spec.sizes = r.Heights(:)';
    else
        spec.sizes = r.Widths(:)';
    end
    sa_labs.util.ui.internal.attach(h, spec);
end
