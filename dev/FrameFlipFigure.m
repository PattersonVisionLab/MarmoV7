classdef FrameFlipFigure < handle

    properties (SetAccess = private)
        Figure
        Axis
        sensitiveTimePointLine
        regularTimePointLine
    end

    methods
        function obj = FrameFlipFigure()
            obj.createUi();
        end

        function update(obj, txx, flips, tStates)
            if nargin < 3 || isempty(tStates)
                tStates = zeros(size(txx));
            end

            txx = txx/1000;  % sec --> ms

            if any(tStates)
                set(obj.sensitiveTimePointLine,... 
                    'XData', txx(tStates), 'YData', flips(tStates));
            else
                set(obj.sensitiveTimePointLine,... 
                    'XData', NaN, 'YData', NaN);
            end

            set(obj.regularTimePointLine,... 
                'XData', txx(~tStates), 'YData', flips(~tStates));
            axis(obj.Axis, 'tight');
            obj.Axis.YLim(1) = 0;
        end
    end

    methods (Access = private)
        function createUi(obj)
            obj.Figure = uifigure("Name", "Frame Timing Figure");
            obj.Figure.Position(1) = obj.Figure.Position(1)*0.75;
            obj.Figure.Position(3) = 800;
            obj.Axis = uiaxes(obj.Figure, "FontSize", 12);
            
            obj.sensitiveTimePointLine = line(obj.Axis,...
                "XData", 0, "YData", 0, "Color", 'r', "Marker", '.',...
                "MarkerSize", 10, "LineStyle", "none");
            obj.regularTimePointLine = line(obj.Axis,...
                "XData", 0, "YData", 0, "Color", [0.1 0.1 0.1],...
                "Marker", ".", "MarkerSize", 10, "LineStyle", "none");
            xlabel(obj.Axis, 'Time (sec)');
            ylabel(obj.Axis, 'Frame Time (ms)');
            % yticks(obj.Axis, [1/120, 1/60]);
        end
    end
end