classdef PR_FixFlash < handle
    % Matlab class for running an experimental protocl
    %
    % The class constructor can be called with a range of arguments:
    %
    
    properties
        Iti   = 1;            % default Iti duration
        startTime   = 0;      % trial start time
        fixStart   = 0;       % fix acquired time
        itiStart   = 0;       % start of ITI interval
        fixDur   = 0;         % fixation duration
        faceTrial   = true;  % trial with face to start
        showFix   = true;    % trial start with fixation
        flashCounter   = 0;   % counter to flash fixation
        rewardCount   = 0;    % counter for reward drops
        RunFixBreakSound   = 0;       % variable to initiate fix break sound (only once)
        NeverBreakSoundTwice   = 0;   % other variable for fix break sound
        BlackFixation   = 6;          % frame to see black fixation, before reward
        GABcounter   = 1;             % counter for Gabor flashing stimuli
    end
    
    properties (Access = private)
        winPtr; % ptb window
        state   = 0;      % state counter
        error   = 0;      % error state in trial
        %*********
        S;      % copy of Settings struct (loaded per trial start)
        P;      % copy of Params struct (loaded per trial)
        %********* stimulus structs for use
        Faces;             % object that stores face images for use
        hFix;              % object for a fixation point
        hGabor = [];       % object for Gabor stimuli
        fixbreak_sound;    % audio of fix break sound
        fixbreak_sound_fs; % sampling rate of sound
        %*********
        NoiseHistory = []; % list of noise frames over trial and their times
        FrameCount = 0;    % count noise frames
        MaxFrame = (120*20); % twenty second maximum
        %****************
        D = struct;        % store PR data for end plot stats
    end
    
    methods (Access = public)
        function o = PR_FixFlash(winPtr)
            o.winPtr = winPtr;
        end
        
        function state = get_state(obj)
            state = obj.state;
        end
        
        function initFunc(obj, S, P)
            obj.Faces = stimuli.gaussimages(obj.winPtr,...
                'bkgd', S.bgColour, 'gray', false);   % color images
            obj.Faces.loadimages('./SupportData/MarmosetFaceLibrary.mat');
            obj.Faces.position = [0,0]*S.pixPerDeg + S.centerPix;
            obj.Faces.radius = round(P.faceRadius*S.pixPerDeg);
            
            %******* create fixation point ****************
            obj.hFix = stimuli.fixation(obj.winPtr);   % fixation stimulus
            % set fixation point properties
            sz = P.fixPointRadius*S.pixPerDeg;
            obj.hFix.cSize = sz;
            obj.hFix.sSize = 2*sz;
            obj.hFix.cColour = [0 0 0];
            obj.hFix.sColour = [1 1 1];
            obj.hFix.position = [0,0]*S.pixPerDeg + S.centerPix;
            obj.hFix.updateTextures();
            %**********************************
            
            %******** store history of flashed gratings
            obj.NoiseHistory = zeros(obj.MaxFrame,4);   %time, x, y, ori
            %*** Build a set of 8 oriented gratings
            for k = 1:P.OriNum
                ori = (((k-1)*180) / P.OriNum);
                %********* assign a random start position (not too close to fix)
                ampo = P.gabMinRadius + (P.gabMaxRadius-P.gabMinRadius)*rand;
                ango = rand*2*pi;
                dx = cos(ango)*ampo;
                dy = sin(ango)*ampo;
                cX = S.centerPix(1)+ round( S.pixPerDeg * dx);
                cY = S.centerPix(2)+ round( S.pixPerDeg * dy);   %
                %*****************
                obj.hGabor{k} = stimuli.grating(obj.winPtr);
                obj.hGabor{k}.position = [cX cY];
                obj.hGabor{k}.radius = round(P.gabRadius * S.pixPerDeg);
                obj.hGabor{k}.orientation = ori;
                obj.hGabor{k}.phase = 0;
                obj.hGabor{k}.cpd = P.cpd;
                obj.hGabor{k}.range = floor( (P.GaborContrast/100)*127 );
                obj.hGabor{k}.square = false;
                obj.hGabor{k}.bkgd = P.bkgd;
                obj.hGabor{k}.updateTextures();
                %****** store starting locations, set time as NaN
                obj.FrameCount = obj.FrameCount + 1;
                obj.NoiseHistory(obj.FrameCount,:) = [NaN,dx,dy,k];
                %*********************
            end
            
            %********** load in a fixation error sound ************
            [y,fs] = audioread(['SupportData', filesep, 'gunshot_sound.wav']);
            y = y(1:floor(size(y,1)/3),:);  % shorten it, very long sound
            obj.fixbreak_sound = y;
            obj.fixbreak_sound_fs = fs;
            %*********************
        end
        
        function closeFunc(obj)
            obj.Faces.CloseUp();
            obj.hFix.CloseUp();
            for k = 1:length(obj.hGabor)
                obj.hGabor{k}.CloseUp;
            end
        end
        
        function generate_trialsList(~, ~, ~)
            % nothing for this protocol
        end
        
        function P = next_trial(obj,S,P)
            %********************
            obj.S = S;
            obj.P = P;
            obj.FrameCount = 0;   % for noise history
            %*******************
            
            %%%% Trial control -- Update certain parameters depending on run type %%%%%
            switch obj.P.runType
                case 1  % Staircasing
                    % If correct, small increment in fixation duration
                    if ~obj.error
                        P.fixMin = P.fixMin + S.staircase.up(1);
                        P.fixRan = P.fixRan + S.staircase.up(2);
                        % cannot exceed limit
                        P.fixMin = min([P.fixMin S.staircase.durLims(3)]);
                        P.fixRan = min([P.fixRan S.staircase.durLims(4)]);
                        % If entered fixationand failed to maintain it, large reduction in
                        % fixation duration
                    elseif obj.error == 2
                        P.fixMin = P.fixMin - S.staircase.down(1);
                        P.fixRan = P.fixRan - S.staircase.down(2);
                        % cannot exceed limit
                        P.fixMin = max([P.fixMin S.staircase.durLims(1)]);
                        P.fixRan = max([P.fixRan S.staircase.durLims(2)]);
                    end
            end
            %*************************************
            
            % Set up fixation duration
            obj.fixDur = P.fixMin + ceil(1000*P.fixRan*rand)/1000;
            
            % Reward schedule is automated based on fix duration for staircasing
            if S.runType
                P.rewardNumber = find(obj.fixDur > S.staircase.rewardSchedule,1,'last');
            end
            
            % Select a face from image set to show at center
            obj.Faces.imagenum = randi(length(obj.Faces.tex));  % pick any at random
            if rand < P.faceTrialFraction
                obj.faceTrial = true;
            else
                obj.faceTrial = false;
            end
        end
        
        function [FP,TS] = prep_run_trial(obj)
            cprintf('_Comments', '\tFrameControl, call prepRunTrial\n');
            
            %********VARIABLES USED IN RUNNING TRIAL LOGISTICS
            % showFix is a flag to check whether to show the fixation spot or not while
            % it is flashing in state 0
            obj.showFix = true;
            % flashCounter counts the frames to switch ShowFix off and on
            obj.flashCounter = 0;
            % rewardCount counts the number of juice pulses, 1 delivered per frame
            obj.rewardCount = 0;
            %****** deliver sound on fix breaks
            obj.RunFixBreakSound =0;
            obj.NeverBreakSoundTwice = 0;
            obj.BlackFixation = 6;  % frame to see black fixation, before reward
            obj.GABcounter = 1;
            % Setup the state
            obj.state = 0; % Showing the face
            obj.error = 0; % Start with error as 0
            obj.Iti = obj.P.iti;   % set ITI interval from P struct stored in trial
            %******* Plot States Struct (show fix in blue for eye trace)
            % any special plotting of states,
            % FP(1).states = 1:2; FP(1).col = 'b';
            % would show states 1,2 in blue for eye trace
            FP(1).states = 1;  %before fixation
            FP(1).col = 'k';
            FP(2).states = 2;  % fixation held
            FP(2).col = 'b';
            %******* set which states are TimeSensitive, if [] then none
            TS = 2;  % state 2 is senstive, during Gabor flashing
            %********
            obj.startTime = GetSecs;
        end
        
        function keepgoing = continue_run_trial(obj,screenTime)
            keepgoing = 0;
            if (obj.state < 4)
                keepgoing = 1;
            end
            %****** store the last screen flip for noise history
            if (obj.FrameCount)
                obj.NoiseHistory(obj.FrameCount,1) = screenTime;
            end
            %*******************
        end
        
        %******************** THIS IS THE BIG FUNCTION *************
        function drop = state_and_screen_update(obj,currentTime,x,y)
            drop = 0;
            %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
            
            %%%%% STATE 0 -- GET INTO FIXATION WINDOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % If eye travels within the fixation window, move to state 1
            if obj.state == 0 && norm([x y]) < obj.P.fixWinRadius
                obj.state = 1; % Move to fixation grace
                obj.fixStart = GetSecs;
            end
            % Trial expires if not started within the start duration
            if obj.state == 0 && currentTime > obj.startTime + obj.P.startDur
                obj.state = 3; % Move to iti -- inter-trial interval
                obj.error = 1; % Error 1 is failure to initiate
                obj.itiStart = GetSecs;
            end
            
            %%%%% STATE 1 -- GRACE PERIOD TO BE IN FIXATION WINDOW %%%%%%%%%%%%%%%%
            % A grace period is given before the eye must remain in fixation
            if obj.state == 1 && currentTime > obj.fixStart + obj.P.fixGrace
                obj.state = 2; % Move to hold fixation
            end
            
            %%%%% STATE 2 -- HOLD FIXATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if obj.state == 2    % show flashing stimuli at random points each frame
                %***pick a random screen location but not overlapping fixation
                ampo = obj.P.gabMinRadius + (obj.P.gabMaxRadius-obj.P.gabMinRadius)*rand;
                ango = rand*2*pi;
                dx = cos(ango)*ampo;
                dy = sin(ango)*ampo;
                cX = obj.S.centerPix(1)+ round( obj.S.pixPerDeg * dx);
                cY = obj.S.centerPix(2)+ round( obj.S.pixPerDeg * dy);   %
                %****** update one of the Gabor's locations
                obj.hGabor{obj.GABcounter}.position = [cX cY];
                %****** store starting locations, set time as NaN
                obj.FrameCount = obj.FrameCount + 1;
                obj.NoiseHistory(obj.FrameCount,:) = [NaN,dx,dy,obj.GABcounter];
                %*********************
                obj.GABcounter = obj.GABcounter + 1;
                if (obj.GABcounter > obj.P.OriNum)
                    obj.GABcounter = 1;
                end
            end
            
            % If fixation is held for the fixation duration, then reward
            if obj.state == 2 && currentTime > obj.fixStart + obj.fixDur
                obj.state = 3; % Move to iti -- inter-trial interval
                obj.itiStart = GetSecs;
            end
            % Eye must remain in the fixation window
            if obj.state == 2 && norm([x y]) > obj.P.fixWinRadius
                obj.state = 3; % Move to iti -- inter-trial interval
                obj.error = 2; % Error 2 is failure to hold fixation
                obj.itiStart = GetSecs;
            end
            
            %%%%% STATE 3 -- INTER-TRIAL INTERVAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Deliver rewards
            if obj.state == 3
                if ~obj.error && obj.rewardCount < obj.P.rewardNumber
                    if currentTime > obj.itiStart + 0.2*obj.rewardCount % deliver in 200 ms increments
                        obj.rewardCount = obj.rewardCount + 1;
                        drop = 1;   % this is where you return with instruction to give reward
                    end
                else
                    if currentTime > obj.itiStart + 0.2   % enough time to flash fix break
                        obj.state = 4;
                        if obj.error
                            obj.Iti = obj.P.iti + obj.P.timeOut;
                        end
                    end
                end
            end
            
            % STATE SPECIFIC DRAWS
            switch obj.state
                case 0
                    if obj.showFix
                        if ~obj.faceTrial
                            obj.hFix.beforeFrame(1);
                        else
                            obj.Faces.beforeFrame();  %draw an image at random
                        end
                    end
                    obj.flashCounter = mod(obj.flashCounter+1,obj.P.flashFrameLength);
                    if obj.flashCounter == 0
                        obj.showFix = ~obj.showFix;
                        if obj.showFix && obj.faceTrial
                            if rand < obj.P.faceTrialFraction
                                obj.faceTrial = true;
                            end
                        else
                            obj.faceTrial = false;
                        end
                    end
                case 1
                    obj.hFix.beforeFrame(1);
                case 2
                    %***** then display all P.OriNum of the Gabors
                    for k = 1:obj.P.OriNum
                        obj.hGabor{k}.beforeFrame();  % draw Gabor
                    end
                    %****** put fixation above the Gabors
                    obj.hFix.beforeFrame(1);
                    
                case 3
                    if ~obj.error
                        if (obj.BlackFixation)
                            obj.hFix.beforeFrame(3);
                            obj.BlackFixation = obj.BlackFixation - 1;
                        else
                            obj.Faces.beforeFrame();
                        end
                    end
                    if (obj.error == 2)  % fixation break
                        obj.hFix.beforeFrame(2);
                        obj.RunFixBreakSound = 1;
                    end
            end
            
            %******** if sound, do here
            if (obj.RunFixBreakSound == 1) && (obj.NeverBreakSoundTwice == 0)
                sound(obj.fixbreak_sound,obj.fixbreak_sound_fs);
                obj.NeverBreakSoundTwice = 1;
            end
            %**************************************************************
        end
        
        function Iti = end_run_trial(obj)
            % returns generic Iti interval
            Iti = obj.Iti - (GetSecs - obj.itiStart);
        end
        
        function plot_trace(o,handles)
            %********* append other things eye trace plots if you desire
            h = handles.EyeTrace;
            set(h,'NextPlot','Replace');
            eyeRad = handles.eyeTraceRadius;
            % Fixation window
            r = o.P.fixWinRadius;
            fixX = o.P.xDeg;
            fixY = o.P.yDeg;
            plot(h,fixX+r*cos(0:.01:1*2*pi),fixY+r*sin(0:.01:1*2*pi),'--k');
            axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
            set(h,'NextPlot','Add');
        end
        
        function PR = end_plots(o,P,A)   %update D struct if passing back info
            
            %************* STORE DATA to PR
            PR = struct;
            PR.error = o.error;
            PR.fixDur = o.fixDur;
            PR.x = P.xDeg;
            PR.y = P.yDeg;
            %******* this is also where you store Gabor Flash Info
            PR.NoiseHistory = o.NoiseHistory(1:o.FrameCount,:);
            
            %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            o.D.error(A.j) = o.error;
            o.D.x(A.j) = P.xDeg;
            o.D.y(A.j) = P.yDeg;
            o.D.fixDur(A.j) = o.fixDur;
            
            %%%% Plot results %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Dataplot 1, errors
            errors = [0 1 2; sum(o.D.error==0) sum(o.D.error==1) sum(o.D.error==2)];
            bar(A.DataPlot1,errors(1,:),errors(2,:));
            title(A.DataPlot1,'Errors');
            ylabel(A.DataPlot1,'Count');
            set(A.DataPlot1,'XLim',[-.75 errors(1,end)+.75]);
            
            %% show the number - 2016-05-05 - Shaun L. Cloherty <s.cloherty@ieee.org>
            x = errors(1,:);
            y = 0.15*max(ylim);
            
            h = [];
            for ii = 1:size(errors,2)
                axes(A.DataPlot1);
                h(ii) = text(x(ii),y,sprintf('%i',errors(2,ii)),'HorizontalAlignment','Center');
                if errors(2,ii) > 2*y
                    set(h(ii),'Color','w');
                end
            end
            %%
            
            % Dataplot 2, wait time histogram
            if any(o.D.error==0)
                hist(A.DataPlot2,o.D.fixDur(o.D.error==0));
            end
            % title(A.DataPlot2,'Successful Trials');
            % show the numbers - 2016-05-06 - Shaun L. Cloherty <s.cloherty@ieee.org>
            title(A.DataPlot2,sprintf('%.2fs %.2fs',median(o.D.fixDur(o.D.error==0)),max(o.D.fixDur(o.D.error==0))));
            ylabel(A.DataPlot2,'Count');
            xlabel(A.DataPlot2,'Time');
            
        end
        
    end
    
end 
