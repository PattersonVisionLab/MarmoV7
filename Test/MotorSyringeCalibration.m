

%% Run to initialize controller
% Recommend doing this before cueing up syringe in case controller needs to
% be homed (below) which might drive the syringe

serialNumber = '26250117';  % On the KCube controller
stageName = 'HS ZST213B';
deviceManager = ur.pattersonlab.aoslo.motion.ThorlabsMotorManager();
device = ur.pattersonlab.aoslo.motion.KST201.init(serialNumber, stageName, deviceManager);

%% Home if needed
if ~device.isHomed
    device.home();
end

%% Set up motor syringe class
moveDirection = "down";
stepSize = 0.01; % mm
syringeDiameter = 10;  % mm

obj = marmoview.KinesisMotorSyringe([], device,...
    "MoveDirection", "down",...
    "StepSize", 0.01,...
    "SyringeDiameter", 10);




%% Calibration code
% Run these two lines in command line and change step size until the
% deliver function reliably releases 1 drop.
obj.setStepSize(0.01);
obj.deliver();

% Under 0.001 may become unreliable? Might just switch to smaller syringe
% instead if reaching this lower limit.

%% To reset syringe position
obj.retract();

%% Run to disconnect from controller
obj.disconnect();
% Without this, you may need to restart MATLAB to reestablish connection
% with the controller as the disconnection may not register