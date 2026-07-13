classdef PR_Speed_Motion_OKN < handle
    % Matlab class for running an experimental protocl
    %
    % The class constructor can be called with a range of arguments:
    %

    properties (Access = public)
        Iti          double = 1;         % default Iti duration
        startTime    double = 0;         % trial start time
        itiStart     double = 0;         % start of iti interval
        rewardGap    double = 0;         % gap for next target onset
        rewardTime   double = 0;         % store time of last reward
    end

    properties (SetAccess = private)
        winPtr; % ptb window
        state           double = 0;      % state counter
        error           double = 0;      % error state in trial
        %*********
        hGrating = [];     % marmoview.stimuli.grating
        %*********
        S;              % copy of Settings struct (loaded per trial start)
        P;              % copy of Params struct (loaded per trial)
        trialsList;        % store copy of trial list (not good to keep in S struct)
        %********* stimulus structs for use
        noiseStim = 0;     % which noise stim (if long term duration)
        ori = 0;           % tested orientations
        spatialFreq = 0.2;
        temporalFrequency = 1;      %
        speedStep = 1;         % speed change phase step
        %******* parameters for Noise History grating stimulus
        NoiseHistory = []; % list of noise frames over trial and their times
        FrameCount = 0;    % count noise frames
        MaxFrame = (120*20); % twenty second maximum
        TrialDur = 0;      % store internally the trial duration (make less than 20)
        StimPhase = 1;
        %**********************************
        D = struct;        % store PR data (see end_plots)
    end

    methods (Access = public)
        function obj = PR_Speed_Motion_OKN(winPtr)
            obj.winPtr = winPtr;
            obj.trialsList = [];  % should be set by generate call
        end

        function state = get_state(obj)
            state = obj.state;
        end

        function initFunc(obj, S, P)

            %********** Set-up for trial indexing (required)
            cors = [0,4];  % count these errors as correct trials
            reps = [1,2];  % count these errors like aborts, repeat
            obj.trialsList = [];  % empty for this protocol
            %**********

            % Create stimulus bank
            obj.NoiseHistory = zeros(obj.MaxFrame, 2);
            obj.spatialFreq = P.spf;
            obj.temporalFrequency = S.frameRate / P.gratingcycle;
            obj.ori = P.ori;
            %******
            obj.hGrating = cell(1, P.gratingcycle);
            obj.StimPhase = 1;
            %*********
            fprintf('Creating stimuli... ');
            for i = 1:P.gratingcycle
                fprintf('%u  ', i);
                %******** replace dot field with full-field grating
                obj.hGrating{1,i} = stimuli.grating(obj.winPtr); 
                obj.hGrating{1,i}.position = S.centerPix;
                if isinf(P.noiseradius)
                    obj.hGrating{1,i}.radius = Inf; %fill entire screen
                    obj.hGrating{1,i}.screenRect = S.screenRect;
                else
                    obj.hGrating{1,i}.radius = round(P.noiseradius * S.pixPerDeg);
                end
                %*********
                obj.hGrating{1,i}.orientation = obj.ori - 90;  % 0 is right
                obj.hGrating{1,i}.phase = (360*((i-1) / P.gratingcycle));
                obj.hGrating{1,i}.cpd = obj.spatialFreq;
                %*******
                obj.hGrating{1,i}.range = P.noiserange;
                obj.hGrating{1,i}.square = logical(P.squareWave);
                obj.hGrating{1,i}.dutyCycle = P.dutyCycle;
                obj.hGrating{1,i}.squareAperture = false;
                obj.hGrating{1,i}.gauss = true;
                obj.hGrating{1,i}.bkgd = P.bkgd;
                obj.hGrating{1,i}.transparent = 0.5;
                obj.hGrating{1,i}.pixperdeg = S.pixPerDeg;
                obj.hGrating{1,i}.updateTextures();
            end
            fprintf('Done\n');
            %****************
        end

        function closeFunc(obj)
            if iscell(obj.hGrating)
                for i = 1:obj.P.gratingcycle
                    if ~isempty(obj.hGrating{1,i})
                        obj.hGrating{1,i}.CloseUp();
                    end
                end
            end
        end

        function generate_trialsList(obj, S, P)
            % Call a function outside class (easier for us to edit)
            obj.trialsList = [];  %all random for this one
        end

        function P = next_trial(obj, S, P)
            %********************
            obj.S = S;
            obj.P = P;
            obj.error = 0;
            obj.FrameCount = 0;
            %********
            if (P.trialdur < 20)
                obj.TrialDur = P.trialdur;
            else
                obj.TrialDur = 20;
            end

            %*************
            if (obj.noiseStim == 1)
                obj.noiseStim = 2;
            else
                obj.noiseStim = 1;
            end
            % o.noiseStim = randi(2);  %1 forward, 2 backward
            obj.speedStep = 2^(randi(P.speednum) - 1);
            %***********
            obj.rewardTime = GetSecs();
            obj.rewardGap = P.rewardGapTime;
            %******** new resettings
            obj.NoiseHistory(:,:) = 0;
        end

        function [FP,TS] = prep_run_trial(obj)
            % Flags that control transitions
            % State is the main variable to control transitions. A protocol can be
            % described by shifting through states. For this protocol:
            % State 0 -- Foraging for targets
            % State 1 -- Fixation entered on target
            % State 2 -- Rewards for target, face shown
            % State 3 -- Foraging finished
            obj.state = 0;
            % Errors describe why a trial was not completed
            % No possible errors for this type of experiment
            obj.error = 0;
            %******* Plot States Struct (show fix in blue for eye trace)
            % any special plotting of states,
            % FP(1).states = 1:2; FP(1).col = 'b';
            % would show states 1,2 in blue for eye trace
            FP(1).states = 1;  %before fixation
            FP(1).col = 'b-';
            FP(2).states = 2;  % fixation held
            FP(2).col = 'r';
            FP(3).states = 3;  % reward on target
            FP(3).col = 'g';
            %***********
            TS = 1:3;  % most states are time sensitive due to revcor
            %****************
            obj.startTime = GetSecs();
            obj.Iti = obj.P.iti;  % default ITI, could be longer if error
        end

        function updateNoise(obj, xx, yy, currentTime)
            if (obj.FrameCount < obj.MaxFrame)
                %***************
                obj.hGrating{1, floor(obj.StimPhase)}.beforeFrame();
                if (obj.noiseStim == 1)  % forward phase steps
                    obj.StimPhase = obj.StimPhase + obj.speedStep;
                    if (obj.StimPhase > obj.P.gratingcycle)
                        obj.StimPhase = obj.StimPhase - obj.P.gratingcycle;
                    end
                else
                    obj.StimPhase = obj.StimPhase - obj.speedStep;
                    if (obj.StimPhase < 1)
                        obj.StimPhase = obj.StimPhase + obj.P.gratingcycle;
                    end
                end
                %**********
                obj.FrameCount = obj.FrameCount + 1;
                % NOTE: store screen time in "continue_run_trial" after flip
                obj.NoiseHistory(obj.FrameCount,2) = obj.noiseStim;
                %**********
            end
        end

        function keepgoing = continue_run_trial(obj, screenTime)
            keepgoing = 0;
            if (obj.state < 4)
                keepgoing = 1;
            end
            % this is also called post-screen flip, and thus can be used to
            % time-stamp any previous graphics calls for object on the
            % screen and things like that
            if (obj.FrameCount)
                % store screen flip
                obj.NoiseHistory(obj.FrameCount,1) = screenTime;  
            end
            %******************************************************
        end

        %******************** THIS IS THE BIG FUNCTION *************
        function drop = state_and_screen_update(obj, currentTime, x, y)
            drop = 0;
            %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
            if (obj.state == 0)
                obj.state = 1;  % jump in and plot eye traces
            end
            if currentTime > obj.startTime + obj.TrialDur
                obj.state = 4;  % time to end trial
                obj.itiStart = GetSecs();
            end
            %***********************

            % Always update the background
            obj.updateNoise(NaN, NaN, currentTime);

            %******* Deliver random rewards through trial
            if (obj.rewardTime > 0)
                if ( (currentTime - obj.rewardTime) > obj.rewardGap)
                    obj.rewardTime = currentTime;
                    drop = 1;
                end
            end
            %****************************************
        end

        function Iti = end_run_trial(obj)
            % returns generic Iti interval
            Iti = obj.Iti - (GetSecs() - obj.itiStart); 
        end

        function plot_trace(obj, handles)
            %****** plot eccentric ring where stimuli appear
            h = handles.EyeTrace;
            set(h, 'NextPlot', 'Replace');
            eyeRad = handles.eyeTraceRadius;
            % Target ring
            r = obj.P.noiseheight;
            plot(h,r*cos(0:.01:1*2*pi), r*sin(0:.01:1*2*pi), '-k');
            set(h, 'NextPlot', 'Add');
            %********
            % h = handles.EyeTrace;
            % set(h,'NextPlot','Replace');
            %****** plot eccentric ring where stimuli appear
            % h = handles.EyeTrace;
            % set(h,'NextPlot','Replace');
            % eyeRad = handles.eyeTraceRadius;
            %*****************
            % axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
        end

        function PR = end_plots(obj, P, A)
            

            % NOTE, no need to copy anything from P itself, that is saved
            % already on each trial in data .... copy parts that are not
            % reflected in P at all and generated random per trial
            % Some params are constant over trials, but still nice to store
            PR = struct();
            PR.error = obj.error;
            if obj.FrameCount == 0
                PR.NoiseHistory = [];
            else
                PR.NoiseHistory = obj.NoiseHistory(1:obj.FrameCount,:);
            end
            PR.ori = obj.ori; 
            PR.spatfreq = obj.spatialFreq;
            PR.tempfreq = obj.temporalFrequency;
            PR.noiseStim = obj.noiseStim; %differs based on noise type
            PR.speedStep = obj.speedStep;

            %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % It is advised not to store things too large here, like eye
            % movements, that would be very inefficient
            obj.D.error(A.j) = obj.error;   % TODO

            %%%% Plot results %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Nothing for now ...

        end
    end
end
