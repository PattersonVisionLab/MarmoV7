function [S,P] = SpatialMotionOKN()

%%%% NECESSARY VARIABLES FOR GUI
%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% LOAD THE RIG SETTINGS, THESE HOLD CRUCIAL VARIABLES SPECIFIC TO THE RIG,
% IF A CHANGE IS MADE TO THE RIG, CHANGE THE RIG SETTINGS FUNCTION IN
% SUPPORT FUNCTIONS
S = MarmoViewRigSettings();

% NOTE THE MARMOVIEW VERSION USED FOR THIS SETTINGS FILE, IF AN ERROR, IT
% MIGHT BE A VERSION PROBLEM
S.MarmoViewVersion = '7';  % Upgrade from 5

% PARAMETER DESCRIBING TRIAL NUMBER TO STOP TASK
S.finish = 200;

% PROTOCOL PREFIX
S.protocol = 'SpatialMotionOKN';
% PROTOCOL PREFIXS
S.protocol_class = ['protocols.PR_',S.protocol];


%NOTE: in MarmoView2 subject is entered in GUI

%******** Don't allow in trial calibration for this one (comment out)
% P.InTrialCalib = 1;
% S.InTrialCalib = 'Eye Calib in Trials';
S.TimeSensitive = 1:7;

% STORE EYE POSITION DATA
% S.EyeDump = false;

% Define Banner text to identify the experimental protocol
% recommend maximum of ~28 characters
S.protocolTitle = 'Horizontal OKN';

%%%%% END OF NECESSARY VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% PARAMETERS -- VARIABLES FOR TASK, CAN CHANGE WHILE RUNNING %%%%%%%%%
% INCLUDES STIMULUS PARAMETERS, DURATIONS, FLAGS FOR TASK OPTIONS
% MUST BE SINGLE VALUE, NUMERIC -- NO STRINGS OR ARRAYS!
% THEY ALSO MUST INCLUDE DESCRIPTION OF THE VALUE IN THE SETTINGS ARRAY

% Reward setting
P.rewardNumber = 1;   % Max juice, only one drop ... it is so easy!
S.rewardNumber = 'Number of juice pulses to deliver:';
P.CycleBackImage = 10;
S.CycleBackImage = 'If def, backimage every # trials:';

%******* trial timing and reward
P.trialdur = 5;
S.trialdur = 'Trial Duration (s):';
P.rewardGapTime = 2.0;
S.rewardGapTime = 'Drop of juice every number seconds';

P.iti = 0.5;
S.iti = 'Duration of intertrial interval (s):';
P.bkgd = 127;
if ~S.use8Bit
    P.bkgd = P.bkgd/255;
end
S.bkgd = 'Choose a grating background color (0-1/0-255):';
P.noiserange = 48;
if ~S.use8Bit
    P.noiserange = P.noiserange/255;
end
S.noiserange = 'Luminance range of grating (0-0.5/0-127):';

% Gaze indicator
P.eyeRadius = 1;
S.eyeRadius = 'Gaze indicator radius (degrees):';
P.eyeIntensity = 20;
if ~S.use8Bit
    P.eyeIntensity = P.eyeIntensity/255;
end
S.eyeIntensity = 'Indicator intensity:';
P.showEye = 0;
S.showEye = 'Show the gaze indicator? (0 or 1):';

P.noisewidth = 25.0;  % radius of noise field around origin
S.noisewidth = 'Spatial noise width (degs, +/- origin):';
P.noiseheight = 15.0;  % radius of noise field around origin
S.noiseheight = 'Spatial noise height (degs, +/- origin):';

%***************
% number of frames for one cycle (120hz, if 120 => 1hz)
P.gratingcycle = S.frameRate;
S.gratingcycle = 'Set the temporal freq of grating drift';
P.spf = 0.2;  % spatial frequency
S.spf = 'Spat freq (cyc/deg):';
P.ori = 0;  % orientation of drifting grating (0 for horizonal, will do
            % both directions, forward phase shift and back
S.ori = 'Orientation of grating';
%***** Linear spaced speeds from base speed
% Base speed = (temp freq / spat freq) = (1hz/0.2) = 5 deg/sec
%*** Run speeds in Log2 increases: 5,10,20,40,80 (5 of them)
%****  and if more, then change base spf for faster or slower
P.speednum = 5;
S.speednum = 'Number of speeds, log 2 scale from base speed';
%********* parameters for noise stimulus following gaze
P.noiseradius = 50; %4.0;  % diameter of target is dva
S.noiseradius = 'Size of Face(dva):';
P.squareWave = 1;
S.squareWave = 'Use square wave in grating';
P.dutyCycle = 0.5;
S.dutyCycle = 'Light:dark ratio (0-1):';

%********* stimulus type: drifting grating vs moving 2D binary noise
P.stimType = 0;
S.stimType = 'Stimulus: 0=grating, 1=2D noise:';
P.noiseSquareSize = 0.2;
S.noiseSquareSize = 'Size of binary noise squares (dva):';
P.noiseSeed = 0;
S.noiseSeed = 'Seed for noise generator (0=pick random):';

