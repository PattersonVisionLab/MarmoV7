function [S,P] = BinaryNoiseOKN()
%%%% NECESSARY VARIABLES FOR GUI
%%%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% LOAD THE RIG SETTINGS, THESE HOLD CRUCIAL VARIABLES SPECIFIC TO THE RIG,
% IF A CHANGE IS MADE TO THE RIG, CHANGE THE RIG SETTINGS FUNCTION IN
% SUPPORT FUNCTIONS
S = MarmoViewRigSettings();

% NOTE THE MARMOVIEW VERSION USED FOR THIS SETTINGS FILE, IF AN ERROR, IT
% MIGHT BE A VERSION PROBLEM
S.MarmoViewVersion = '7';

% PARAMETER DESCRIBING TRIAL NUMBER TO STOP TASK
S.finish = 200;

% PROTOCOL PREFIX
S.protocol = 'BinaryNoiseOKN';
S.protocol_class = ['protocols.PR_',S.protocol];
S.TimeSensitive = 1:7;
% Define Banner text to identify the experimental protocol
S.protocolTitle = 'Binary noise OKN';

%%%%% END OF NECESSARY VARIABLES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%% PARAMETERS -- VARIABLES FOR TASK, CAN CHANGE WHILE RUNNING %%%%%%%%%
% Reward setting
P.rewardNumber = 1; % Max juice, only 1 drop
S.rewardNumber = 'Number of juice pulses to deliver:';
P.CycleBackImage = 10;
S.CycleBackImage = 'If def, backimage every # trials:';
%******* trial timing and reward
P.trialdur = 10;
S.trialdur = 'Trial Duration (s):';
P.rewardGapTime = 2.0;
S.rewardGapTime = 'Drop of juice every number seconds';
P.iti = 0.5;
S.iti = 'Duration of intertrial interval (s):';
if S.use8Bit
    P.bkgd = 127;
else
    P.bkgd = 0.5;
end
S.bkgd = 'Background color (0-1):';

% Gaze indicator
P.eyeRadius = 1.5;
S.eyeRadius = 'Gaze indicator radius (degrees):';
P.eyeIntensity = 5;
S.eyeIntensity = 'Indicator intensity:';
P.showEye = 0;
S.showEye = 'Show the gaze indicator? (0 or 1):';
%***** stimulus field extent (Inf = full field) *****
P.noiseradius = Inf;
S.noiseradius = 'Stimulus radius (dva); use Inf for full field:';
%***** noise texture parameters *****
P.noiseSquareDeg = 2.5;
S.noiseSquareDeg = 'Binary noise element size (dva):';
P.contrastLevel = 96/255; % = 0.376, matches grating script's noiserange = 48/255 (bkgd +/- 48/255 in normalized units)
S.contrastLevel = 'Contrast (0-1, 1 = full black/white):';
%***** speed parameterization *******
P.speedVeryLow = 1; % deg/s
S.speedVeryLow = 'Very low speed condition (deg/s)';
P.speedLow = 10;   % deg/s
S.speedLow = 'Low speed condition (deg/s):';
P.speedHigh = 40;  % deg/s
S.speedHigh = 'High speed condition (deg/s):';