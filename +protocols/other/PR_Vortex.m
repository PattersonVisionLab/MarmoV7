classdef PR_Vortex < handle
  % Matlab class for running an experimental protocl
  %
  % The class constructor can be called with a range of arguments:
  %
  % Add summary plot, offset for speed, faster speeds, add backimage,
  % change fixation point to a face 
  properties (Access = public)    
       Iti = 1;        % default Iti duration
       startTime = 0;  % trial start time
       fixOn = 0;      % is fixation point on
       fixStart = 0;   % time of fixation start
       pursuitStart = 0; % time to start pursuit
       flashCounter = 0;  % counter to flash fixation
       showFixation = 1;  % show fixation, or not , when flashing
       rewardStart = 0;  % time of reward start
       trialStart = 0;  % time the trial starts
       trialTimer = 0;
  end
      
  properties (Access = private)
    winPtr; % ptb window
    state = 0;      % state counter
    error = 0;      % error state in trial
    wB=1920; %1920      % Width of screen in pixel
    wH=1200; %1080;     % Height of screen in pixel
    frame_rate=60;      % Framerate of the Screen
    %************
    S;      % copy of Settings struct (loaded per trial start)
    P;      % copy of Params struct (loaded per trial)
    %********* stimulus structs for use
    Faces;      % object that stores face images for use
    hFix;              % object for a fixation point
    % Gabor; %object for grating stimulus
    % change gabor to fixation point
    %*********
    fixPathN;  % length of fixation motion for trial (video frames)
    fixPathX;  % X position over N frames
    fixPathY;  % Y position over N frames
    fixPathT;  % T, counter for stepping through N frames
    fixState;  % State during tracking, recorded
    D = struct;
  end
  
  methods (Access = public)
    function o = PR_Vortex(winPtr)
      o.winPtr = winPtr;     
    end
    
    function state = get_state(o)
        state = o.state;
    end
    
    function initFunc(o,S,P)  
        
        o.Faces = stimuli.gaussimages(o.winPtr,'bkgd',S.bgColour,'gray',false);   % color images
        o.Faces.loadimages('./SupportData/MarmosetFaceLibrary.mat');  
        o.Faces.position = [0,0]*S.pixPerDeg + S.centerPix; % at center
        o.Faces.radius = round(P.faceRadius*S.pixPerDeg);
        o.Faces.imagenum = randi(length(o.Faces.tex));  % pick any at random

        % o.Gabor = stimuli.grating(o.winPtr); %init Gabor 
        % find the stimuli that is used for a fixation point and insert it
        % here
        
        %******* create fixation point ****************
        o.hFix = stimuli.fixation_JM(o.winPtr);   % fixation stimulus
        % set fixation point properties
        sz = P.fixPointRadius*S.pixPerDeg;
        o.hFix.cSize = sz;
        o.hFix.sSize = 2*sz;
        P.fixOuterRadius
        o.hFix.oSize = (P.fixOuterRadius*S.pixPerDeg);
        o.hFix.cColour = ones(1,3); % black
        o.hFix.sColour = repmat(255,1,3); % white
        o.hFix.position = [0,0]*S.pixPerDeg + S.centerPix;
        o.hFix.updateTextures();
        %**********************************

    end
   
    function closeFunc(o)
        o.hFix.CloseUp(); % fixation
        %o.Gabor.CloseUp(); % get rid of gabor
        o.Faces.CloseUp();
    end
   
    function generate_trialsList(o,S,P)
           % nothing for this protocol
    end
    
    function P = next_trial(o,S,P);
          %********************
%           o.S = S;
%           o.P = P;       
%           o.fixOn = 0;
%           o.fixStart = 0;
%           o.flashCounter = 0;
%           o.showFixation = 1;
%           o.error = 0;
%           o.trialStart = 0;
%           %*******************
%             % replace o.P.gaborStartRad with fixation point
%           %**** place Gabor and random start location near screen center
%           xx = 0; % o.S.centerPix(1) + (o.P.fixStartRad * randn * o.S.pixPerDeg);
%           yy = 0; % o.S.centerPix(2) + (o.P.fixStartRad * randn * o.S.pixPerDeg);
%           
%           %**** Question: should we implement full random walk for trial
%           %**** trial duration now? If so, let's store it in a long list
%           %**** and use a counter to step through it for display over trial
%           o.fixPathN = floor(o.P.fixPathTime * o.S.frameRate);
%           %o.fixPathN = floor(o.P.trialEnd * o.S.frameRate);
%           o.fixPathX = zeros(o.fixPathN,1);
%           o.fixPathY = zeros(o.fixPathN,1);
%           o.fixState = nan(o.fixPathN,1);
%           o.fixPathT = 1;
%           o.fixPathX(:,1) = xx;  % set to start point for now
%           o.fixPathY(:,1) = yy;
%           %***********
%           o.hFix.position = o.S.centerPix + (o.S.pixPerDeg * [xx,yy]); % will need to use this in a state function in order to get those x, y positions to change 
%           %******* make a linear velocity change path
%           dx_r = (o.P.dotSpeed/o.S.frameRate);   % move to the right
%           dx_l = -(o.P.dotSpeed/o.S.frameRate); % moves to the left
%           % randomize between these two variables for dx
%           % randomly pick a number if 1 means right, if 2 means left,
%           % randsample
%           dx = 0;
%           dy = 0;
%           ango = rand * 2*pi;
%           if dx == 0
%               dx = cos(ango)* (o.P.dotSpeed/o.S.frameRate);
%               dy = sin(ango)* (o.P.dotSpeed/o.S.frameRate);
%               dx1 = -cos(ango);
%               dy1 = -sin(ango);
% 
%           end
%           
%           for tt = 2:o.fixPathN
%              o.fixPathX(tt,1) = xx + dx1; % set to start point for now
%              o.fixPathY(tt,1) = yy + dy1;
%              xx = xx + dx;
%              yy = yy + dy;
%           end
%           
% %           
%           %******* put motion in the point

    wB=1920; %1920      % Width of screen in pixel
    wH=1200; %1080;     % Height of screen in pixel
    frame_rate=60;      % Framerate of the Screen
v_x_10=o.P.velocity*0.0324/frame_rate*wB;
winkel_ges=o.P.angular_velocity/frame_rate*pi/180;

% Initialize Psychtoolbox:

scrnNum = max(Screen('Screens'));
white=WhiteIndex(scrnNum);
Screen('Preference','SkipSyncTests', 1);
[windowPtr, rect]=Screen('OpenWindow',scrnNum, [0 0 0],[],32,2);

try
    % Main loop of demo with ten repetitions
    for wid_demo=1:10

        % Initialization of dots
        D=rand([2 o.P.total_dot_number]);
        D(1,:)=D(1,:)*wB;
        D(2,:)=D(2,:)*wH;

        % Starting position of the vortex ([0,0] is the center of the screen)
        pos_x=-wB*0.375;
        pos_y=0;

        % Loop of every trial; two seconds of movement to the right
        for i=1:2*frame_rate

            % Drawing and displaying of dots
            Screen('DrawDots', windowPtr, D, o.P.dotSizePixels, white, [], 1);
            Screen('Flip', windowPtr);

            % Rotation of dots according to the vortex pattern and shift of the vortex position 
            D=rot(D,pos_x,pos_y,winkel_ges,wB,wH,o.P.vortex_radius);
            pos_x=pos_x+v_x_10;

        end 
    end


    Screen('CloseAll');
    
catch ME
    % Close all screens in case of error
    Screen('CloseAll');
    rethrow(ME);
    
end
%           
%           
    end
    
%     function [FP,TS] = prep_run_trial(o)
%         % Setup the state
%         o.state = 0; % Showing the face
%         Iti = o.P.iti;   % set ITI interval from P struct stored in trial
%         %*******
%         FP(1).states = 0;  % any special plotting of states, 
%         FP(1).col = 'r';   % FP(1).states = 1:2; FP(1).col = 'b';
%                            % would show states 1,2 in blue for eye trace
%         FP(2).states = 1;  % any special plotting of states, 
%         FP(2).col = 'g';   % eye on target
%         FP(3).states = 2;  % on target getting reward 
%         FP(3).col = 'b';   % 
%         FP(4).states = 3;  % on target getting reward 
%         FP(4).col = 'k';   % 
%         %***********
%         
%         %******* set which states are TimeSensitive, if [] then none
%         TS = [0:3];  % if set, eye calib cannot be updated during those states
%         %********
%         o.startTime = GetSecs;
%     end
%     
%     function keepgoing = continue_run_trial(o,screenTime)  % decide to end trial
%         keepgoing = 0;
%         if (o.state <= 5)
%             keepgoing = 1;
%         end
%     end
   % change the gabor path to the fixation path
    %******************** THIS IS THE BIG FUNCTION *************
%     function drop = state_and_screen_update(o,currentTime,x,y) 
%         drop = 0;
%         if (o.trialStart == 0)   % never set before
%             o.trialStart = currentTime;
%         end
%         
%         %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
% %         if o.state == 0 && currentTime > o.startTime + o.P.faceDur
% %             o.state = 1; % Inter trial interval
% %             o.faceOff = GetSecs;
% %             drop = 1; % handles.reward.deliver();
% %         end
% %         
% %         %***** if eye on a face then turn off
% %         F_on = find( o.faceConfig(:,3) == 1);
% %         for i = 1:size(F_on,1)
% %             ii = F_on(i);
% %             %**********
% %             if (norm([(x-o.faceConfig(ii,1)),(y-o.faceConfig(ii,2))]) < o.P.fixRadius )
% %                o.faceConfig(ii,3) = 2;  % turn off face 
% %                %****** set fixation point to this location
% %                o.hFix.position = [o.faceConfig(ii,1),-o.faceConfig(ii,2)]*o.S.pixPerDeg + o.S.centerPix;
% %                o.fixItem = ii;
% %                o.fixOn = 1;
% %                o.fixStart = currentTime;
% %                o.fixList = [o.fixList ; [currentTime,1,o.faceConfig(ii,1),o.faceConfig(ii,2)]];
% %                %********************************
% %             end
% %         end
% %         %****** which faces are on still
% %         F_on = find( o.faceConfig(:,3) == 1);
% %         
% %         %****** implement state logic for fixation point
% %         if (o.fixOn == 1)
% %             if (norm([(x-o.faceConfig(o.fixItem,1)),(y-o.faceConfig(o.fixItem,2))]) < o.P.fixRadius)
% %                 if (currentTime > (o.fixStart + o.P.fixHold) )
% %                     drop = 1;  % give juice, fixation was held
% %                     o.fixOn = 0;  % turn off fixation, but not back on face
% %                     o.fixList = [o.fixList ; [currentTime,2,o.faceConfig(o.fixItem,1),o.faceConfig(o.fixItem,2)]];
% %                 end
% %             else   % fixation was broken
% %                 o.fixOn = 0;
% %                 o.faceConfig(o.fixItem,3) = 1;  % show face, not concluded 
% %                 o.fixList = [o.fixList ; [currentTime,3,o.faceConfig(o.fixItem,1),o.faceConfig(o.fixItem,2)]];
% %             end
% %         end
% %         
% 
%        %******** need to code here state transitions
%        %*** state 0:  not looking at fixation point at all (outside fix radius from
%        %*** state 1:  brief fixation hold before starting motion
%        %*** state 2: looking within fixation radius, time started for reward
%        %***          ... if stop, fall back to state 0 (timer off)
%        %*** state 3: looking longer than time, give reward show fix
%        %***            for some duration and return to state 0, start new
%        % here is where you would code the state function that will change
%        % the position of the fixation point
%        
%        if o.state > 1      
%            if (o.fixPathT < o.fixPathN )
%               tt = o.fixPathT;
%               xx = o.fixPathX(tt);
%               yy = o.fixPathY(tt);
%               o.hFix.position = o.S.centerPix + (o.S.pixPerDeg * [xx,-yy]); % will need to use this in a state function in order to get those x, y positions to change 
%               o.Faces.position = o.S.centerPix + (o.S.pixPerDeg * [xx,-yy]);
%               o.fixPathT = o.fixPathT + 1;
%            end
%        else
%            xx = 0;  % still in fixation state
%            yy = 0;
%        end
%        
%        if o.state == 0 %%%%%% show fixation Point
%            if (currentTime > o.trialStart + o.P.trialDur)
%                o.state = 6;
%                o.error = 1;  % abort trial
%            end
%            o.flashCounter = o.flashCounter + 1;
%            if (mod(o.flashCounter,20) < 10)
%                o.showFixation = 1;
%            else
%                o.showFixation = 0;
%            end
%            %********** if animal fixations the center, then go to state 1
%            %********** and start moving the point
%            fixdist = norm([x,y]);
%            if (fixdist < o.P.fixRadius)
%               o.state = 1;
%               o.fixStart = currentTime;
%            end
%        end 
% 
%        if o.state == 1 %%%%%Fixating 
%            if (currentTime > o.fixStart + o.P.fixHold )  % pursuing target trackDur time
%                o.state = 2; 
%                o.Faces.imagenum = randi(length(o.Faces.tex));
%                o.trialTimer = currentTime;
%                %o.pursuitStart = currentTime;
%                drop = 1; %juice for fixation
%            else
%                fixdist = norm([x,y]);   % distance from fixation
%                if (fixdist > o.P.fixRadius)   % fixation break, or pursuit break
%                    o.state = 6;  % no juice, and trial is over
%                    o.error = 2;  % failed to hold fixation
%                end
%            end
%        end
%         
%        if o.state == 2 %default trial state (NotPursuing)
%            if (currentTime > o.trialTimer + o.P.trialEnd )  % if time elapses
%                o.state = 6;
%                o.error = 3; %never completed pursuit
%            else
%                fixdist = norm([(x-xx),(y-yy)]);   % distance from moving point
%                if (fixdist < o.P.fixRadius)   % actually pursuing
%                    o.state = 3;  % move to pursuit state
%                    o.pursuitStart = currentTime;
%                    drop = 1; %juice for acquisition
%                end
%            end
%        end
%        
%        if o.state == 3 %Pursuing
%            if (currentTime > o.pursuitStart + o.P.pursuitHold )  % pursuing target trackDur time
%                
%                o.state = 4;
%                o.rewardStart = currentTime;
%                drop = 2;
%            else
%                fixdist = norm([(x-xx),(y-yy)]);   % distance from moving point
%                if (fixdist > o.P.fixRadius)   % pursuit break
%                    o.state = 2;  % lost target, move back to default state
%                end
%            end
%        end
% 
%        
%        if o.state == 4 %super pursuit
%            if (currentTime > o.trialTimer + o.P.trialEnd - 0.1)  %o.rewardStart + o.P.rewardDur )  % pursuing target time
%                %o.Faces.position = o.S.centerPix + (o.S.pixPerDeg * [xx,-yy]);
%                drop = 2;
%                o.state = 5;  % go to face reward
%                o.error = 4; %completed super pursuit
%            else
%                fixdist = norm([(x-xx),(y-yy)]);   % distance from moving point
%                if (fixdist > o.P.fixRadius)   % fixation break, or pursuit break
%                    o.state = 6;  % no juice, and trial is over
%                end
%           end
%       end
% 
%         if o.state == 5 %show face stimuli
%            if (currentTime > o.trialTimer + o.P.trialEnd)  %o.rewardStart + o.P.rewardDur )  % pursuing target time
%                o.state = 6;  % end the task
%            else
%           end
%       end
% 
% 
% %        tt = o.fixPathT;
% %        if (tt < o.fixPathN)
% %              o.fixState(tt) = o.state;
% %              o.fixPathT = o.fixPathT + 1;
% %              o.hFix.position = [o.fixPathX(tt),o.fixPathY(tt)];
% %               %o.hFix.position = [o.gaborPathX(tt),o.gaborPathY(tt)];  % move fixation point with Gabor (can swap if he looks)
% %        end
% %         % changes the fixation point position for each trial but not within
%         % the trial 
%         
%         % GET THE DISPLAY READY FOR THE NEXT FLIP
%         % STATE SPECIFIC DRAWS
%         
%         switch o.state
%             case 0           % fixation point shown (eyes not on it)
%                if (o.showFixation == 1) 
%                   o.hFix.beforeFrame(1); %2 %flashing fixation point
%                end
%             case 1
%                o.hFix.beforeFrame(1); %2 % hold on fixation a bit 
%             case 2           % eye acquires gabor, start timer
%                 %o.hFix.beforeFrame(4); %4 is black ring
%                 o.hFix.beforeFrame(3);% 3 is the black dot                
%             case 3           % eye reaches timer, give drop juice show fix
%                %o.hFix.beforeFrame(5);  %5 is white ring
%                %o.hFix.beforeFrame(1); %1 is black dot
%                o.Faces.beforeFrame();
%             case 4
%                o.hFix.beforeFrame(1);
%             case 5
%                o.Faces.beforeFrame();
%             case 6
%         end 
%         
%         %**************************************************************
%     end
    
    function Iti = end_run_trial(o)
        Iti = o.Iti;  % returns generic Iti interval (not task dep)
    end
    
%     function plot_trace(o,handles)
%         %********* append other things eye trace plots if you desire
%         h = handles.EyeTrace;
%         set(h,'NextPlot','Replace');
%         % Fixation window
%         fixX1 = 0;
%         fixX2 = 0;
%         fixY1 = 0; 
%         fixY2 = 0;
%         plot(h,[fixX1,fixX2],[fixY1, fixY2],'--k');
%         set(h,'NextPlot','Add');
%         %******** Probably would plot entire wiggly trajectory here
%         % change plot to plot for the fixation point
%         for i = 2:o.fixPathN
%             sta = o.fixState(i-1);
%             xx1 = o.fixPathX(i-1);
%             yy1 = o.fixPathY(i);
%             xx2 = o.fixPathX(i);
%             yy2 = o.fixPathY(i);
%             
%             if (sta == 0)
%                plot(h,[xx1,xx2],[yy1,yy2],'b-'); % blue
%             end
%             if (sta == 1)
%                     plot(h,[xx1,xx2],[yy1,yy2],'g-'); % green     
%             end
%             if (sta == 2)
%                     plot(h,[xx1,xx2],[yy1,yy2],'r-'); % red           
%             end
%         end            
%     end
    
%     function PR = end_plots(o,P,A)   %update D struct if passing back info     
%         % Note, not passing in any complex information here
%         PR = struct;
%         PR.error = o.error;
%         PR.fixPathN = o.fixPathN;
%         PR.fixPathX = o.fixPathX;
%         PR.fixPathY = o.fixPathY;
%         PR.fixState = o.fixState;  % what state was at that time
%         o.D.error(A.j) = o.error;
%         PR.fixStart = o.fixStart;
%         PR.pursuitStart = o.pursuitStart;
%         PR.rewardStart = o.rewardStart;
%         
% %         if (o.error == 0)  % juice given pursuit complete
% %             o.D.error(A.j) = o.error; %o.error;
% %         elseif (o.error == 1)
% %             o.D.error(A.j) = 1; % abort trial
% %         else
% %             o.D.error(A.j) = 2; % drop pursuit
% %         end
% % %           
%           %**************************
% 
%         errors = [0 1 2 3 4;
%             sum(o.D.error==0) sum(o.D.error==1) sum(o.D.error==2) sum(o.D.error==3) sum(o.D.error==4)];
% %          errors = [0 1 2;
% %             sum(o.D.error==0) sum(o.D.error==1) sum(o.D.error==2)];
%         bar(A.DataPlot1,errors(1,:),errors(2,:));
%         title(A.DataPlot1,'Errors');
%         ylabel(A.DataPlot1,'Count');
%         set(A.DataPlot1,'XLim',[-.75 6.75]);
%         xE = errors(1,:);
%         yE = 0.15*max(ylim);
%         h = [];
%         for ii = 1:size(errors,2),
%           axes(A.DataPlot1);
%           h(ii) = text(xE(ii),yE,sprintf('%i',errors(2,ii)),'HorizontalAlignment','Center');
%           if errors(2,ii) > 2*yE,
%             set(h(ii),'Color','w');
%           end
%         end
%     % end .... this was the problem
%     %A
%     %function PR = end_plots(o,P,A) 
% 
% %     z = find( Exp.D{i}.eyeData(:,5) == 1); 
% %     sta = (Exp.D{i}.eyeData(z(1),6) - Exp.D{i}.eyeData(1,6))*1000; %start time of pursuit
% %     rsta=round(sta,0); %round to nearest whole number
% %     adjEye = horzcat(Exp.D{i}.eyeSmo(rsta:end,1)*1000, Exp.D{i}.eyeSmo(rsta:end,2)); %pull out first 500ms
% %     adjEye(:,1) = adjEye(:,1)-rsta; %adjust to zero start time
% %     plot(A.DataPlot2, adjEye(:,1),adjEye(:,2));  %plot eye trace
% %     %plot((Exp.D{i}.eyeSmo(:,1))*1000, Exp.D{i}.eyeSmo(:,2)) 
%     %plot(Exp.D{i}.eyeSmo(sta:sta+500,1), Exp.D{i}.eyeSmo(sta:sta+500,2)) 
% %     hold on;
%         % h2 = A.DataPlot2;
%         %bar(A.DataPlot2,errors(1,:),errors(2,:));
%         
%         plot(A.DataPlot2, PR.fixPathX, PR.fixPathY); % adjEye(:,1),adjEye(:,2));  %plot eye trace
%         % work on plots 
%         
%        % yline(A.DataPlot2, 1);
%     
% %     xlim([0 500])  
% %     ylabel('X position')
% %     xlabel ('Time')
% %     title ('Eye Position over Time')
% 
%     end
function Dots_new_ausgabe = rot(Dots, pos_x, pos_y, rot_v, wB, wH, vortex_radius)
    % Center the dots around the origin with respect to pos_x and pos_y
    D_cent = Dots;
    D_cent(1, :) = D_cent(1, :) - wB * 0.5 - pos_x;
    D_cent(2, :) = D_cent(2, :) - wH * 0.5 - pos_y;
    
    % Calculate the distance from the origin for each dot
    D_dist = sqrt(D_cent(1, :).^2 + D_cent(2, :).^2);
    
    % Apply the rotation matrix
    cos_rot = cos(rot_v);
    sin_rot = sin(rot_v);
    D_cent_new = D_cent;
    D_cent_new(1, :) = D_cent(1, :) * cos_rot - D_cent(2, :) * sin_rot;
    D_cent_new(2, :) = D_cent(1, :) * sin_rot + D_cent(2, :) * cos_rot;
    
    % Translate the dots back to their original center
    Dots_new = D_cent_new;
    Dots_new(1, :) = Dots_new(1, :) + pos_x + wB * 0.5;
    Dots_new(2, :) = Dots_new(2, :) + pos_y + wH * 0.5;
    
    % Preserve the original coordinates for dots outside the vortex boundary
    outside_mask = D_dist > vortex_radius;
    Dots_new(:, outside_mask) = Dots(:, outside_mask);
    
    % Output the new coordinates
    Dots_new_ausgabe = Dots_new;
end




    
  end % methods
    
end % classdef
