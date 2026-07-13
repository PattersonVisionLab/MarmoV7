classdef PR_AcuityAsh < handle
% 
% Stimuli:
%   Faces       stimuli.gaussimages
%   hFix        stimuli.fixation
%   hProbe      stimuli.grating
%   hChoice     stimuli.circles
% TODO: closeUp doesn't close faces?
%
% States: 
%   7 Move to iti -- inter-trial interval

    
    properties 
        Iti   = 1;              % default Iti duration
        startTime   = 0;        % trial start time
        fixStart   = 0;         % fix acquired time
        itiStart   = 0;         % start of ITI interval
        fixDur   = 0;           % fixation duration
        stimStart   = 0;        % start of Gabor probe stimulus
        responseStart   = 0;    % start of choice period
        responseEnd   = 0;      % end of response period
        showFix   = true;       % trial start with fixation
        flashCounter   = 0;     % counts frames, used for fade in point cue?
        flashCounterMax   = 10; % counts before flip fixation
        rewardCount   = 0;      % counter for reward drops
        RunFixBreakSound   = 0; % variable to initiate fix break sound (once)
        NeverBreakSoundTwice = 0;   % other variable for fix break sound
        faceTrial   = false;    % trial with face to start
        faceFlash   = false;    % show face or fixation at random
    end
    
    properties (Access = private)
        winPtr; % ptb window
        state   = 0;      % state counter
        error   = 0;      % error state in trial
        %*********
        S;      % copy of Settings struct (loaded per trial start)
        P;      % copy of Params struct (loaded per trial)
        trialsList;  % list of trial types to run in experiment
        trialIndexer = [];  % object to run trial order
        %********* stimulus structs for use
        stimTheta   = 0;   % direction of choice
        Faces;             % object that stores face images for use
        hFix;              % object for a fixation point
        hProbe = [];       % object for Gabor stimuli
        hChoice = [];      % object for Choice Gabor stimuli
        fixbreak_sound;    % audio of fix break sound
        fixbreak_sound_fs; % sampling rate of sound
        %****************
        D = struct();        % store PR data for end plot stats
    end
    
    methods 
        function obj = PR_AcuityAsh(winPtr)
            obj.winPtr = winPtr;
            obj.trialsList = [];
        end
        
        function state = get_state(obj)
            state = obj.state;
        end
        
        function initFunc(obj, S, P)
            %********** Set-up for trial indexing (required)
            cors = [0,4];  % count these errors as correct trials
            reps = [1,2];  % count these errors like aborts, repeat

            obj.trialIndexer = marmoview.TrialIndexer(obj.trialsList, P, cors, reps);
            obj.error = 0;
            
            obj.Faces = stimuli.gaussimages(obj.winPtr,... 
                'bkgd', S.bgColour,'gray',false);   % color images
            obj.Faces.loadimages(fullfile(getMarmoViewPath(),...
                'SupportData', 'MarmosetFaceLibrary.mat'));  % uint8
            obj.Faces.position = [0,0] * S.pixPerDeg + S.centerPix;
            obj.Faces.radius = round(P.faceRadius * S.pixPerDeg);
            
            %********** Initialize Graphics Objects
            obj.hFix = stimuli.fixation(obj.winPtr);   % fixation stimulus
            obj.hProbe = stimuli.grating(obj.winPtr);  % grating probe
            for k = 1:P.apertures
                % choice grating, right (vertical)
                obj.hChoice{k} = stimuli.circles(obj.winPtr); 
                ango = (((k-1)/P.apertures)*2*pi) + (pi/4);
                xpos = P.ecc * cos(ango);
                ypos = P.ecc * sin(ango);
                obj.hChoice{k}.position = [(S.centerPix(1) + round(xpos * S.pixPerDeg)), ...
                    (S.centerPix(2) + round(ypos * S.pixPerDeg))];
                obj.hChoice{k}.size = round(P.choiceRad * S.pixPerDeg);
                obj.hChoice{k}.colour = P.bkgd - floor( P.choiceCon * 1.27);
                obj.hChoice{k}.weight = P.choiceWidth; %width in pixels
            end
            %********* if stimuli remain constant on all trials, set-them up here
            
            % set fixation point properties
            sz = P.fixPointRadius*S.pixPerDeg;
            obj.hFix.cSize = sz;
            obj.hFix.sSize = 2*sz;
            if S.use8Bit
                obj.hFix.cColour = ones(1,3); % black
                obj.hFix.sColour = repmat(255,1,3); % white
            else
                obj.hFix.cColour = [0 0 0];
                obj.hFix.sColour = [1 1 1];
            end
            obj.hFix.position = [0,0]*S.pixPerDeg + S.centerPix;
            obj.hFix.updateTextures();
            
            %********** load in a fixation error sound ************
            [y,fs] = audioread(['SupportData',filesep,'gunshot_sound.wav']);
            y = y(1:floor(size(y,1)/3),:);  % shorten it, very long sound
            obj.fixbreak_sound = y;
            obj.fixbreak_sound_fs = fs;
            %*********************
        end
        
        function closeFunc(o)
            o.hFix.CloseUp();
            o.hProbe.CloseUp();
            for k = 1:length(o.hChoice)
                o.hChoice{k}.CloseUp;
            end
        end
        
        function generate_trialsList(obj, S, P)
            % Spatial frequency sampling
            lx = log(P.minFreq):((log(P.maxFreq)-log(P.minFreq))/P.FreqNum):log(P.maxFreq);
            sf_sampling =  exp(lx); % [2 4 6 8 10 12];
            
            % Generate trials list
            obj.trialsList = [];
            for zk = 1:size(sf_sampling, 2)
                for k = 1:P.apertures   % do both choice directions
                    %**********
                    stimori = 90;  %always vertical
                    ango = (((k-1)/P.apertures)*2*pi) + (pi/4);
                    xpos = P.ecc * cos(ango);
                    ypos = P.ecc * sin(ango);
                    %*************
                    mjuice = 2 + floor(sf_sampling(zk)/2);  % give more juice for higher spatial freq
                    if (mjuice > P.rewardNumber)
                        mjuice = P.rewardNumber;
                    end
                    %*************
                    % storing list of trials, 
                    % [Choice_xpos Choice_ypos  SpatFreq Phase Ori Juice_Amount]
                    obj.trialsList = [obj.trialsList ; ...
                        [xpos ypos sf_sampling(zk) 0  stimori mjuice]];
                    obj.trialsList = [obj.trialsList ; [xpos ypos sf_sampling(zk) 90 stimori mjuice]];
                end
            end
        end
        
        function P = next_trial(o,S,P)
            %********************
            o.S = S;
            o.P = P;
            %*******************
            
            if P.runType == 1   % go through trials list
                i = o.trialIndexer.getNextTrial(o.error);
                %****** update trial parameters for next trial
                P.choiceX = o.trialsList(i,1);
                P.choiceY = o.trialsList(i,2);
                P.xDeg = P.choiceX;  % detection task, choice is at target
                P.yDeg = P.choiceY;
                P.cpd = o.trialsList(i,3);
                P.phase = o.trialsList(i,4);
                P.orientation = o.trialsList(i,5);
                P.rewardNumber = o.trialsList(i,6);
                %******************
                o.P = P;  % set to most current
                disp(P)
            end
            
            % Calculate this for pie slice windowing for choice
            o.stimTheta = atan2(P.choiceY,P.choiceX);
            
            % Make Gabor stimulus texture
            o.hProbe(1).position = [(S.centerPix(1) + round(P.xDeg*S.pixPerDeg)),...
                                    (S.centerPix(2) - round(P.yDeg*S.pixPerDeg))];
            o.hProbe(1).radius = round(P.radius*S.pixPerDeg);
            o.hProbe(1).orientation = P.orientation; % vertical for the right
            o.hProbe(1).phase = P.phase;
            o.hProbe(1).cpd = P.cpd;
            o.hProbe(1).range = P.range;
            o.hProbe(1).square = logical(P.squareWave);
            o.hProbe(1).bkgd = P.bkgd;
            o.hProbe(1).updateTextures();
            %******************************************
            
            % Select a face from image set to show at center
            o.Faces.imagenum = randi(length(o.Faces.tex));  % pick any at random
            if o.faceTrial
                o.faceTrial = false;  % never do two in a row
            else
                if rand < P.faceProb   % chance of a face fixation trial
                    o.faceTrial = true;
                else
                    o.faceTrial = false;
                end
            end
            %*************
        end
        
        function [FP,TS] = prep_run_trial(obj)
            cprintf('_[1,0.7,0.5]', '\tProtocol, call prepRunTrial\n');
            %********VARIABLES USED IN RUNNING TRIAL LOGISTICS
            obj.fixDur = obj.P.fixMin + ceil(1000*obj.P.fixRan*rand)/1000;  % randomized fix duration
            if obj.faceTrial
                obj.fixDur = obj.fixDur + obj.P.faceHoldExtra;
            end
            obj.faceFlash = false;
            % showFix is a flag to check whether to show the fixation spot or not while
            % it is flashing in state 0
            obj.showFix = true;
            % flashCounter counts the frames to switch ShowFix off and on
            obj.flashCounter = 0;
            obj.flashCounterMax = floor(obj.P.flashFrameLength/2) + floor( rand * obj.P.flashFrameLength);
            % rewardCount counts the number of juice pulses, 1 delivered per frame
            obj.rewardCount = 0;
            %****** deliver sound on fix breaks
            obj.RunFixBreakSound =0;
            obj.NeverBreakSoundTwice = 0;
            % Setup the state
            obj.state = 0; % Showing the face
            obj.error = 0; % Start with error as 0
            obj.Iti = obj.P.iti;   % set ITI interval from P struct stored in trial
            if (obj.faceTrial)
                obj.Iti = obj.P.faceIti;  % wait longer to re-establish fixation
            end
            %******* Plot States Struct (show fix in blue for eye trace)
            % any special plotting of states,
            % FP(1).states = 1:2; FP(1).col = 'b';
            % would show states 1,2 in blue for eye trace
            FP(1).states = 0:1;  %before trial even?
            FP(1).col = 'k';
            FP(2).states = 2:3;  %during fixation
            FP(2).col = 'b';
            FP(3).states = 4;  % fixation held
            FP(3).col = 'g';
            FP(4).states = 5;
            FP(4).col = 'r';
            %******* set which states are TimeSensitive, if [] then none
            TS = 1:5;  % all times during target presentation
            %********
            obj.startTime = GetSecs;
        end
        
        function keepgoing = continue_run_trial(obj, screenTime)
%            cprintf('_[1,0.7,0.5]', '\tProtocol, call continueRunTrial\n');
            keepgoing = 0;
            if (obj.state < 9)
                keepgoing = 1;
            end
        end
        
        %******************** THIS IS THE BIG FUNCTION *************
        function drop = state_and_screen_update(obj, currentTime, x, y)
            drop = 0;
            %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
            
            % POLAR COORDINATES FOR PIE SLICE METHOD, note three values of polT to
            % ensure atan2 discontinuity does not wreck shit
            polT = atan2(y,x)+[-2*pi 0 2*pi];
            polR = norm([x y]);
            
            %%%%% STATE 0 -- GET INTO FIXATION WINDOW %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % If eye travels within the fixation window, move to state 1
            if obj.state == 0 && norm([x y]) < obj.P.initWinRadius
                obj.state = 1; % Move to fixation grace
                obj.fixStart = GetSecs;
                cprintf('_[0.5,0.5,0.5]', '\tProtocol, state 1 (fixation)\n');
            end
            
            % Trial expires if not started within the start duration
            if obj.state == 0 && currentTime > obj.startTime + obj.P.startDur
                obj.state = 8; % Move to iti -- inter-trial interval
                obj.error = 1; % Error 1 is failure to initiate
                obj.itiStart = GetSecs;
                cprintf('_[0.5,0.5,0.5]', '\tProtocol, state 8 (expired)\n');
            end
            
            %%%%% STATE 1 -- GRACE PERIOD TO BE IN FIXATION WINDOW %%%%%%%%%%%%%%%%
            % A grace period is given before the eye must remain in fixation
            if obj.state == 1 && currentTime > obj.fixStart + obj.P.fixGrace
                if norm([x y]) < obj.P.initWinRadius
                    obj.state = 2; % Move to hold fixation
                else
                    obj.state = 8;
                    obj.error = 1; % Error 1 is failure to initiate
                    obj.itiStart = GetSecs;
                end
            end
            
            %%%%% STATE 2 -- HOLD FIXATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % If fixation is held for the fixation duration, move to state 3
            if obj.state == 2 && currentTime > obj.fixStart + obj.fixDur
                obj.state = 3; % Move to show stimulus
                obj.stimStart = GetSecs();
                
                cprintf('_[0.5,0.5,0.5]', '\tProtocol, state 3 (fixation held)\n');
            end
            % Eye must remain in the fixation window
            if ((obj.state == 2) || (obj.state == 3)) && norm([x y]) > obj.P.fixWinRadius
                obj.state = 8; % Move to iti -- inter-trial interval
                obj.error = 2; % Error 2 is failure to hold fixation
                obj.itiStart = GetSecs();
                
                cprintf('_[0.5,0.5,0.5]', '\tProtocol, state 8 (fixation lost)\n');
            end
            
            %%%%% STATE 4 -- SHOW STIMULUS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Eye leaving fixation indicates a saccade, move to state 4
            if (obj.state == 4) && norm([x y]) > obj.P.fixWinRadius
                obj.state = 5; % dim fixation if so, then move to saccade in flight
                obj.responseStart = GetSecs();
            end
            
            %**** in this scenario, eye always leaves, only question if
            %**** it goes to the right location
            % Hold fixation through the stimulus presentation
            if obj.state == 3 && currentTime > obj.stimStart + obj.P.stimHold
                if obj.faceTrial
                    obj.state = 7;  % move to reward and show the face
                    obj.itiStart = GetSecs();
                else
                    obj.state = 4; % remove stim and dim fixation to cue "Go"
                    %***** reward here for holding of fixation
                    %if (isfield(o.P,'rewardFix'))
                    %   if (o.P.rewardFix)
                    %      drop = 1;
                    %   end
                    %end
                    %***********************
                end
            end
            
            % Eye must leave fixation within stimulus duration or counted as no
            % response after some much longer interval
            if obj.state == 4 && currentTime > obj.stimStart + obj.P.noresponseDur
                obj.state = 7; % Move to iti -- inter-trial interval
                obj.error = 3; % Error 3 is failure to make a saccade
                obj.itiStart = GetSecs();
                
                cprintf('_[0.5,0.5,0.5]', '\tProtocol, state 7 (no saccade)\n');
            end
            
            %%%%% STATE 5 -- IN FLIGHT %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Give the saccade time to finish flight
            if obj.state == 5 && currentTime > obj.responseStart + obj.P.flightDur
                % If the saccade shifted gaze to the stimulus, proceed to state 5
                if polR > obj.P.stimWinMinRad && polR < obj.P.stimWinMaxRad && min(abs(obj.stimTheta-polT)) < obj.P.stimWinTheta
                    obj.state = 6; % Move to hold stimulus
                    obj.responseEnd = GetSecs();
                    % Otherwise the response failed to select the stimulus
                else
                    obj.state = 7; % Move to iti -- inter-trial interval
                    obj.error = 4; % Error 4 is failure to select the stimulus.
                    obj.itiStart = GetSecs();
                end
            end
            
            %%%%% STATE 6 -- HOLD STIMULUS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % If the eye does not leave the stimulus, then reward
            if obj.state == 6 && currentTime > obj.responseEnd + obj.P.holdDur
                obj.state = 7; % Move to iti -- trial is over
                obj.itiStart = GetSecs();
                
                cprintf('_[0.5,0.5,0.5]', '\tProtocol, state 7 (reward)\n');
            end
            % If the eye leaves before hold duration, no reward
            if obj.state == 6 && ~(polR > obj.P.stimWinMinRad && polR < obj.P.stimWinMaxRad && min(abs(obj.stimTheta-polT)) < obj.P.stimWinTheta)
                obj.state = 7; % Move to iti -- inter-trial interval
                obj.error = 5; % Error 5 is failure to hold the stimulus
                obj.itiStart = GetSecs();
            end
            
            %%%%% STATE 7 -- INTER-TRIAL INTERVAL %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Deliver rewards
            if obj.state == 7
                if ~obj.error && obj.rewardCount < obj.P.rewardNumber
                    if currentTime > obj.itiStart + 0.2*obj.rewardCount % deliver in 200 ms increments
                        obj.rewardCount = obj.rewardCount + 1;
                        drop = 1;
                        
                        cprintf('_[0.5,0.5,0.5]', '\tProtocol, reward delivered\n');
                    end
                else
                    obj.state = 8;
                end
            end
            %******* fixation break feedback, but otherwise go to state 9
            if obj.state == 8
                if currentTime > obj.itiStart + 0.2   % enough time to flash fix break
                    obj.state = 9;
                    if obj.error
                        obj.Iti = obj.Iti + obj.P.blank_iti;
                    end
                end
            end
            
            % STATE SPECIFIC DRAWS
            switch obj.state
                case 0
                    %******* flash fixation point to draw monkey to it
                    if obj.showFix
                        if obj.faceFlash
                            obj.Faces.beforeFrame();  %draw an image at random
                        else
                            obj.hFix.beforeFrame(1);
                        end
                    end
                    obj.flashCounter = mod(obj.flashCounter+1,obj.flashCounterMax);
                    if obj.flashCounter == 0
                        obj.showFix = ~obj.showFix;
                        if obj.faceTrial
                            if (rand < obj.P.faceProbFlash)
                                obj.faceFlash = true;
                            else
                                obj.faceFlash = false;
                            end
                        end
                    end
                    
                case 1
                    % Bright fixation spot, prior to stimulus onset
                    obj.hFix.beforeFrame(1);
                    
                case 2
                    % Continue to show fixation for a hold period
                    obj.hFix.beforeFrame(1);
                    
                case 3
                    if ~obj.faceTrial
                        % fixation remains on while Gabor stim is shown
                        %********* show stimulus
                        if ( currentTime < obj.stimStart + obj.P.stimDur )
                            obj.hProbe.beforeFrame();
                        end
                        %************
                        obj.hFix.beforeFrame(1);
                    end
                case 4    % disappear fixation and show apertures to go
                    
                    %********* show stimulus if still appropriate
                    if ~obj.faceTrial
                        if ( currentTime < obj.stimStart + obj.P.stimDur )
                            obj.hProbe.beforeFrame();
                        else
                            % Aperture choice stimuli shown
                            for k = 1:obj.P.apertures
                                obj.hChoice{k}.beforeFrame();
                            end
                        end
                    end
                    
                case 5    % saccade in flight, dim fixation, just in case not done before
                    
                    %********* show stimulus if still appropriate
                    if ~obj.faceTrial
                        if ( currentTime < obj.stimStart + obj.P.stimDur )
                            obj.hProbe.beforeFrame();
                        else
                            % Aperture choice stimuli shown
                            for k = 1:obj.P.apertures
                                obj.hChoice{k}.beforeFrame();
                            end
                        end
                    end
                    
                case {6 7} 
                    % once saccade landed, reappear stimulus,  show correct option
                    
                    if obj.faceTrial
                        if (obj.error == 0)
                            obj.Faces.beforeFrame();
                        end
                    else
                        % Only the correct aperture choice stimuli shown
                        if (obj.error == 0)  % no error, show stim again
                            obj.hProbe.beforeFrame();
                            % Aperture choice stimuli shown
                            for k = 1:obj.P.apertures
                                obj.hChoice{k}.beforeFrame();
                            end
                        else
                            if (obj.error == 4)  % wrong aperture
                                % Aperture choice stimuli shown
                                for k = 1:obj.P.apertures
                                    obj.hChoice{k}.beforeFrame();
                                end
                            end
                        end
                    end
                    
                case 8
                    if (obj.error == 2) % broke fixation
                        obj.hFix.beforeFrame(2);
                        %once you have a sound object, put break fix here
                        obj.RunFixBreakSound = 1;
                    end
                    % leave everything blank for a minimum ITI
            end
            
            %******** if sound, do here
            if (obj.RunFixBreakSound == 1) && (obj.NeverBreakSoundTwice == 0)
                sound(obj.fixbreak_sound,obj.fixbreak_sound_fs);
                obj.NeverBreakSoundTwice = 1;
            end
        end
        
        function Iti = end_run_trial(o)
            cprintf('_[1,0.7,0.5]', '\tProtocol, call endRunTrial\n');
            
            Iti = o.Iti - (GetSecs() - o.itiStart); % returns generic Iti interval
        end
        
        function plot_trace(o,handles)
            % This function plots the eye trace from a trial in the EyeTracker
            % window of MarmoView.
            tic
            h = handles.EyeTrace;
            % Fixation window
            set(h,'NextPlot','Replace');
            r = o.P.fixWinRadius;
            plot(h,r*cos(0:.01:1*2*pi),r*sin(0:.01:1*2*pi),'--k');
            set(h,'NextPlot','Add');
            
            % Stimulus window
            stimX = o.P.choiceX;
            stimY = o.P.choiceY;
            eyeRad = handles.eyeTraceRadius;
            minR = o.P.stimWinMinRad;
            maxR = o.P.stimWinMaxRad;
            errT = o.P.stimWinTheta;
            stimT = atan2(stimY,stimX);
            
            plot(h,[minR*cos(stimT+errT) maxR*cos(stimT+errT)],[minR*sin(stimT+errT) maxR*sin(stimT+errT)],'--k');
            plot(h,[minR*cos(stimT-errT) maxR*cos(stimT-errT)],[minR*sin(stimT-errT) maxR*sin(stimT-errT)],'--k');
            plot(h,minR*cos(stimT-errT:pi/100:stimT+errT),minR*sin(stimT-errT:pi/100:stimT+errT),'--k');
            plot(h,maxR*cos(stimT-errT:pi/100:stimT+errT),maxR*sin(stimT-errT:pi/100:stimT+errT),'--k');
            r = o.P.radius;
            plot(h,stimX+r*cos(0:.01:1*2*pi),stimY+r*sin(0:.01:1*2*pi),'-k');
            axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
            fprintf('---\nplot_trace took %.4f secs\n---\n', toc);
        end
        
        function PR = end_plots(obj, P, A)   
            %update D struct if passing back info
            
            %************* STORE DATA to PR
            PR = struct();
            PR.error = obj.error;
            PR.fixDur = obj.fixDur;
            PR.x = P.xDeg;
            PR.y = P.yDeg;
            PR.choiceX = P.choiceX;
            PR.choiceY = P.choiceY;
            PR.cpd = P.cpd;
            PR.faceTrial = obj.faceTrial;
            %******* this is also where you could store Gabor Flash Info
            
            %%%% Record some data %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.D.error(A.j) = obj.error;
            obj.D.xDeg(A.j) = P.xDeg;
            obj.D.yDeg(A.j) = P.yDeg;
            obj.D.x(A.j) = P.choiceX;
            obj.D.y(A.j) = P.choiceY;
            obj.D.cpd(A.j) = P.cpd;
            
            %%%% Plot results %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Dataplot 1, errors
            errors = [0 1 2 3 4 5;
                sum(obj.D.error==0) sum(obj.D.error==1) sum(obj.D.error==2) sum(obj.D.error==3) sum(obj.D.error==4) sum(obj.D.error==5)];
            bar(A.DataPlot1,errors(1,:),errors(2,:));
            title(A.DataPlot1,'Errors');
            ylabel(A.DataPlot1,'Count');
            set(A.DataPlot1,'XLim',[-.75 5.75]);
            
            % DataPlot2, fraction correct by spatial location (left or right trial)
            % Note that this plot will break down if multiple stimulus eccentricities
            % or a non horizontal hexagon are used. It will also only calculate
            % fraction correct for locations assigned by the trials list.
            locs = unique(obj.trialsList(:,1:2),'rows');
            nlocs = size(locs,1);
            labels = cell(1,nlocs);
            fcXxy = zeros(1,nlocs);
            for i = 1:nlocs
                x = locs(i,1); y = locs(i,2);
                Ncorrect = sum(obj.D.x == x & obj.D.y == y & obj.D.error == 0);
                Ntotal = sum(obj.D.x == x & obj.D.y == y & (obj.D.error == 0 | obj.D.error > 2.5));
                if  Ntotal > 0
                    fcXxy(i) = Ncorrect/Ntotal;
                end
                % Constructs labels based on the six locations
                if x > 0 && abs(y) < .01     
                    labels{i} = 'R';    
                end
                if x < 0 && abs(y) < .01       
                    labels{i} = 'L';    
                end
            end
            bar(A.DataPlot2,1:nlocs,fcXxy);
            title(A.DataPlot2,'By Location');
            ylabel(A.DataPlot2,'Fraction Correct');
            set(A.DataPlot2,'XTickLabel',labels);
            axis(A.DataPlot2,[.25 nlocs+.75 0 1]);
            
            % Dataplot3, fraction correct by cycles per degree
            % This plot only calculates the fraction correct for trials list cpds.
            cpds = unique(obj.trialsList(:,3));
            ncpds = size(cpds,1);
            fcXcpd = zeros(1,ncpds);
            labels = cell(1,ncpds);
            for i = 1:ncpds
                cpd = cpds(i);
                Ncorrect = sum(obj.D.cpd == cpd & obj.D.error == 0);
                Ntotal = sum(obj.D.cpd == cpd & (obj.D.error == 0 | obj.D.error > 2.5));
                if Ntotal > 0
                    fcXcpd(i) = Ncorrect/Ntotal;
                end
                labels{i} = num2str(round(cpd)); %num2str(round(10*cpd)/10);
            end
            bar(A.DataPlot3, 1:ncpds,fcXcpd);
            title(A.DataPlot3, 'By Cycles per Degree');
            ylabel(A.DataPlot3, 'Fraction Corret');
            set(A.DataPlot3, 'XTickLabel',labels);
            axis(A.DataPlot3, [.25 ncpds+.75 0 1]);
        end       
    end
    
end 
