function h = buttonbox(orientation, varargin)
%SA_LABS.UTIL.UI.BUTTONBOX  Replacement for uix.HButtonBox / uix.VButtonBox.
%
%   h = sa_labs.util.ui.buttonbox('horizontal', 'Parent', p, 'ButtonSize', [100 30], ...
%                                 'Spacing', 5, 'HorizontalAlignment', 'center')
%
%   Every child gets the same fixed ButtonSize and the row (or column) is
%   aligned inside the panel: HorizontalAlignment 'left'|'center'|'right',
%   VerticalAlignment 'top'|'middle'|'bottom'. Returns a borderless uipanel.

    ip = inputParser();
    ip.KeepUnmatched = true;
    ip.addParameter('Parent', [], @(x) isempty(x) || isgraphics(x));
    ip.addParameter('ButtonSize', [100 25], @(x) isnumeric(x) && numel(x) == 2);
    ip.addParameter('Spacing', 5, @(x) isnumeric(x) && isscalar(x));
    ip.addParameter('Padding', 0, @(x) isnumeric(x) && isscalar(x));
    ip.addParameter('HorizontalAlignment', 'center', @ischar);
    ip.addParameter('VerticalAlignment', 'middle', @ischar);
    ip.parse(varargin{:});
    r = ip.Results;

    args = {'BorderType', 'none', 'Units', 'normalized', 'Position', [0 0 1 1]};
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
    spec.kind = 'buttonbox';
    spec.orientation = validatestring(orientation, {'vertical', 'horizontal'});
    spec.buttonSize = r.ButtonSize(:)';
    spec.spacing = r.Spacing;
    spec.padding = r.Padding;
    spec.horizontalAlignment = validatestring(r.HorizontalAlignment, {'left', 'center', 'right'});
    spec.verticalAlignment = validatestring(r.VerticalAlignment, {'top', 'middle', 'bottom'});
    sa_labs.util.ui.internal.attach(h, spec);
end
