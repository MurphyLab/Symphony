function s = windowScreen(fh)
    % Returns the index of the screen on which most of the figure window lies.
    
    s = [];
    %dpi = get(0, 'ScreenPixelsPerInch');
    
%     prevScreenUnits = get(0, 'Units');
%     set(0, 'Units', 'pixels');
%     mps = get(0, 'MonitorPositions');
%     set(0, 'Units', prevScreenUnits);
    mps = zeros(System.Windows.Forms.Screen.AllScreens.Length, 4);
    for i = 1:System.Windows.Forms.Screen.AllScreens.Length
        screen = System.Windows.Forms.Screen.AllScreens(i).Bounds;
        mps(i, 1) = screen.X + 1;
        mps(i, 2) = screen.Y + 1;
        mps(i, 3) = screen.Width;
        mps(i, 4) = screen.Height;
    end
    
    prevFigureUnits = get(fh, 'Units');
    set(fh, 'Units', 'pixels');
    figPos = get(fh, 'Position');
    set(fh, 'Units', prevFigureUnits);
    
    figPos(2) = mps(1, 4) - (figPos(2) + figPos(4));
    
    maxCov = 0;
    for i = 1:size(mps, 1)
        if figPos(1) < mps(i, 1) + mps(i, 3) && ...
           figPos(1) + figPos(3) > mps(i, 1) && ...
           figPos(2) < mps(i, 2) + mps(i, 4) && ...
           figPos(2) + figPos(4) > mps(i, 2)
            cov = (min(figPos(1) + figPos(3), mps(i, 1) + mps(i, 3)) - max(figPos(1), mps(i, 1))) * ...
                  (min(figPos(2) + figPos(4), mps(i, 2) + mps(i, 4)) - max(figPos(2), mps(i, 2)));
            if cov > maxCov
                s = i;
                maxCov = cov;
            end
        end
    end
end
