function setSizes(h, sizes)
%SA_LABS.UTIL.UI.SETSIZES  Set child sizes of a box (replacement for set(box,'Heights'|'Widths',...)).
%   sa_labs.util.ui.setSizes(vb, [-1 -1 30])   % two weighted rows and a 30 px row
%   Negative = weight for the remaining space, positive = fixed pixels. A box
%   created with vbox interprets these as heights, one created with hbox as widths.
    if isnumeric(h) && all(isgraphics(h))
        h = handle(h);          % numeric graphics handle (e.g. stored in a double array)
    end
    if ~isgraphics(h) || ~isappdata(h, 'sa_labs_layout')
        error('sa_labs:ui:notABox', 'setSizes expects a box created by sa_labs.util.ui.vbox/hbox');
    end
    spec = getappdata(h, 'sa_labs_layout');
    spec.sizes = sizes(:)';
    setappdata(h, 'sa_labs_layout', spec);
    sa_labs.util.ui.internal.layout(h);
end
