function attach(h, spec)
%SA_LABS.UTIL.UI.INTERNAL.ATTACH  Store a layout spec on a uipanel and keep it live.
%   Re-runs the layout when the panel resizes and when children are added or
%   removed. Listeners are kept in appdata so they live as long as the panel.

    setappdata(h, 'sa_labs_layout', spec);
    h.SizeChangedFcn = @(src, ~) sa_labs.util.ui.internal.layout(src);

    listeners = {};
    try
        listeners{end+1} = addlistener(h, 'ObjectChildAdded',   @(src, ~) sa_labs.util.ui.internal.layout(src));
        listeners{end+1} = addlistener(h, 'ObjectChildRemoved', @(src, ~) sa_labs.util.ui.internal.layout(src));
    catch
        % Older graphics objects without child events: layout still runs on
        % resize and on explicit setSizes calls.
    end
    setappdata(h, 'sa_labs_layout_listeners', listeners);
end
