classdef TrackPixxFigure < handle

    properties (SetAccess = private)
        Figure

        Pupil
        EyeXT
        EyeXY

        leftEyeXY
        rightEyeXY
        leftEyeXT
        rightEyeXT
        leftPupil
        rightPupil
    end

    properties (Hidden, Constant)
        LEFT_COLOR = [1 0.25 0.25]
        RIGHT_COLOR = [0.2 0.3 1];
    end

    methods
        function obj = TrackPixxFigure()
            obj.createUi();
        end

        function updateUi(obj, tpxData)
            tpxData = tpxData(6:end,:);
            xpts = tpxData.TimeTag - tpxData.TimeTag(1);

            set(obj.leftPupil, 'XData', xpts,...
                'YData', tpxData.LeftPupilDiameter);
            set(obj.rightPupil, 'XData', xpts,...
                'YData', tpxData.RightPupilDiameter);

            set(obj.leftEyeXY, 'XData', tpxData.LeftEyeRawX,...
                "YData", tpxData.LeftEyeRawY);
            set(obj.rightEyeXY, 'XData', tpxData.RightEyeRawX,...
                "YData", tpxData.RightEyeRawY);

            set(obj.leftEyeXT, "XData", xpts,...
                "YData", tpxData.LeftEyeRawX);
            set(obj.rightEyeXT, "XData", xpts,...
                "YData", tpxData.RightEyeRawY);
        end
    end

    methods (Access = private)
        function createUi(obj)
            obj.Figure = uifigure("Name", "Trackpixx Figure");
            g = uigridlayout(obj.Figure, [3, 1],...
                "RowHeight", {'1x', '1x', '1.5x'});

            obj.Pupil = uiaxes(g);
            obj.EyeXT = uiaxes(g);
            obj.EyeXY = uiaxes(g);

            ylabel(obj.Pupil, 'Pupil Diameter (mm)');
            ylabel(obj.EyeXT, 'Horizontal Position');
            xlabel(obj.EyeXT, "Time (sec)");
            axis(obj.EyeXY, 'equal');
            grid(obj.EyeXY, 'on');

            obj.leftPupil = line(obj.Pupil, NaN, NaN,...
                'Color', obj.LEFT_COLOR, 'LineWidth', 1.25);
            obj.rightPupil = line(obj.Pupil, NaN, NaN,...
                "Color", obj.RIGHT_COLOR, "LineWidth", 1.25);
            obj.leftEyeXT = line(obj.EyeXT, NaN, NaN,...
                "Color", obj.LEFT_COLOR);
            obj.rightEyeXT = line(obj.EyeXT, NaN, NaN,...
                "Color", obj.RIGHT_COLOR);
            obj.leftEyeXY = line(obj.EyeXY, NaN, NaN,...
                "Color", obj.LEFT_COLOR);
            obj.rightEyeXY = line(obj.EyeXY, NaN, NaN,...
                "Color", obj.RIGHT_COLOR);
        end
    end
end
