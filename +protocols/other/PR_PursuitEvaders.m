classdef PR_PursuitEvaders < handle
  % Matlab class for running an experimental protocl
  %
  % The class constructor can be called with a range of arguments:
  %
  
  properties (Access = public)    
       Iti = 1;        % default Iti duration
       startTime = 0;  % trial start time
       startSearch = 0; % time before reset target
       startTrial = 0;  % onset of new search
       waitSearch = 0;  % gap time between reappearing target
       fixOn = 0;      % is fixation point on
       fixStart = 0;   % time of fixation start
       holdfixStart = 0; % time fixation acquired to start trial
       holdtarget = 0;  % time for high SF part of pursuit
       rewardStart = 0; % time from show reward
       conval = 1;     % contrast value in look up table
       angoffset = 0;  % orientation of Gabor
       flashCounter = 0;   % counter to flash fixation
       showFix = 0;        % used with flash counter
       hardCount = 0;    % count repeated hard trials
       DotTrial = 0;    % trial using fixation point, straight
                        % if DotTrial == 2, use jiggle motion
       DotSpeed = 0;    % speed of stimulus for trial
       ConTrial = 0;    % if Gabor trial, change contrast
       FixJuice = 0;    % give a drop for starting fixation sometimes
       ExtraJuice = 0;  % extra drop for hard trials (high SF)
       FirstPursuit = 0;  % mark first time pursuing target
  end
      
  properties (Access = private)
    winPtr; % ptb window
    state = 0;      % state counter
    error = 0;      % error state in trial
    %************
    S;      % copy of Settings struct (loaded per trial start)
    P;      % copy of Params struct (loaded per trial)
    %********* stimulus structs for use
    Faces;      % object that stores face images for use
    Gabor;      %object for grating stimulus
    hFix;       % fixation trial object
    conEvents;  % list on contrast events
    startCon;   % current test contrast
        
    %*********
    gaborRadius; % width of tracked targets
    gaborPathN;  % length of gabor motion for trial (video frames)
    gaborPathX;  % X position over N frames
    gaborPathY;  % Y position over N frames
    gaborPathT;  % T, counter for stepping through N frames
    gaborState;  % State during tracking, recorded
    gaborConNum; % number of contrast states
    gaborConVals; % contrast values
    gaborSpatialVals; %Spatial frequency values
    gaborSpatialNum; %number of spatial frequency values
    %*********
    ango = [];    % array per item, direction of motion 
    % view = [];    % array per obj, being tracked
    xx = [];      % array per item, x velocity    
    yy = [];      % array per item, y velocity
    %****************
    D = struct;    % store PR data for end plot stats, will store dotmotion array
  end
  
  methods (Access = public)
    function o = PR_PursuitEvaders(winPtr)
      o.winPtr = winPtr;     
    end
    
    function state = get_state(o)
        state = o.state;
    end
    
    function initFunc(o,S,P)  
        
        %**** if concatenating, but initialize them
        o.D.error = [];
        o.D.errdist = [];
        o.hardCount = 0;
        %**********
        
        o.Faces = stimuli.gaussimages(o.winPtr,'bkgd',S.bgColour,'gray',false);   % color images
        o.Faces.loadimages('./SupportData/MarmosetFaceLibrary.mat'); 
        o.Faces.position = [0,0]*S.pixPerDeg + S.centerPix; % at center
        o.Faces.radius = round(P.faceradius*S.pixPerDeg);
        o.Faces.imagenum = randi(length(o.Faces.tex));  % pick any at random
        
        %********** set Gabor contrast values
        % o.gaborSpatialVals = [2.5 5 5.6 6.2 6.9 7.6 8.5 9.4 10.5 11.6 12.9 14.4 16 20];
        o.gaborSpatialVals = [2.5 5 5.6 6.2 6.9 7.6 8.5 9.4];
        o.gaborSpatialNum = length(o.gaborSpatialVals);
        
        %**********************************
        
        %************     
        o.gaborRadius = (P.gaborRadius * S.pixPerDeg);
        
        %Setting up Gabor (constant parameters every trial)
        if (1)
            o.Gabor = stimuli.agrating(o.winPtr); %init Gabor 
            o.Gabor.position = [S.centerPix(1),S.centerPix(2)]; %will change randomly (later)
            o.Gabor.radius = o.gaborRadius; 
            o.Gabor.orientation = P.gaborOri; % default ori (otherwise change with target motion)
            o.Gabor.phase = 90;
            o.Gabor.cpd = P.gaborCpd;
            o.Gabor.square = false;
            o.Gabor.bkgd = P.bkgd;
            o.Gabor.aspect = 1;
            o.Gabor.transparent = 1.0; %0.50;  % half contrast, should allow blends on collisions
            %*****
            o.Gabor.range = 127; 
            o.Gabor.updateTextures();
            %****************************
        end
        
        %******* create fixation point ****************
        o.hFix = stimuli.fixation(o.winPtr);   % fixation stimulus
        sz = P.fixPointRadius*S.pixPerDeg;
        o.hFix.cSize = sz;
        o.hFix.sSize = 2*sz;
        o.hFix.cColour = ones(1,3); % black
        o.hFix.sColour = repmat(255,1,3); % white
        o.hFix.position = [0,0]*S.pixPerDeg + S.centerPix; % at center
        o.hFix.updateTextures();
        %**********************************
        
    end
   
    function closeFunc(o)
        o.hFix.CloseUp();
        o.Gabor.CloseUp();
        o.Faces.CloseUp();
    end
   
    function generate_trialsList(o,S,P)
           % nothing for this protocol
    end
   
    function reset_target(o)
        if (rand < 0.5)
            rango = randn * (o.P.startAng * pi / 180);
        else
            rango = pi + (randn * (o.P.startAng * pi / 180));
        end
        % rango = rand*2*pi;
        o.xx = (o.P.gaborStartRad * cos(rango));
        o.yy = (o.P.gaborStartRad * sin(rango));
        %******* point the angle back towards center when initialized
        anga = angle(complex(o.xx,o.yy));
        if (anga > pi)
              anga = anga - pi;
        else
              anga = anga + pi;
        end
        o.ango = anga;  % will be pointed right towards fixation
        o.gaborPathX(o.gaborPathT,1) = o.xx;  % set to start point for now
        o.gaborPathY(o.gaborPathT,1) = o.yy;
        o.Gabor.position = [o.xx,o.yy];
    end
    
    function update_positions(o)
        tt = o.gaborPathT;
        if (1)
              if (o.P.gaborStep > 0) && ...
                  ( (o.DotTrial == 0) || (o.DotTrial == 2) )  % if DotTrial it is straight
                o.ango = o.ango + (o.P.gaborStep * (pi/180) * randn); 
              end
              dx = ((o.DotSpeed / o.S.frameRate) * cos(o.ango));
              dy = ((o.DotSpeed / o.S.frameRate) * sin(o.ango));
              %******
              nx = o.xx + dx;
              ny = o.yy + dy;
               if (~o.P.useCircleBoundary)  % square boundary
                if (abs(nx) > o.P.gaborBoundary)
                  dx = -dx;
                  o.ango = angle(complex(dx,dy));  % reset angle
                  nx = o.xx + (2*dx);
                end
                if (abs(ny) > o.P.gaborBoundary)
                  dy = -dy;
                  o.ango = angle(complex(dx,dy));  % reset angle
                  ny = o.yy + (2*dy);
                end
              else   % circular boundary
                rado = sqrt( nx^2 + ny^2);
                if (rado > o.P.gaborBoundary)  % radius
                   cx = nx/rado;
                   cy = ny/rado;  % normal vector
                   paro = (dx*cx) + (dy*cy);
                   ortho = (dx*cy) - (dy*cx);
                   ndx = -(paro * cx) + (ortho * cy);
                   ndy = -(paro * cy) - (ortho * cx);
                   o.ango = angle(complex(ndx,ndy));
                   %*****
                   dx = ndx;
                   dy = ndy;
                   nvec = [o.xx,o.yy];
                   nvec = 0.5*nvec/norm(nvec);
                   nx = o.xx + dx - nvec(1);
                   ny = o.yy + dy - nvec(2);
                end
              end
              %******* update xx and yy
              o.xx = nx;
              o.yy = ny;
              %******* store the location in pixel coordinates
              o.gaborPathX(tt,1) = o.xx;
              o.gaborPathY(tt,1) = o.yy;
              %*******************************************
        end
    end
    
    function P = next_trial(o,S,P);
          %********************
          o.S = S;
          o.P = P;   
          o.error = 0;
          o.fixOn = 0;
          o.fixStart = NaN;
          o.conEvents = [];
          o.startCon = 0;
          o.startSearch = 0;
          o.startTrial = NaN;
          o.waitSearch = NaN;
          o.ConTrial = 0;  % not set
          o.showFix = 1;
          o.FirstPursuit = 1;
          %*******************
          o.angoffset = 0;
          if isfield(o.D,'error')
            if (mod(length(o.D.error),2) == 0)
              o.angoffset = (pi/2);  % make half of trials orthogonal Gabor
            end
          end
          
          o.DotTrial = 0;
          o.DotSpeed = o.P.gaborSpeed;
          if (rand < o.P.DotTrialProb)
              if (rand < o.P.DotJiggleProb)
                  o.DotTrial = 2;
              else
                  o.DotTrial = 1;
              end
              o.DotSpeed = o.P.dotSpeedArray( randi(length(o.P.dotSpeedArray)) );
          end
          
          %**** Question: should we implement full random walk for trial
          %**** trial duration now? If so, let's store it in a long list
          %**** and use a counter to step through it for display over trial
          o.gaborPathN = floor( o.P.gaborPathTime * o.S.frameRate );
          o.gaborPathX = zeros(o.gaborPathN,1);
          o.gaborPathY = zeros(o.gaborPathN,1);
          o.gaborState = nan(o.gaborPathN,5);
          o.gaborPathT = 1;
          %*******
          o.ango = zeros(1,1);
          % o.view = zeros(1,1);
          o.xx = zeros(1,1);
          o.yy = zeros(1,1);
          %********
          o.reset_target();
          o.hFix.position = S.centerPix; % at center
          %********
    end
    
    function [FP,TS] = prep_run_trial(o)
        % Setup the state
        o.state = 0; % Showing the face
        Iti = o.P.iti;   % set ITI interval from P struct stored in trial
        if (rand < o.P.probFixJuice)
            o.FixJuice = 1;
        else
            o.FixJuice = 0;
        end
        o.ExtraJuice = 1;  % default for all trials, penalize 1 if drop in flight
        %*******
        FP(1).states = 2;  % any special plotting of states, 
        FP(1).col = 'c';
        FP(2).states = 3;  % any special plotting of states, 
        FP(2).col = 'b';
        FP(3).states = 4;  % any special plotting of states, 
        FP(3).col = 'm';   % FP(1).states = 1:2; FP(1).col = 'b';
        %***********
        
        %******* set which states are TimeSensitive, if [] then none
        % TS = []; %[0:2];  % if set, eye calib cannot be updated during those states
        TS = [2:4];
        %********
        o.startTime = GetSecs;
    end
    
    function keepgoing = continue_run_trial(o,screenTime)
        keepgoing = 1;
        if (o.state == 6)
            keepgoing = 0;
        end
        if (o.gaborPathT >= o.gaborPathN)
            keepgoing = 0;
        end
    end
   
    %******************** THIS IS THE BIG FUNCTION *************
    function drop = state_and_screen_update(o,currentTime,x,y) 
        drop = 0;
        
       %******** need to code here state transitions
       %*** state 0:  not looking at Gabor at all (outside fix radius from
       %*** state 1: looking within Gabor radius, time started for reward
       %***          ... if stop, fall back to state 0 (timer off)
       %*** state 2: looking longer than time, give reward show fix
       %***            for some duration and return to state 0, start new
       tt = o.gaborPathT;
       
       %********* check on contrast and update as needed
       if (1)
         o.Gabor.range = 127;                %range for spatial freq?
         
         %default spatial freq
         o.Gabor.cpd = o.gaborSpatialVals(1); %spatial freq = 2
         
         o.Gabor.radius = o.gaborRadius;
         o.Gabor.square = false;

         if (o.state == 4) % change to square wave
             o.Gabor.square = true;
             o.Gabor.radius = 0.5 * o.gaborRadius;
             o.Gabor.range = 127; %max contrast            
         else
             if (o.startCon)  % state 1 or 2
               %&&&&&&&&&& This is an issue, should be o.gaborSpatialNum
                if (o.startCon == o.gaborSpatialNum)  % Most difficult level
                    o.Gabor.range = 0; % grey away stimulus, 0 contrast
                else
                    o.Gabor.cpd = o.gaborSpatialVals(o.startCon);
                end
             end
         end
         %*** motion dir
         vang = o.ango;
         vang = vang + o.angoffset;
         vang = vang - (floor(vang/(2*pi)) * (2*pi));
         %******
         if (o.P.updateOrientation) % if you want orientation to move with motion (like insect)
            o.Gabor.orientation = o.ango * (180/pi);  % match orientation to direction of motion
         end
         o.Gabor.updateTextures();
       end
       
       %**** determine which targets viewed and incre= vanment time-steps 
%        if (1)
%          tdist = norm([(x-o.gaborPathX(tt,1)),(y-o.gaborPathY(tt,1))]);
%          if (tdist < o.P.fixRadius)
%              if (o.view == 0)
%                 o.view = currentTime;  % if first time view, mark time
%              end
%          else
%              o.view = 0;
%          end
%        end
       %*******
       
       fixdist = norm(x,y); % from center of screen
       if (tt > 1)
         tdist = norm([(x-o.gaborPathX(tt,1)),(y-o.gaborPathY(tt,1))]); % pursuit target 
       else
         tdist = fixdist;
       end
       FixRad = o.P.fixRadius; % default is tight window, 2.5     
       %*******
       
       switch o.state
           case 5,  % using 5th state as a wait before end trial
               %****** wait a pause before go to next trial
               if ((currentTime - o.startSearch) > o.waitSearch)
                     o.state = 6;
               end
           case 0,  % waiting to start on fixation
               %****** wait a random time to reappear target for search
               o.holdfixStart = 0;
               if isnan(o.waitSearch)
                 o.state = 1;
                 o.startCon = 0;
                 o.startSearch = currentTime;
                 %****
                 o.startTrial = NaN;
                 o.waitSearch = NaN;
                 o.showFix = 1;
                 %****      
                 o.conEvents = [o.conEvents ; [2, currentTime]];  % value one indicates visible
               end
           case 1,   % holding in fixation
               if (fixdist < o.P.fixRadius) 
                   if ~o.holdfixStart
                       o.holdfixStart = currentTime;
                   end
                   if (currentTime > (o.holdfixStart + o.P.holdFix))
                       o.state = 2; 
                   end
               else
                  o.holdfixStart = 0;
               end
           case 2,        % initial pursuit to establish trial going
              %******** 
              o.holdfixStart = 0;  % make sure this is reset
              o.showFix = 1;
              %******** determine how long in pursuit
              if ~isnan(o.fixStart)
                if ((currentTime-o.fixStart) < o.P.gaborInitTime)
                    FixRad = o.P.fixInitRadius; %sloppy window, 3.5
                end
              end
              %******************
              if (tdist < FixRad) % sum(o.view) > 0)
                if isnan(o.fixStart)
                   if (o.FirstPursuit == 1) || (o.FirstPursuit == 0)
                      o.fixStart = currentTime;
                      o.FirstPursuit = 2;
                   end
                else
                   if ((currentTime-o.fixStart) > o.P.gaborCapture)
                      o.state = 3;
                      if (o.FixJuice)
                         drop = 1;   % drop for looking at fixation
                      end
                      o.FirstPursuit = 0;  % promoted to next state, first pursuit over
                      if (o.startCon == 0)
                        
                        %********* don't allow to many hard trials                       
                        ConCandidate = 2+randi(o.gaborSpatialNum-2);
                        if (ConCandidate > o.P.hardTrialThreshold)
                            o.hardCount = o.hardCount + 1;
                        else
                            o.hardCount = 0;
                        end
                        if (o.hardCount > o.P.maxHardRepeat)
                            ConCandidate = 3;  % easy trial
                            o.hardCount = 0;
                        end
                        %*************
                        o.startCon = ConCandidate;
                        if (o.DotTrial == 0) && (ConCandidate > floor(o.gaborSpatialNum / 2) )
                            o.ExtraJuice = 1;
                        end
                        o.ConTrial = o.startCon;  % one contrst test per trial
                        
                        % Need to mark the time here
                        o.holdtarget = currentTime;  % state 2 to 3 ...
                        
                        o.conEvents = [o.conEvents ; [o.startCon, currentTime]];
                        if (o.P.gaborEvade)
                          %******* face evade or straight path
                          if (o.DotTrial == 0) || (o.DotTrial == 2)
                            if (1) % (rand < (2/3))  % 1/3 same, left, or right    
                              if (rand < 0.50)
                                o.ango(1) = o.ango(1) + (o.P.gaborEvade * (pi/180));
                              else
                                o.ango(1) = o.ango(1) - (o.P.gaborEvade * (pi/180));       
                              end
                            end
                          end
                          %***************
                        end
                      end
                   end
                end
              else   % if not tracking it, then reset new location
                 if ( o.FirstPursuit)  % initial pursuit started, but not finished  
                    o.state = 6;  % stop trial if not engaged
                 else  % if started and lost allow to reacquire   
                    
                    o.fixStart = NaN; % lost track of target, capture needs to be redone
                    o.ExtraJuice = 0;  % no extra juice if lost track 
                    if (currentTime > (o.startSearch + o.P.searchHold))
                      if (1)  %trial will end after wait
                        o.state = 5;  
                        o.waitSearch = o.P.minreappear + rand * o.P.reappearGap;
                        o.startSearch = currentTime;
                        o.startCon = 0;
                        o.conEvents = [o.conEvents ; [o.startCon, currentTime]];
                      end
                    end

                 end            
              end
           case 3,  %pursuing on-line
              %******** 
              o.holdfixStart = 0;  % make sure this is reset
              o.showFix = 1;
              %******** 
              if (tdist < o.P.fixRadius) % tight window on pursuit, %sum(o.view) > 0)
                if ( (currentTime - o.holdtarget) > o.P.gaborHold) 
                     o.state = 4;
                     o.fixStart = NaN;
                     o.rewardStart = currentTime; 
                     drop = 1;

                     o.Faces.position = o.Gabor.position;
                     o.Faces.beforeFrame();

                     if (o.error < 10)
                       o.error = o.error + 1;
                     end
                end
              else  % if you loose the track, what then ... replot or not?
                    % or set a timer for it to expire maybe
                o.state = 2;  %drop target, pick it back up
                o.fixStart = NaN; 
                o.startSearch = currentTime;
                o.ExtraJuice = 0;
                % o.waitSearch = rand * o.P.reappearGap;
              end
           case 4,   % giving reward with face
               % [currentTime-o.rewardStart,o.P.gaborReward]
               if ( (currentTime - o.rewardStart) > o.P.gaborReward)
                  o.state = 5;  % don't restart, go to end state
                  o.fixStart = NaN;
                  o.waitSearch = o.P.minreappear + rand * o.P.reappearGap;
                  o.startSearch = currentTime;
                  o.rewardStart = NaN;
                  o.Faces.imagenum = randi(length(o.Faces.tex));  % pick new face
                  %*******
                  o.startCon = 0;
                  o.conEvents = [o.conEvents ; [o.startCon, currentTime]];
                  if (o.ExtraJuice)
                    drop = 1;  % second drop of juice with face disappear
                  end
                  %*********************************
               end
       end
       
        if (tt < o.gaborPathN)
            o.gaborState(tt,1) = o.state;
            o.gaborState(tt,2) = currentTime;
            o.gaborState(tt,3) = o.Gabor.cpd; 
            o.gaborState(tt,4) = tdist;
            o.gaborState(tt,5) = (tdist < FixRad); %o.view;  % state of eye on targ
            o.Gabor.position = o.S.centerPix + o.S.pixPerDeg * [o.gaborPathX(tt,1),-o.gaborPathY(tt,1)];
            %********* update motion for next step
            o.gaborPathT = o.gaborPathT + 1;
            if (o.state >= 2)   % don't move it when invisible
              o.update_positions();
            end
            %************
        end
        
        % GET THE DISPLAY READY FOR THE NEXT FLIP
        if (o.state > 1)  % gap where nothing is shown
           if (o.state <= 3) %(0) % show the Gabor
             if (o.DotTrial == 0)
               % if o.ExtraJuice
                  o.Gabor.beforeFrame();
               %else
               %    o.hFix.position = o.Gabor.position;
               %    o.hFix.beforeFrame(3);    
               %end
             else
               o.hFix.position = o.Gabor.position;
               if (fixdist < o.P.fixRadius) % sum(o.view) > 0)
                   o.hFix.beforeFrame(1);
               else
                   o.hFix.beforeFrame(3);
               end
             end
           else  % show a face instead if in state 4
               if (o.state < 5)
                 o.Faces.position = o.Gabor.position;
                 o.Faces.beforeFrame();
               end
           end
        else
           if (o.state == 1)  % show fixation to start trial
              if o.holdfixStart
                 o.hFix.beforeFrame(1);  % call to start tracking
              else   % flash fixation on and off
                 o.flashCounter = o.flashCounter + 1;
                 fcount = mod(o.flashCounter,o.P.flashFrameLength);
                 if (fcount == 0)
                     o.showFix = ~o.showFix;
                 end
                 if (o.showFix)
                     o.hFix.beforeFrame(1);
                 end
              end
           end
        end
        %**************************************************************
    end
    
    function Iti = end_run_trial(o)
        Iti = o.Iti;  % returns generic Iti interval (not task dep)
    end
    
    function plot_trace(o,handles)
        %********* append other things eye trace plots if you desire
        h = handles.EyeTrace;
        set(h,'NextPlot','Replace');
        plot(0,0,'k+');
        set(h,'NextPlot','Add');
        %******** Probably would plot entire wiggly trajectory here
        if (1)
          colo = 'k';
          for i = 2:o.gaborPathN
            sta = o.gaborState(i-1,1);
            xx1 = o.gaborPathX(i-1,1);
            yy1 = o.gaborPathY(i-1,1);
            xx2 = o.gaborPathX(i,1);
            yy2 = o.gaborPathY(i,1);
            plot(h,[xx1,xx2],[yy1,yy2],[colo,'-']); % thin dash
          end
        end
    end
    
    function PR = end_plots(o,P,A)   %update D struct if passing back info     
        % Note, not passing in any complex information here
        PR = struct;
        %***** over-ride error sent back to allow nat image viewing
        if (o.error > 0)
            PR.error = 0;  % got trial correct, caught at least one target
        else
            PR.error = 1;
        end
        PR.real_error = o.error;
        PR.gaborPathN = o.gaborPathN;
        PR.gaborPathX = o.gaborPathX;
        PR.gaborPathY = o.gaborPathY;
        PR.gaborState = o.gaborState;  % what state was at that time
        PR.conEvents = o.conEvents;  % history of target contrast in trial
        PR.angoffset = o.angoffset;
        %******** update code for 1/18/24
        PR.gaborSpatialNum = o.gaborSpatialNum; %
        PR.gaborSpatialVals = o.gaborSpatialVals; % contrast values
        PR.DotTrial = o.DotTrial;
        PR.DotSpeed = o.DotSpeed;
        PR.ConTrial = o.ConTrial;
        PR.FixJuice = o.FixJuice;
        PR.ExtraJuice = o.ExtraJuice;
       
        %********** UPDATE ERROR, if Line Cue correct is standard
        err = o.error;
        if err & ~o.ExtraJuice
                err = 2;
        end
        o.D.error = [o.D.error ; err];  % only error 0 in current trials
        o.D.errdist = [o.D.errdist ; o.gaborState(:,4)'];
        
        %%%% Plot results %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Dataplot 1, errors
          errors = [0 1 2 3 4 5 6 7 8 9;
            sum(o.D.error==0) sum(o.D.error==1) sum(o.D.error==2) sum(o.D.error==3) ...
            sum(o.D.error==4) sum(o.D.error==5) sum(o.D.error==6) sum(o.D.error==7) ...
            sum(o.D.error==8) sum(o.D.error==9) ];
          bar(A.DataPlot1,errors(1,:),errors(2,:));
          xlabel(A.DataPlot1,'Drops Given');
          ylabel(A.DataPlot1,'Count');
          set(A.DataPlot1,'XLim',[-.75 10.75]);
          xE = errors(1,:);
          yE = 0.15*max(ylim);
          h = [];
          for ii = 1:size(errors,2),
            axes(A.DataPlot1);
            h(ii) = text(xE(ii),yE,sprintf('%i',errors(2,ii)),'HorizontalAlignment','Center');
                if errors(2,ii) > 2*yE,
                    set(h(ii),'Color','w');
                end
          end
          %****** Plot error over the trial **************************
          hold(A.DataPlot2,'off');
          tt = o.gaborState(:,2)-o.gaborState(1,2);
          plot(A.DataPlot2,tt',o.gaborState(:,4)','k.-');
          T = max(tt);
          set(A.DataPlot2,'XLim',[0 T]);
          set(A.DataPlot2,'YLim',[0 20]);
          xlabel(A.DataPlot2,'Time (s)');
          ylabel(A.DataPlot2,'Distance from Target');
        
          if (isfield(o.D,'errdist') && (size(o.D.errdist,1) > 1) )
            uu = median(o.D.errdist);
            su = std(o.D.errdist)/sqrt(size(o.D.errdist,1));
            tt = (1:o.gaborPathN)/o.S.frameRate;
            %********
            plot(A.DataPlot3,tt,o.D.errdist,'b:',tt,uu,'k-',tt,uu+su,'k-',tt,uu-su,'k-');
            T = max(tt);
            set(A.DataPlot3,'XLim',[0 T]);
            set(A.DataPlot3,'YLim',[0 20]);
            xlabel(A.DataPlot3,'Time (s)');
            ylabel(A.DataPlot3,'Distance from Target');          
          end
    end
    
  end % methods
    
end % classdef
 