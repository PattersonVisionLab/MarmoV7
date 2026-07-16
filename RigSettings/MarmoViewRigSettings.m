function S = MarmoViewRigSettings()
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
% Additional info about trial run and function calls to cmd line
S.verbose = true;

% default, allow GUI updating in run func states
S.TimeSensitive = [];  

% Set to true to work in 8-bit for PsychDefaultSetup(0)
S.use8Bit = false;

if S.verbose
    cprintf('_Comments', 'MarmoViewRigSettings, call\n');
end

%% Rig configuration options
onrig = false;
if onrig
    S.DataPixx = true;
    % string: Kinesis, NewEra, Solenoid, None
    S.rewardType = "None";
    % string: "Trackpixx", "Eyelink", "Arrington", "Mouse"
    S.eyetrackerType = "Trackpixx";
    S.DummyEye = false;         % use mouse instead of eye tracker
    S.DummyScreen = false;      % don't use a Dummy Display
    S.EyeDump = true;           % store all eye position data
else
    S.DataPixx = false;
    S.rewardType = "None";
    S.eyetrackerType = "Mouse";
    S.DummyEye = true;
    S.DummyScreen = true;
    S.EyeDump = false;
end

%% Set reward-specific parameters
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
        S.kinesis_stepSize = 0.2;         % Step to release 1 drop reliably (mm)
end

%% Set eyetracker-specific parameters
% Defaults for TrackPixx. Update once marmoset-specific values are found.
if S.eyetrackerType == "Trackpixx"
    S.trackpixx_expectedIrisSize = 70;     % pixels
    S.trackpixx_species = 1;                % 1 = NHP, 0 = human
    if S.trackpixx_species == 1
        S.trackpixx_ledIntensity = 15;
    else
        S.trackpixx_ledIntensity = 8;
    end
    S.trackpixx_lens = 3;                   % 75 mm
    S.trackpixx_mainEye = "right";          % right = magenta on trackpixx
end

%% Set display-specific parameters
% Override these below if needed.
S.gamma = 2.2;
S.bgColour = 127;
if ~S.use8Bit
    S.bgColour = S.bgColour/255;
end
S.showFrameFlipFigure = false;        % Plot standalone flip figure

if S.DummyScreen
   S.monitor = 'Laptop';              % Monitor for display window
   S.screenNumber = 1;                % Display for task stimuli
   S.frameRate = 60;                  % Frame rate of screen (Hz)
   S.screenRect = [50 50 960 540];    % Screen dimensions in pixels
   S.screenWidth = 15;                % Width of screen (cm)
   S.centerPix =  [...                % Pixels for center of screen
       round((S.screenRect(3)-S.screenRect(1))/2),...
       round((S.screenRect(4)-S.screenRect(2))/2)];

   S.guiLocation = [1000 100 890 660];
   S.screenDistance = 40; %14; %57;    % Distance of eye to screen (cm)

else    % Rig config
   S.monitor = 'ViewPixx-OLED';        % Monitor used for display window
   S.screenNumber = 1;                 % Designates the display for task stimuli
   S.frameRate =  120;                 % Frame rate of screen in Hz
   S.screenRect = [0 0 2560 1440];     % Screen dimensions in pixels
   S.screenWidth = 53;                 % Width of screen (cm)

   S.centerPix =  [...                 % Pixels for center of screen
       round((S.screenRect(3)-S.screenRect(1))/2),...
       round((S.screenRect(4)-S.screenRect(2))/2)];
   S.guiLocation = [800 100 890 660];
   S.screenDistance = 70;              % Distance of eye to screen (cm)
   S.showFrameFlipFigure = true;        % Plot standalone flip figure
end

S.pixPerDeg = PixPerDeg(S.screenDistance, S.screenWidth, S.screenRect(3));

