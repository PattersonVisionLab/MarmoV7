classdef PR_BinaryNoiseOKN < handle
    % Matlab class for running the standalone binary noise OKN protocol.
    % Mirrors PR_Speed_Motion_OKN.m, but runs one binary-noise stimulus that drifts continuously 
    % based on elapsed time, instead of the grating protocol's approach of pre-building many 
    % phase-shifted textures and stepping through them frame by frame.

    properties (Access = public)
        Iti          double = 1;
        startTime    double = 0;
        itiStart     double = 0;
        rewardGap    double = 0;
        rewardTime   double = 0;
    end

    properties (SetAccess = private)
        winPtr;
        state           double = 0;
        error           double = 0;
        %*********
        hNoise = [];     % stimuli.BinaryNoise
        %*********
        S;
        P;
        trialsList;
        %*********
        noiseStim = 0;        % 1/2 toggled per trial -> direction
        speedDegPerSec = 0;
        currentSeed = 0;      % this trial's RNG seed, for reproducibility/logging
        %*******
        NoiseHistory = [];
        FrameCount = 0;
        MaxFrame = (120*20);
        TrialDur = 0;
        %**********************************
        D = struct;
    end

    methods (Access = public)
        function obj = PR_BinaryNoiseOKN(winPtr)
            obj.winPtr = winPtr;
            obj.trialsList = [];
        end

        function state = get_state(obj)
            state = obj.state;
        end

        function initFunc(obj, S, P)
            obj.trialsList = [];
            obj.NoiseHistory = zeros(obj.MaxFrame, 2);

            fprintf('Creating binary noise stimulus... ');
            obj.hNoise = stimuli.BinaryNoise(obj.winPtr);
            obj.hNoise.squareSizeDeg = P.noiseSquareDeg;
            obj.hNoise.pixperdeg = S.pixPerDeg;
            obj.hNoise.bkgd = P.bkgd;
            obj.hNoise.contrastLevel = P.contrastLevel;
            if isinf(P.noiseradius)
                obj.hNoise.radius = Inf;
                obj.hNoise.screenRect = S.screenRect;
            else
                obj.hNoise.radius = round(P.noiseradius * S.pixPerDeg);
                obj.hNoise.position = S.centerPix;
            end
            fprintf('Done\n');
        end

        function closeFunc(obj)
            if ~isempty(obj.hNoise)
                obj.hNoise.CloseUp();
            end
        end

        function generate_trialsList(obj, S, P)
            obj.trialsList = [];
        end

        function P = next_trial(obj, S, P)
            obj.S = S;
            obj.P = P;
            obj.error = 0;
            obj.FrameCount = 0;

            if (P.trialdur < 20)
                obj.TrialDur = P.trialdur;
            else
                obj.TrialDur = 20;
            end

            if (obj.noiseStim == 1)
                obj.noiseStim = 2;
            else
                obj.noiseStim = 1;
            end

            % Randomly pick one of exactly three speed conditions each trial
            r = rand();
            if r < 1/3
                obj.speedDegPerSec = P.speedVeryLow;
            elseif r < 2/3
                obj.speedDegPerSec = P.speedLow;
            else
                obj.speedDegPerSec = P.speedHigh;
            end

            % NoiseStim==1 -> direction=+1
            % -> rightward motion; verified on 07/14/26
 
            if obj.noiseStim == 1
                obj.hNoise.direction = 1;
            else
                obj.hNoise.direction = -1;
            end
            obj.hNoise.speedDegPerSec = obj.speedDegPerSec;

            obj.currentSeed = randi(2^31 - 1); % fresh integer seed for this trial
            obj.hNoise.randSeed = obj.currentSeed;

            obj.hNoise.beforeTrial();  % fresh random texture + drift clock reset (reproducible from obj.currentSeed)

            obj.rewardTime = GetSecs();
            obj.rewardGap = P.rewardGapTime;
            obj.NoiseHistory(:,:) = 0;
        end

        function [FP,TS] = prep_run_trial(obj)
            obj.state = 0;
            obj.error = 0;
            FP(1).states = 1;
            FP(1).col = 'b-';
            FP(2).states = 2;
            FP(2).col = 'r';
            FP(3).states = 3;
            FP(3).col = 'g';
            TS = 1:3;
            obj.startTime = GetSecs();
            obj.Iti = obj.P.iti;
        end

        function updateNoise(obj, xx, yy, currentTime)
            if (obj.FrameCount < obj.MaxFrame)
                obj.hNoise.beforeFrame(currentTime);
                obj.FrameCount = obj.FrameCount + 1;
                obj.NoiseHistory(obj.FrameCount,2) = obj.noiseStim;
            end
        end

        function keepgoing = continue_run_trial(obj, screenTime)
            keepgoing = 0;
            if (obj.state < 4)
                keepgoing = 1;
            end
            if (obj.FrameCount)
                obj.NoiseHistory(obj.FrameCount,1) = screenTime;
            end
        end

        function drop = state_and_screen_update(obj, currentTime, x, y)
            drop = 0;
            if (obj.state == 0)
                obj.state = 1;
            end
            if currentTime > obj.startTime + obj.TrialDur
                obj.state = 4;
                obj.itiStart = GetSecs();
            end

            obj.updateNoise(NaN, NaN, currentTime);

            if (obj.rewardTime > 0)
                if ( (currentTime - obj.rewardTime) > obj.rewardGap)
                    obj.rewardTime = currentTime;
                    drop = 1;
                end
            end
        end

        function Iti = end_run_trial(obj)
            Iti = obj.Iti - (GetSecs() - obj.itiStart);
        end

        function plot_trace(obj, handles)
            h = handles.EyeTrace;
            set(h, 'NextPlot', 'Replace');
            if isinf(obj.P.noiseradius)
                r = 20;  % nominal ring for full-field display
            else
                r = obj.P.noiseradius;
            end
            plot(h,r*cos(0:.01:1*2*pi), r*sin(0:.01:1*2*pi), '-k');
            set(h, 'NextPlot', 'Add');
        end

        function PR = end_plots(obj, P, A)
            PR = struct();
            PR.error = obj.error;
            if obj.FrameCount == 0
                PR.NoiseHistory = [];
            else
                PR.NoiseHistory = obj.NoiseHistory(1:obj.FrameCount,:);
            end
            PR.noiseStim = obj.noiseStim;
            PR.speedDegPerSec = obj.speedDegPerSec;
            PR.trialSeed = obj.currentSeed;   % seed used to generate this trial's noise pattern

            obj.D.error(A.j) = obj.error;
        end
    end
end