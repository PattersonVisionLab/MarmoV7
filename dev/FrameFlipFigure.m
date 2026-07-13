classdef FrameFlipFigure < handle

    properties (SetAccess = private)
        Figure
        Axis
        sensitiveTimePointLine
        regularTimePointLine
        ptbFlipLine
    end

    methods
        function obj = FrameFlipFigure()
            obj.createUi();
        end

        function delete(obj)
            try
                close(obj.Figure);
            catch ME
                warning(ME.identifier, '%s', ME.message);
            end
        end

        function update(obj, txx, flips, tStates, ptbFlips)
            if nargin < 3 || isempty(tStates)
                tStates = zeros(size(txx));
            end

            txx = txx/10;               % ms --> sec
            flips = flips * 1000;       % sec --> ms
            ptbFlips = ptbFlips * 1000; % sec --> ms

            if any(tStates)
                set(obj.sensitiveTimePointLine,... 
                    'XData', txx(tStates), 'YData', flips(tStates));
            else
                set(obj.sensitiveTimePointLine,... 
                    'XData', NaN, 'YData', NaN);
            end

            set(obj.regularTimePointLine,... 
                'XData', txx(~tStates), 'YData', flips(~tStates));
            set(obj.ptbFlipLine, 'XData', txx, 'YData', ptbFlips);
            axis(obj.Axis, 'tight');
            obj.Axis.YLim(1) = 0;
        end
    end

    methods (Access = private)
        function createUi(obj)
            obj.Figure = uifigure("Name", "Frame Timing Figure");
            obj.Figure.Position(1) = obj.Figure.Position(1)*0.75;
            obj.Figure.Position(3) = 800;
            obj.Axis = uiaxes(obj.Figure,... 
                "Position", [10 10 (obj.Figure.Position(3:4)-10)],...
                "FontSize", 12);
            
            obj.sensitiveTimePointLine = line(obj.Axis,...
                "XData", 0, "YData", 0, "Color", 'r', "Marker", '.',...
                "MarkerSize", 15, "LineStyle", "none");
            obj.regularTimePointLine = line(obj.Axis,...
                "XData", 0, "YData", 0, "Color", [0.1 0.1 0.1],...
                "Marker", ".", "MarkerSize", 15, "LineStyle", "none");
            obj.ptbFlipLine = line(obj.Axis,...
                "XData", 0, "YData", 0, "Color", [0.1 0.1 0.8],...
                "Marker", ".", "MarkerSize", 5, "LineStyle", "none");
            xlabel(obj.Axis, 'Time (sec)');
            ylabel(obj.Axis, 'Frame Time (ms)');
        end
    end
end
