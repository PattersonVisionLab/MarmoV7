function S = MarmoViewRigSettings
% For use with MarmoView version 3   
%
% Revised by JM 8/2018 to consolidate several new features and Dummy Screen
%
% This function contains all settings for a particular rig, this way, when
% a change is made to the rig, all settings files do not need to be
% updated. This function MUST be located in a directory set in the MATLAB
% path so that it can both be called by MarmoView (in MarmoView directory)
% and by settings functions (in the MarmoView/Settings directory). I
% suggest SupportFunctions.
%
% For example, if you change the monitor set up, you only change those
% monitor related variables here.

%#ok<*UNRCH> 

cprintf('_Comments', 'MarmoViewRigSettings, call\n');

% NEW COMMANDS TO INTEGRATE LATER
S = struct();
S.whichEye = "right";
%warning('NewEra syringe pump temporarily set to false!');

onrig = true;
if (onrig)
    S.newera = false;           % use Newera juice pump
    S.arrington = false;        % use Arrington eye tracker
    S.eyelink = false;          % use Eyelink eye tracker
    S.trackpixx = true;         % use TrackPixx eye tracker
    S.DummyEye = false;         % use mouse instead of eye tracker
    S.solenoid = false;         % use solenoid juice delivery
    S.DummyScreen = false;      % don't use a Dummy Display
    S.EyeDump = true;           % store all eye position data
    S.DataPixx = true;
else
    S.newera = false; 
    S.solenoid = false;
    S.arrington = false;
    S.trackpixx = false;     
    S.eyelink = false;
    S.DummyEye = true;
    S.DummyScreen = true;
    S.EyeDump = false;
    S.DataPixx = false;
end
S.TimeSensitive = [];  % default, allow GUI updating in run func states
%***************************

S.pumpCom = 'COM4';       % COM port the New Era syringe pump
S.pumpDiameter = 20;      % internal diameter of the juice syringe (mm)
S.pumpRate = 20;          % rate to deliver juice (ml/minute)
S.pumpDefVol = 0.01;      % default dispensing volume (ml)

% Defaults for TrackPixx. Update once marmoset-specific values are found.
S.expectedIrisSize = 115;
S.ledIntensity = 8;


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
   S.screenRect = [0 0 1920 1080];     % Screen dimensions in pixels
   S.screenWidth = 53;                 % Width of screen (cm)
   S.centerPix =  ceil(S.screenRect(3:4)/2); % Pixels for center of screen
   S.guiLocation = [800 100 890 660];
   S.bgColour = 127;                   % use 127 if gamma corrected, or 186

   S.screenDistance = 57;              % Distance of eye to screen (cm)
   S.pixPerDeg = PixPerDeg(S.screenDistance, S.screenWidth, S.screenRect(3));

end

% 2.2 single value gamma correction works for BenQ
S.gamma = 2.2;                       
