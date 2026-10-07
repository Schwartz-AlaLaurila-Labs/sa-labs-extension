function layout(h)
%SA_LABS.UTIL.UI.INTERNAL.LAYOUT  Position the children of a layout panel.
%   Reads the spec stored by attach(). Sizes follow the uix convention: a
%   negative value is a weight for the remaining space, a positive value is a
%   fixed number of pixels. Missing entries default to -1.

    if isnumeric(h) && all(isgraphics(h))
        h = handle(h);          % numeric graphics handle (e.g. stored in a double array)
    end
    if ~isgraphics(h) || ~isappdata(h, 'sa_labs_layout')
        return;
    end
    spec = getappdata(h, 'sa_labs_layout');

    kids = h.Children;
    if isempty(kids)
        return;
    end
    kids = flipud(kids(:));          % Children is newest-first; lay out in creation order
    n = numel(kids);

    % Pixel size of the panel's drawable area
    oldUnits = h.Units;
    h.Units = 'pixels';
    pos = h.Position;
    h.Units = oldUnits;
    W = max(pos(3), 1);
    H = max(pos(4), 1);
    pad = spec.padding;
    sp = spec.spacing;

    switch spec.kind
        case 'box'
            sizes = spec.sizes;
            if numel(sizes) < n
                sizes(end+1:n) = -1;
            end
            sizes = sizes(1:n);
            vertical = strcmp(spec.orientation, 'vertical');
            if vertical
                total = H - 2*pad - sp*(n-1);
            else
                total = W - 2*pad - sp*(n-1);
            end
            fixed = sum(sizes(sizes > 0));
            weights = -sizes(sizes < 0);
            flexible = max(total - fixed, 0);
            px = zeros(1, n);
            px(sizes > 0) = sizes(sizes > 0);
            if any(sizes < 0)
                px(sizes < 0) = flexible .* weights ./ sum(weights);
            end
            px = max(px, 1);

            if vertical
                y = H - pad;
                for i = 1:n
                    y = y - px(i);
                    place(kids(i), [pad, y, max(W - 2*pad, 1), px(i)]);
                    y = y - sp;
                end
            else
                x = pad;
                for i = 1:n
                    place(kids(i), [x, pad, px(i), max(H - 2*pad, 1)]);
                    x = x + px(i) + sp;
                end
            end

        case 'buttonbox'
            bw = spec.buttonSize(1);
            bh = spec.buttonSize(2);
            if strcmp(spec.orientation, 'horizontal')
                rowW = n*bw + (n-1)*sp;
                switch spec.horizontalAlignment
                    case 'left',  x0 = pad;
                    case 'right', x0 = W - pad - rowW;
                    otherwise,    x0 = (W - rowW)/2;
                end
                switch spec.verticalAlignment
                    case 'top',    y0 = H - pad - bh;
                    case 'bottom', y0 = pad;
                    otherwise,     y0 = (H - bh)/2;
                end
                for i = 1:n
                    place(kids(i), [x0 + (i-1)*(bw+sp), y0, bw, bh]);
                end
            else
                colH = n*bh + (n-1)*sp;
                switch spec.verticalAlignment
                    case 'bottom', yTop = pad + colH;
                    case 'middle', yTop = (H + colH)/2;
                    otherwise,     yTop = H - pad;      % 'top'
                end
                switch spec.horizontalAlignment
                    case 'left',  x0 = pad;
                    case 'right', x0 = W - pad - bw;
                    otherwise,    x0 = (W - bw)/2;
                end
                for i = 1:n
                    place(kids(i), [x0, yTop - i*bh - (i-1)*sp, bw, bh]);
                end
            end

        case 'fill'
            % Single child fills the panel (uix.Panel replacement)
            for i = 1:n
                place(kids(i), [pad, pad, max(W - 2*pad, 1), max(H - 2*pad, 1)]);
            end
    end
end

function place(k, p)
    try
        if isa(k, 'matlab.graphics.axis.Axes') || isa(k, 'matlab.graphics.axis.PolarAxes')
            k.Units = 'pixels';
            k.OuterPosition = p;
        elseif isprop(k, 'Units') && isprop(k, 'Position')
            k.Units = 'pixels';
            k.Position = p;
        elseif isprop(k, 'Position')
            k.Position = p;        % uifigure components (uibutton etc.) are always pixels
        end
    catch
        % A child that cannot be positioned (legend, toolbar, ...) is skipped
    end
end
