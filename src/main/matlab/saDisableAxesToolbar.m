function saDisableAxesToolbar(ax)
%SADISABLEAXESTOOLBAR  Stop the web axes hover-toolbar from ever being built.
%
%   Installed as the groot 'defaultAxesCreateFcn' by bootstrap_sa_labs to work
%   around the GUI Layout Toolbox (uix) ChildObserver bug: when an axes lives
%   inside a uix layout, MATLAB lazily creates a web hover-toolbar, and the
%   ChildObserver sweeps the toolbar's ToolbarPushButton/ToolbarDropdown
%   children into the box and calls set(child,'Units','pixels') -> errors with
%   "Unrecognized property 'Units' for class ...ToolbarPushButton".
%
%   Simply emptying ax.Toolbar is NOT sufficient: the toolbar controller
%   rebuilds the default toolbar on the next mouse-move (getDefaultToolbar in
%   handleMouseMotion), so the buttons reappear and the error floods the
%   console. Stripping the default interactions removes the controller path
%   that attaches the toolbar on hover, so nothing is created to be swept up.
%
%   Trade-off: axes created this session have no hover zoom/pan/datatip
%   buttons and no scroll/drag interactions. Programmatic plotting is
%   unaffected. Everything is wrapped in try/catch so a quirky axes can never
%   break figure construction.

    try
        ax.Toolbar = [];
    catch
    end

    try
        disableDefaultInteractivity(ax);
    catch
    end
end