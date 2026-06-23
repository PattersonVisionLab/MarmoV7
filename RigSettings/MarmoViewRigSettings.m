function S = MarmoViewRigSettings
% For use with MarmoView version 6+  
%
% Revised by JM 8/2018 to consolidate several new features and Dummy Screen
% Revised by SP 6/2026 to integrate trackpixx
%
% This function contains all settings for a particular rig, this way, when
% a change is made to the rig, all settings files do not need to be
% updated.
%
% For example, if you change the monitor set up, you only change those
% monitor related variables here.

%#ok<*UNRCH> 

S = struct();
S.verbose = false;
S.TimeSensitive = [];  % default, allow GUI updating in run func states

if S.verbose
    cprintf('_Comments', 'MarmoViewRigSettings, call\n');
end

% NEW COMMANDS TO INTEGRATE LATER

onrig = true;
if onrig
    S.rewardType = "Kinesis";   % string: Kinesis, NewEra, Solenoid, None
    S.newera = false;           % use Newera juice pump
    S.solenoid = false;         % use solenoid juice delivery
    S.kinesis = true;           % use kinesis stepper motor

    % string: "Trackpixx", "Eyelink", "Arrington", "Mouse"
    S.eyetrackerType = "TrackPixx"; 
    S.arrington = false;        % use Arrington eye tracker
    S.eyelink = false;          % use Eyelink eye tracker
    S.trackpixx = true;         % use TrackPixx eye tracker
    S.DummyEye = false;         % use mouse instead of eye tracker

    S.DummyScreen = false;      % don't use a Dummy Display
    S.EyeDump = true;           % store all eye position data
    S.DataPixx = true;
else
    S.rewardType = "None";
    S.newera = false; 
    S.solenoid = false;
    S.kinesis = false;

    S.eyetrackerType = "Mouse";
    S.arrington = false;
    S.trackpixx = false;     
    S.eyelink = false;
    S.DummyEye = true;

    S.DummyScreen = true;
    S.EyeDump = false;
    S.DataPixx = false;
end
%***************************
switch S.rewardType
    case "NewEra"
        S.pumpCom = 'COM4';       % COM port the New Era syringe pump
        S.pumpDiameter = 20;      % internal diameter of the juice syringe (mm)
        S.pumpRate = 20;          % rate to deliver juice (ml/minute)
        S.pumpDefVol = 0.01;      % default dispensing volume (ml)
    case "Kinesis"
        S.kinesis_serialNumber = '26250117';
        S.kinesis_stageName = "HS ZST213B";
        S.kinesis_syringeDiameter = 10;   % Internal diameter of syringe (mm)
        S.kinesis_moveDirection = "down"; % Direction to move to dispense
        S.kinesis_stepSize = 0.02;        % Step to release 1 drop reliably (mm)
end

% Defaults for TrackPixx. Update once marmoset-specific values are found.
if S.eyetrackerType == "TrackPixx"
    S.trackpixx_expectedIrisSize = 115;     % pixels
    S.trackpixx_species = 1;                % 1 = NHP, 0 = human
    S.trackpixx_ledIntensity = 12;            
    S.trackpixx_lens = 3;                   % 75 mm
    S.trackpixx_mainEye = "right";          % right = magenta on trackpixx
end

if S.DummyScreen

   S.monitor = 'Laptop';                    % Monitor for display window
   S.screenNumber = 1;                      % Display for task stimuli
   S.frameRate = 60;                        % Frame rate of screen (Hz)
   S.screenRect = [0 0 960 540];            % Screen dimensions in pixels
   S.screenWidth = 15;                      % Width of screen (cm)
   S.centerPix = ceil(S.screenRect(3:4)/2); % Pixels of center of screen
   
   S.guiLocation = [1000 100 890 660];
   S.bgColour = 127; % 186 if not gamma corrected

   S.screenDistance = 30; %14; %57;         % Distance of eye to screen (cm)
   S.pixPerDeg = PixPerDeg(S.screenDistance,S.screenWidth,S.screenRect(3));
    
else    
    
   S.monitor = 'ViewPixx-OLED';        % Monitor used for display window
   S.screenNumber = 1;                 % Designates the display for task stimuli
   S.frameRate =  120;                 % Frame rate of screen in Hz
   S.screenRect = [0 0 2560 1440];     % Screen dimensions in pixels
   S.screenWidth = 53;                 % Width of screen (cm)

   S.centerPix =  [...                 % Pixels for center of screen
       round((S.screenRect(3)-S.screenRect(1))/2) + S.screenRect(1),...
       round((S.screenRect(4)-S.screenRect(2))/2) + S.screenRect(2)];
   S.guiLocation = [800 100 890 660];
   S.bgColour = 127;                   % use 127 if gamma corrected, or 186

   S.screenDistance = 57;              % Distance of eye to screen (cm)
   S.pixPerDeg = PixPerDeg(S.screenDistance, S.screenWidth, S.screenRect(3));

end

S.gamma = 2.2;                       
