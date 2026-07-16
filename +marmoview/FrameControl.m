% core task controller
% 8-30-2018 - Jude Mitchell
% TODO: This is setting background but does not know about the other places
% where background might be defined (settings file and protocol file)

classdef FrameControl < handle
    %
    % To see the public properties of this class, type
    %
    %  properties(marmoview.TaskControl)
    %
    % To see a list of methods, type
    %
    %   methods(marmoview.TaskControl)
    %
    % The class constructor can be called with a range of arguments:
    %
    %  This is the workhorse class of any experiment:
    %       1) It store the parameter structs for each trial
    %       2) It controls the screen flips and Show Eye feature
    %       3) It regulates any access back to GUI during run function
    %       4) It send out timing signals for eye tracker and ephys
    %       5) It stores the eye position and screen flip times
    %       6) It plots the eye position traces per trial and screen flip dT
    %       7) It writes out to a data file all of its information
    %                accumulated over a block of trials

    % METHODS
    %

    properties (SetAccess = private)
        %******** psychtoolbox
        winPtr;     % pointer to Screen window

        %******** storage across a session
        PInit;      % initialized Param struct, never allow new fields

        %******* what states are time sensitive
        TimeSensitive;

        %******** storage within a single trial
        FData       % buffer to store within trial data
        FCount      % counter to store flips during trial
        c = [0,0];  % struct that holds eye calibration data, center
        dx = 1;     % eye calib x scale
        dy = 1;     % eye calib y scale
        rot = 0;    % eye rotation
        FMAX;       % Max screen flips in any trial
        FIELDS;     % Max number of fields to store in eye data
        eyeColor;   % for ShowEye of eye position tracker
        FP;         % know how to plot eye traces (supplied from Run)
    end

    % These are all defined elsewhere and the defaults here worry me
    properties
        showEye = 0;
        eyeIntensity = 0.08;
        Bkgd = 0.5;       % FIXME need to know for screen flip
        eyeRadius = 2.0;
        centerPix = [0,0];
        pixPerDeg = 30;
        frameRate = 60;
    end

    properties (SetAccess = private)
        use8Bit
    end

    properties (Hidden)
        FrameTimingFigure
        TpxFigure
    end

    methods
        function obj = FrameControl()
            cprintf('_Comments', 'FrameControl,constructor\n');
            % Defaults, call to initialize() will set up properly
            obj.winPtr = [];
            obj.PInit = struct();
            obj.TimeSensitive = [];

            % Per trial data storage
            obj.FMAX = 3000;  % max screen flips
            obj.FIELDS = 6;
            obj.FData = nan(obj.FMAX, obj.FIELDS);
            obj.FCount = 0;
            obj.c  = [0,0];
            obj.dx = 1;
            obj.dy = 1;
            obj.rot = 0;

            obj.FP = [];
        end
    end

    methods (Access = public)
        function obj = initialize(obj, winPtr, P, C, S, varargin)
            cprintf('_Comments', '\tFrameControl, call initialize\n');

            % winPtr is the window point of psych display
            % P is the parameter struct defined by settings
            % C is the eye calibration struct
            % varargin are other important parameters

            %*** initialize data storage and counters
            obj.winPtr = winPtr;  % screen pointer
            %*********
            obj.PInit = P;
            %*************
            obj.FData(:) = NaN;
            obj.FCount = 0;
            %***********
            obj.c = C.c;
            obj.dx = C.dx;
            obj.dy = C.dy;
            obj.rot = C.rot;
            %**************
            obj.frameRate = S.frameRate;
            obj.centerPix = S.centerPix;
            obj.pixPerDeg = S.pixPerDeg;
            obj.use8Bit = S.use8Bit;
            %*************

            % initialise input parser
            p = inputParser;
            p.KeepUnmatched = true;
            p.StructExpand = true;

            p.addParameter('showEye', 0, @isfloat);
            p.addParameter('eyeIntensity', [], @isfloat); % default
            p.addParameter('Bkgd', P.bkgd, @isfloat);
            p.addParameter('eyeRadius', 2.0, @isfloat);

            p.parse(varargin{:});

            obj.showEye = p.Results.showEye;
            obj.eyeIntensity = p.Results.eyeIntensity;
            obj.Bkgd = p.Results.Bkgd;
            obj.eyeRadius = p.Results.eyeRadius;

            if isempty(obj.eyeIntensity)
                if obj.use8Bit
                    obj.eyeIntensity = 20;
                else
                    obj.eyeIntensity = 0.1;
                end
            end

            % Override with parameters from pInit
            obj.update_args_from_Pstruct(obj.PInit);

            % Color for gaze indicator color, % purple, replace later
            obj.eyeColor = uint8(repmat(obj.Bkgd,[1 3])) + ...
                           uint8(obj.eyeIntensity * [1,-1,1]);
            if ~obj.use8Bit
                obj.eyeColor = double(obj.eyeColor) / 255;
            end

            if S.eyetrackerType == "Trackpixx"
                obj.TpxFigure = TrackPixxFigure();
            end
            %if S.showFrameFlipFigure
            %    obj.FrameTimingFigure = FrameFlipFigure();
            %end
        end

        function update_args_from_Pstruct(obj, P)
            % NOTE, these arguments could load from the Pinit as well
            %cprintf('_Comments', '\tFrameControl, call updateArgsFromPStruct =');

            if (isfield(P,'bkgd'))
                obj.Bkgd = P.bkgd;
            end

            if (isfield(P, 'showEye'))
                obj.showEye = P.showEye;
            end
            if (isfield(P,'eyeIntensity'))
                obj.eyeIntensity = P.eyeIntensity;
                obj.eyeColor = repmat(obj.Bkgd,[1 3]) + ...
                    obj.eyeIntensity * [1,-1,1];
                if obj.use8Bit
                    obj.eyeColor = uint8(obj.eyeColor);
                end
            end
            if (isfield(P,'eyeRadius'))
                obj.eyeRadius = P.eyeRadius;
            end
        end

        function set_task(obj, FP, TS)
            % call to set private property of class
            obj.FP = FP;
            obj.TimeSensitive = TS;
        end

        function eyeData = upload_eyeData(obj)
            %cprintf('_Comments', '\tFrameControl, call uploadEyeData\n');
            if obj.FCount
                eyeData = obj.FData(1:obj.FCount,:);
            else
                eyeData = [];
            end
        end

        function [c,dx,dy,rot] = upload_C(obj)
            %cprintf('_Comments', '\tFrameControl, call uploadC\n');
            c = obj.c;
            dx = obj.dx;
            dy = obj.dy;
            rot = obj.rot;
        end

        %********* main routines below for the work during trials
        function CL = prep_run_trial(obj, eyepos, pupil)
            % PREPRUNTRIAL Runs every screen flip

            %cprintf('_Comments', '\tFrameControl, call prepRunTrial\n');
            obj.FData(:,:) = NaN;  % set all to NaN at start
            obj.FData(1:5,1) = GetSecs;  % column 1 timelock on eye pos
            obj.FCount = 5;   % flip counter, why at 5 though?


            % Setup first frame
            Screen('FillRect', obj.winPtr, obj.Bkgd);
            % when flipping, store time in eyeData
            FStart = Screen('Flip', obj.winPtr, GetSecs);

            % Get initial into
            obj.FData(1:5,2) = eyepos(1);
            obj.FData(1:5,3) = eyepos(2);
            obj.FData(1:5,4) = pupil;
            obj.FData(1:5,5) = 0;    %default, start state = 0
            obj.FData(1:5,6) = FStart;

            % Store the Clock Sixlet
            CL = fix(clock);
            CL(1) = CL(1) - 2000;
        end

        function [currentTime,x,y] = grabeye_run_trial(obj,state,eyepos,pupil)
            %cprintf('_Comments', '\tFrameControl, call grabEyeRunTrial\n');
            currentTime = GetSecs();

            if isempty(obj.FCount)
                obj.FCount = 0;
            end
            obj.FCount = obj.FCount + 1;
            k = obj.FCount;
            if (k <= obj.FMAX)  %drops data if over max
                obj.FData(k,1) = currentTime;
                obj.FData(k,2) = eyepos(1);
                obj.FData(k,3) = eyepos(2);
                obj.FData(k,4) = pupil;
                obj.FData(k,5) = state;
            else
                disp('Over MAX eye data within trial, expand buffer');
            end
            x = (eyepos(1) - obj.c(1)) / (obj.dx * obj.pixPerDeg);
            y = (eyepos(2) - obj.c(2)) / (obj.dy * obj.pixPerDeg);
            [x, y] = obj.rotatecore(x, y, obj.rot);

            %disp([eyepos, x, y, pupil]);
        end


        function [updateGUI, screenTime] = screen_update_run_trial(obj, state)
            % OTHER DRAWS
            eyeI = obj.FCount;
            if obj.showEye
                % Convert eye position from last 5 samples to pixel space
                x = mean(obj.FData(eyeI-4:eyeI,2)-obj.c(1)) / obj.dx;
                y = mean(obj.FData(eyeI-4:eyeI,3)-obj.c(2)) / obj.dy;
                [x, y] = obj.rotatecore(x, y, obj.rot);
                cX = obj.centerPix(1)+round(x);
                cY = obj.centerPix(2)-round(y);   % INVERT FOR SCREEN DRAWS!
                eR = round(obj.eyeRadius*obj.pixPerDeg);
                Screen('FrameOval', obj.winPtr, obj.eyeColor,...
                    [cX-eR, cY-eR, cX+eR, cY+eR], 2);
            end

            % FLIP SCREEN NOW
            screenTime = Screen('Flip', obj.winPtr, GetSecs());
            obj.FData(eyeI,6) = screenTime;
            % Reset the screen
            Screen('FillRect', obj.winPtr, obj.Bkgd);

            % If not time sensitive state, allow GUI updating
            if (~ismember(state, obj.TimeSensitive))
                updateGUI = true;
            else
                updateGUI = false;
            end
        end

        function update_eye_calib(obj, c, dx, dy, rot)
            %cprintf('_Comments', '\tFrameControl, call updateEyeCalib\n');

            obj.c = c;
            obj.dx = dx;
            obj.dy = dy;
            obj.rot = rot;
        end

        function CL = last_screen_flip(obj)
            % Reset the screen and leave blank for ITI
            cprintf('_Comments', '\tFrameControl, call lastScreenFlip\n');

            obj.FCount = obj.FCount + 1;
            eyeI = obj.FCount;
            Screen('FillRect', obj.winPtr, obj.Bkgd);
            FEnd = Screen('Flip', obj.winPtr, GetSecs());
            obj.FData(eyeI, 6) = FEnd;

            % Store the Clock Sixlet
            CL = fix(clock);
            CL(1) = CL(1) - 2000;
        end

        function updateTpxPlot(obj, tpxData)
            if ~isempty(obj.TpxFigure)
                obj.TpxFigure.updateUi(tpxData);
            end
        end

        function plot_eye_trace_and_flips(obj, handles)
            % function plot_eye_trace_and_flips(handles)
            %
            % This function plots the eye trace from trial in the EyeTracker
            % window of MarmoView.
            %
            % And it also plots the screen frame flips

            ax1 = handles.EyeTrace;
            dx = handles.A.dx; dy = handles.A.dy;
            c = handles.A.c; rot = handles.A.rot;
            ppd = handles.S.pixPerDeg;
            eyeRad = handles.eyeTraceRadius;

            set(ax1, 'NextPlot', 'Add');
            plot(ax1, 0, 0, '+k', 'LineWidth', 2);
            plot(ax1, [-eyeRad eyeRad], [0 0], '--', 'Color', [.5 .5 .5]);
            plot(ax1, [0 0], [-eyeRad eyeRad], '--', 'Color', [.5 .5 .5]);

            % special labeling of states
            if obj.FCount
                if isempty(obj.FP)  % default case, plot all traces
                    ind = 1:obj.FCount;  %any reasonable states
                    x = (obj.FData(ind, 2) - c(1)) / (dx*ppd);
                    y = (obj.FData(ind, 3) - c(2)) / (dy*ppd);
                    [x,y] = obj.rotatecore(x, y, rot);
                    plot(ax1,x,y,'b.');
                else
                    for k = 1:length(obj.FP)
                        ind = ismember(obj.FData(:,5),obj.FP(k).states);
                        x = (obj.FData(ind,2) - c(1)) / (dx * ppd);
                        y = (obj.FData(ind,3) - c(2)) / (dy * ppd);
                        [x, y] = obj.rotatecore(x, y, rot);
                        plot(ax1, x, y, [obj.FP(k).col, '.']);
                    end
                end
            end
            axis(ax1, [-eyeRad, eyeRad, -eyeRad, eyeRad]);

            % Show the screen flip times
            ax2 = handles.DataPlot4;
            dT = (1 / obj.frameRate);
            set(ax2, 'NextPlot', 'Replace');
            if (obj.FCount > 1)
                tN = obj.FCount - 1;  %drop last flip, worst one
                txx = 2:tN;
                flips = obj.FData(txx,1) - obj.FData((txx-1),1);
                mflips = max(flips);
                tic
                plot(ax2, [2, tN], [dT, dT], 'k-');
                set(ax2, 'NextPlot', 'Add');
                tstates = ismember( obj.FData(txx,5), obj.TimeSensitive );
                plot(ax2, txx(~tstates), flips(~tstates), 'k.');
                plot(ax2, txx(tstates), flips(tstates), 'r.');
                axis(ax2, [2 tN 0 (mflips*1.5)]);
                set(ax2, 'NextPlot', 'Replace');
                fprintf('FRAME FLIP PLOT: %.4f\n', toc)

                if ~isempty(obj.FrameTimingFigure)
                    ptbFlips = obj.FData(txx, 6) - obj.FData(txx-1, 6);
                    obj.FrameTimingFigure.update(txx, flips, tstates, ptbFlips);
                end
            end
        end
    end

    methods (Static)
        function [x2,y2] = rotatecore(x, y, rot)
            if (rot)
                anga = rot * pi /180;
                ca = cos( anga);
                sa = sin( anga);
                x2 = ca * x + sa * y;
                y2 = -sa * x + ca * y;
            else
                x2 = x;
                y2 = y;
            end
        end
    end
end

