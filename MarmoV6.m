function varargout = MarmoV6(varargin)
% MARMOV6 M-file for MarmoV6.fig
% Patterson lab trackpixx version (to be MarmoV7 at some point)
%
%      THIS IS MARMOV6 VERSION 1C, THIS CORRESPONDS TO THE VERSION TEXT
%      IN THE MarmoV6.fig FILE
%
%      MARMOV6, by itself, creates a new MARMOV6 or raises the existing
%      singleton*.
%
%      H = MARMOV6 returns the handle to a new MARMOV6 or the handle to
%      the existing singleton*.
%
%      MARMOV6('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in MARMOV6.M with the given input arguments.
%
%      MARMOV6('Property','Value',...) creates a new MARMOV6 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before MarmoV6_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to MarmoV6_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Last Modified by GUIDE v2.5 19-Aug-2024 16:32:28

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
        'gui_Singleton',  gui_Singleton, ...
        'gui_OpeningFcn', @MarmoV6_OpeningFcn, ...
        'gui_OutputFcn',  @MarmoV6_OutputFcn, ...
        'gui_LayoutFcn',  [] , ...
        'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end

    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT


% --- Executes just before MarmoV6 is made visible.
function MarmoV6_OpeningFcn(hObject, eventdata, handles, varargin)
    % This function has no output args, see OutputFcn.

    % Choose default command line output for MarmoV6
    handles.output = hObject;

    %%%%% IMPORTANT GROUNDWORK FOR THE GUI IS PLACED HERE %%%%%%%%%%%%%%%%%%%%%

    % GET SOME CRUCIAL DIRECTORIES -- THESE DIRECTORIES MUST EXIST!!
    marmoDir = getMarmoViewPath();
    % Present working directory, location of all GUIs
    handles.taskPath = sprintf('%s/',marmoDir);
    % Settings directory, settings files should be kept here
    handles.settingsPath = sprintf('%s/Settings/',marmoDir);
    % Output directory, all data will be saved here!
    handles.outputPath = sprintf('%s/Output/',marmoDir);
    % Support data directory, data to support MarmoV6 or its protocols can be
    % kept here unintrusively (e.g. eye calibration values or marmoset images)
    handles.supportPath = sprintf('%s/SupportData/',marmoDir);
    %****** start with no settings file
    handles.settingsFile = 'none';
    set(handles.SettingsFile, 'String', handles.settingsFile);

    % AS DEFAULT, THE GUI WILL USE THE CALIBRATION SETTINGS AT THE END OF THE
    % LAST GUI RUN, THIS GUI SUPPORT DATA IS IN THE 'SUPPORT DATA' DIRECTORY,
    % A different calibration file can be loaded, if specified as a field in
    % the settings structure, but any changes made will only be saved to the
    % default 'MarmoViewLastCalib.mat' -- I suspect this won't be used, but
    % could be if two subjects had substantially different eye position gains
    handles.calibFile = 'MarmoViewLastCalib.mat';
    set(handles.RotationAngle, 'String', handles.calibFile);
    calStruct = load([handles.supportPath handles.calibFile]);
    if ~isfield(calStruct, 'rot')
        calStruct.rot = 0;
    end
    handles.C = calStruct;
    handles.eyeTraceRadius = 15;
    % This C structure is never changed until a protocol is cleared or
    % MarmoV6 is exited, until then, it may be reset to the C values using
    % the ResetCalib callback.

    % CREATE THE STRUCTURES USED BY ALL PROTOCOLS
    handles.A = struct(); % Values necessary for protocols to run current trial
    handles.S = struct(); % Settings for the protocol, NOT changed while running
    handles.P = struct(); % Parameters for the current protocol, changeable
    handles.SI = handles.S;
    handles.PI = struct;

    %****** AT SOME POINT THIS TASK CONTROL MAY INCLUDE EPHYS TIMING WRAPPER
    handles.FC = marmoview.FrameControl();   % create generic task control

    % ** LOAD RIG SETTINGS (RELOADED FOR EACH PROTOCOL)
    handles.outputSubject = 'none';
    S = MarmoViewRigSettings();
    S.subject = handles.outputSubject;
    handles.S = S;

    %****** if a DummyEye, use mouse and change coordinates
    %****** so the eye is estimated to be where the mouse is located
    if handles.S.DummyEye
        handles.calibFile = 'Using Mouse as Eye';
        set(handles.RotationAngle, 'String', handles.calibFile);
        cx = round((S.screenRect(3)-S.screenRect(1))/2) + S.screenRect(1);
        cy = round((S.screenRect(4)-S.screenRect(2))/2) + S.screenRect(2);
        % Stay in pixel coordinates, don't scale, invert y
        handles.C.dx = 1;
        handles.C.dy = -1; % invert y
        handles.C.c = [cx cy];
        handles.C.rot = 0;
    end

    %********** if using the DataPixx, initialize it here
    if (handles.S.DataPixx)
        datapixx.init();
    end

    % Load calibration variables into the A structure to be changed if needed
    handles.A = handles.C;
    % Add in the plot handles to A in case handles isn't available
    % e.g. while running protocols)
    handles.A.EyeTrace = handles.EyeTrace;
    handles.A.DataPlot1 = handles.DataPlot1;
    handles.A.DataPlot2 = handles.DataPlot2;
    handles.A.DataPlot3 = handles.DataPlot3;
    handles.A.DataPlot4 = handles.DataPlot4;
    handles.A.outputFile = 'none';

    % OPEN UP COMMUNICATION WITH THE PUMP FOR REWARD DELIVERY -- THIS IS DONE
    % IMMEDIATELY USING THE RIG SETTINGS, SO THAT JUICE IS AVAILABLE TO THE
    % MARMOSET WHILE NO PROTOCOLS ARE LOADED
    switch handles.S.rewardType
        case "Kinesis"
            deviceManager = ur.pattersonlab.aoslo.motion.ThorlabsMotorManager();
            device = ur.pattersonlab.aoslo.motion.KST201.init(...
                S.kinesis_serialNumber, S.kinesis_stageName, deviceManager);
            handles.reward = marmoview.KinesisMotorSyringe([], device,...
                "MoveDirection", S.kinesis_moveDirection,...
                "StepSize", S.kinesis_stepSize,...
                "SyringeDiameter", S.kinesis_syringeDiameter);
            assignin('base', 'kinesisDevice', handles.reward);
        case "NewEra"
            handles.reward = marmoview.newera(hObject,...
                'port', S.pumpCom,...
                'diameter', S.pumpDiameter,...
                'volume', S.pumpDefVol,...
                'rate', S.pumpRate);
        case "Solenoid"
            handles.reward = marmoview.SolenoidControl(S.pumpCom);
            S.pumpDefVol = handles.reward.volume;
            vol = sprintf('%d', S.pumpDefVol * 1e3);
            set(handles.JuiceVolumeText, 'String', [vol ' ms']); % displayed in microliters!!
        otherwise
            handles.reward = marmoview.dbgreward(hObject);
    end
    % % TYPICALLY, I PREFER TO HANDLES LARGER/SMALLER REWARDS BY NUMBER OF PULSES
    % INSTEAD OF CHANGING THE VOLUME, ALTHOUGH THE VOLUME CAN BE CHANGED, I
    % SUGGEST ONLY USING A NUMBER OF JUICE PULSE PARAMETER FOR PROTOCOLS.
    % !!!IF YOU DO CHANGE JUICE VOLUME, MAKE SURE THE PUMP IS GIVEN TIME TO
    % DELIVER EACH PULSE BEFORE STARTING ON THE NEXT ONE, IT TAKES LONGER TO
    % DELIVER A BIG JUICE PULSE THAN A SMALL ONE!!!
    handles.A.juiceVolume = handles.reward.volume; %S.pumpDefVol;
    % Also start a juice counter, for now at 0 -- It will be reset upon loading
    % a new protocol and between trials. But it's changed with the give juice
    % button, so best to assign it now
    handles.A.juiceCounter = 0;

    % *** Initialize the eye tracker
    switch handles.S.eyetrackerType
        case "Arrington"
            handles.eyetrack = marmoview.eyetrack_arrington(hObject,'EyeDump',S.EyeDump);
        case "TrackPixx"
            handles.eyetrack = marmoview.eyetrack_trackpixx(hObject,...
                'LedIntensity', S.trackpixx_ledIntensity,...
                'ExpectedIrisSize', S.trackpixx_expectedIrisSize,...
                'EyeDump',S.EyeDump);
        otherwise % no eyetrack, use @eyetrack object instead that uses mouse pointer
            handles.eyetrack = marmoview.eyetrack();
    end


    %********* add the task controller for storing eye movements, flipping
    %********* frames
    % WRITE THE CALIBRATION DATA INTO THE EYE TRACKER PANEL AND GET THE SIZES
    % OF GAIN AND SHIFT CONTROLS FOR CALIBRATING EYE POSITION FOR UPDATE EYE
    % TEXT TO RUN PROPERLY, CALBIRATION MUST ALREADY BE IN STRUCTURE 'A'
    handles.A
    UpdateEyeText(handles);
    handles.shiftSize = str2double(get(handles.ShiftSize, 'String'));
    handles.gainSize = str2double(get(handles.GainSize, 'String'));

    % THESE VARIABLES CONTROL THE RUN LOOP
    handles.runTask = false;
    handles.stopTask = false;
    % These variables control interleaved background images
    handles.runOneTrial = false;
    handles.runImage = false;
    handles.lastRunWasImage = false;

    % SET ACCESS TO GUI CONTROLS
    set([handles.RunTrial, handles.FlipFrame, handles.ClearSettings], "Enable", "off");
    set([handles.Initialize, handles.PauseTrial], 'Enable','Off');
    set([handles.Background_Image, handles.Calib_Screen], 'Enable', 'on');
    set([handles.ParameterPanel, handles.EyeTrackerPanel,...
        handles.SettingsPanel, handles.TaskPerformancePanel], "Visible", "off");

    % Force to select subject name first thing
    set(handles.StatusText, 'String', 'Please select SUBJECT to begin');
    set(handles.OutputSubjectEdit, 'String', 'none');
    handles.outputSubject = 'none';
    handles.outputPrefix = [];
    handles.outputDateEdit = [];
    handles.outputSuffixEdit = [];
    set([handles.OutputPrefixEdit, handles.OutputDateEdit, handles.OutputSuffixEdit],...
        "Enable", "off");

    % For the protocol title, note that no protocol has been loaded yet
    set(handles.ProtocolTitle, 'String', 'No protocol is loaded.');
    % The task light is a neutral gray when no protocol is loaded
    ChangeLight(handles.TaskLight,[.5 .5 .5]);
    UpdateEyeText(handles);

    % Update handles structure
    guidata(hObject, handles);

% --- Outputs from this function are returned to the command line.
function varargout = MarmoV6_OutputFcn(hObject, eventdata, handles)  %#ok<*INUSL>
    % varargout  cell array for returning output args (see VARARGOUT);
    % hObject    handle to figure
    % eventdata  reserved - to be defined in a future version of MATLAB
    % handles    structure with handles and user data (see GUIDATA)

    % Get default command line output from handles structure
    varargout{1} = handles.output;


%% Callbacks: Settings
% CHOOSE A SETTINGS FILE
function ChooseSettings_Callback(hObject, eventdata, handles) %#ok<*DEFNU>
    cprintf('_[0.5,0.1,0.6]', '\tMV6, callback ChooseSettings\n');
    % Go into the settings path
    cd(handles.settingsPath);
    % Have user select the file
    handles.settingsFile = uigetfile;
    % Show the selected outputfile
    if handles.settingsFile ~= 0
        set(handles.SettingsFile,'String',handles.settingsFile);
    else
        % Or no outputfile if cancelled selection
        set(handles.SettingsFile,'String','none');
        handles.settingsFile = 'none';
    end
    % If file exists, then we can get the protocol initialized
    if exist(handles.settingsFile,'file')
        if (strcmp(handles.outputSubject,'none'))
            set(handles.Initialize, 'Enable', 'off');
            tstring = 'Please select SUBJECT NAME >>>';
        else
            set(handles.Initialize, 'Enable', 'on');
            tstring = 'Ready to initialize protocol...';
        end
    else
        set(handles.Initialize,'Enable','off');
        tstring = 'Please select a settings file...';
    end
    % Regardless, update status
    set(handles.StatusText,'String',tstring);
    % Return to task directory
    cd(handles.taskPath);

    % Update handles structure
    guidata(hObject, handles);


% INITIALIZE A PROTOCOL FROM THE SETTINGS SELECTED
function Initialize_Callback(hObject, eventdata, handles)
    cprintf('_[0.5,0.1,0.6]', '\tMV6, callback Initialize\n');
    % PREPARE THE GUI FOR INITIALIZING THE PROTOCOL

    % Update GUI status
    set(handles.StatusText,'String','Initializing...');
    % The task light is blue only during protocol initialization
    ChangeLight(handles.TaskLight, [.2 .2 1]);

    % TURN OFF BUTTONS TO PREVENT FIDDLING DURING INITIALIZATION
    set(handles.ChooseSettings,'Enable','Off');
    set(handles.Initialize,'Enable','Off');
    set(handles.OutputSubjectEdit,'Enable','Off'); % subject already set
    % Effect these changes on the GUI immediately
    guidata(hObject, handles); drawnow;

    % GET PROTOCOL SETTINGS
    cd(handles.settingsPath);
    cmd = sprintf('[handles.S,handles.P] = %s;',handles.settingsFile(1:end-2));
    eval(cmd);
    handles.S.subject = handles.outputSubject;
    cd(handles.taskPath);

    % MOVE THE GUI OFF OF THE VISUAL STIMULUS SCREEN TO THE CONSOLE SCREEN
    % THIS IS CHANGED IN PROTOCOL SETTINGS AND IS NOT A NECESSARY SETTING
    if isfield(handles.S,'guiLocation')
        set(handles.figure1,'Position',handles.S.guiLocation);
    end

    % SHOW THE PROTOCOL TITLE
    set(handles.ProtocolTitle,'String',handles.S.protocolTitle);

    % OPEN THE PBT SCREEN
    handles.A = marmoview.openScreen(handles.S, handles.A);

    % INITIALIZE THE PROTOCOL
    cmd = sprintf('handles.PR = %s(handles.A.window);',handles.S.protocol_class);
    eval(cmd);   %Establishes the PR object
    %***************
    % GENERATE DEFAULT TRIALS LIST
    handles.PR.generate_trialsList(handles.S, handles.P);
    %*****************
    handles.PR.initFunc(handles.S, handles.P);
    %***************

    % ALSO GENERATE A BACKGROUND IMAGE VIEWER PROTOCOL
    %********* Setup Image Viewer Protocol ******************
    cd(handles.settingsPath);
    [handles.SI, handles.PI] = BackImage;
    cd(handles.taskPath);
    % INITIALIZE THE Back Image Protocl
    handles.PRI = protocols.PR_BackImage(handles.A.window);
    handles.PRI.generate_trialsList(handles.SI, handles.PI);
    handles.PRI.initFunc(handles.SI, handles.PI);
    %***************

    %*****************************************

    % INITIALIZE THE TASK CONTROLLER FOR THE TRIAL
    handles.FC.initialize(handles.A.window, handles.P, handles.C, handles.S);

    % SET UP THE OUTPUT PANEL
    % Get the output file name components
    handles.outputPrefix = handles.S.protocol;
    set(handles.OutputPrefixEdit, 'String', handles.outputPrefix);
    set(handles.OutputSubjectEdit, 'String', handles.outputSubject);
    handles.outputDate = datestr(now,'ddmmyy');
    set(handles.OutputDateEdit,'String',handles.outputDate);
    i = 0; handles.outputSuffix = '00';
    % Generate the file name
    handles.A.outputFile = strcat(handles.outputPrefix,'_',handles.outputSubject,...
        '_',handles.outputDate,'_',handles.outputSuffix,'.mat');
    % If the file name already exists, iterate the suffix to a nonexistant file
    while exist([handles.outputPath handles.A.outputFile],'file')
        i = i+1; handles.outputSuffix = num2str(i,'%.2d');
        handles.A.outputFile = strcat(handles.outputPrefix,'_',handles.outputSubject,...
            '_',handles.outputDate,'_',handles.outputSuffix,'.mat');
    end

    handles.eyetrack.startfile(handles);

    % Show the file name on the GUI
    set(handles.OutputSuffixEdit, 'String', handles.outputSuffix);
    set(handles.OutputFile, 'String', handles.A.outputFile);
    % Note that a new output file is being used
    handles.A.newOutput = 1;

    % SET UP THE PARAMETERS PANEL
    % Trial counting section of the parameters
    handles.A.j = 1; handles.A.finish = handles.S.finish;
    set(handles.TrialCountText,'String',['Trial ' num2str(handles.A.j-1)]);
    set(handles.TrialMaxText,'String',num2str(handles.A.finish));
    set(handles.TrialMaxEdit,'String','');

    % pNames are the actual parameter names
    handles.pNames = fieldnames(handles.P);
    % pList is the list of parameter names with values
    handles.pList = cell(size(handles.pNames,1),1);
    updateParameterDisplay(handles);

    % For the highlighted parameter, provide a description and editable value
    set(handles.Parameters, 'Value', 1);
    set(handles.ParameterText, 'String', handles.S.(handles.pNames{1}));
    set(handles.ParameterEdit, 'String', num2str(handles.P.(handles.pNames{1})));

    % UPDATE ACCESS TO CONTROLS
    set([handles.RunTrial, handles.FlipFrame, handles.ClearSettings], "Enable", "on");
    set([handles.OutputPanel, handles.ParameterPanel, handles.EyeTrackerPanel,...
        handles.TaskPerformancePanel], "Visible", "on");
    EnableOutputFileNaming(handles, 'off');
    set([handles.Background_Image, handles.Calib_Screen], 'Enable', 'on');
    set([handles.GraphZoomIn, handles.GraphZoomOut], 'Enable', 'on');

    %*******Blank the eyetrace plot
    h = handles.EyeTrace;
    eyeRad = handles.eyeTraceRadius;
    set(h,'NextPlot','Replace');
    plot(h,0,0,'+k','LineWidth',2);
    set(h,'NextPlot','Add');
    plot(h,[-eyeRad eyeRad],[0 0],'--','Color',[.5 .5 .5]);
    plot(h,[0 0],[-eyeRad eyeRad],'--','Color',[.5 .5 .5]);
    axis(h,[-eyeRad eyeRad -eyeRad eyeRad]);
    %*************************

    if handles.S.DummyEye
        EnableEyeCalibration(handles, 'Off');
        set([handles.GraphZoomIn, handles.GraphZoomOut], 'Enable', 'on');
    end

    % UPDATE GUI STATUS
    set(handles.StatusText, 'String', 'Protocol is ready to run trials.');
    % Now that a protocol is loaded (but not running), task light is red
    ChangeLight(handles.TaskLight,[1 0 0]);

    % FINALLY, RESET THE JUICE COUNTER WHENEVER A NEW PROTOCOL IS LOADED
    handles.A.juiceCounter = 0;

    % UPDATE HANDLES STRUCTURE
    guidata(hObject, handles);
    % ---------------------------------------------------------------------


% UNLOAD CURRENT PROTOCOL, RESET GUI TO INITIAL STATE
function ClearSettings_Callback(hObject, eventdata, handles)
    cprintf('_[0.5,0.1,0.6]', '\tMV6, callback ClearSettings\n');

    % DISABLE RUNNING THINGS WHILE CLEARING
    set([handles.RunTrial, handles.FlipFrame, handles.ClearSettings,...
        handles.Background_Image, handles.Calib_Screen], "Enable", "off");
    set([handles.OutputPanel, handles.ParameterPanel, handles.EyeTrackerPanel,...
        handles.TaskPerformancePanel], "Visible", "off");

    % Clear plots
    plot(handles.DataPlot1, 0,0, '+k');
    plot(handles.DataPlot2, 0,0, '+k');
    plot(handles.DataPlot3, 0,0, '+k');
    plot(handles.DataPlot4, 0,0, '+k');

    % Eye trace needs to be treated differently to maintain important properties
    plot(handles.EyeTrace, 0, 0, '+k');
    set(handles.EyeTrace, 'UserData', 15); % 15 degrees of visual arc is default
    handles.eyetrack.closefile();

    % DE-INITIALIZE PROTOCOL (remove screens or objects created on init)
    handles.PR.closeFunc();  % de-initialize any objects
    handles.PRI.closeFunc(); % close the back-ground image protocol
    handles.lastRunWasImage = false;

    % REFORMAT DATA FILES TO CONDENSED STRUCT
    CondenseAppendedData(hObject, handles)

    % Close all screens from ptb
    sca;

    % Save the eye calibration values at closing time to the MarmoViewLastCalib
    c = handles.A.c; 
    dx = handles.A.dx; 
    dy = handles.A.dy; 
    rot = handles.A.rot;
    if ~handles.S.DummyEye
        save([handles.supportPath 'MarmoViewLastCalib.mat'], 'c', 'dx', 'dy', 'rot');
    end

    handles.C.c = c; handles.C.dx = dx; handles.C.dy = dy; handles.C.rot = rot;

    % Create a structure for A that maintains only basic values required
    % outside the protocol
    A = handles.C;
    A.EyeTrace = handles.EyeTrace;
    A.DataPlot1 = handles.DataPlot1;
    A.DataPlot2 = handles.DataPlot2;
    A.DataPlot3 = handles.DataPlot3;
    A.DataPlot4 = handles.DataPlot4;
    A.outputFile = 'none';

    % Reset structures
    handles.A = A;
    handles.S = MarmoViewRigSettings();
    handles.S.subject = handles.outputSubject;
    handles.P = struct();
    handles.SI = handles.S;
    handles.PI = struct();
    % If juicer delivery volume was changed during the previous protocol,
    % return it to default. Also add the juice counter for the juice button.
    handles.A.juiceVolume = handles.reward.volume;
    handles.A.juiceCounter = 0;

    if handles.S.rewardType == "Solenoid"
        set(handles.JuiceVolumeText,...
            'String', sprintf('%3i ms',handles.A.juiceVolume*1e3));
    else
        set(handles.JuiceVolumeText,...
            'String', sprintf('%3i ul',handles.A.juiceVolume * 1e3));
    end

    % RE-ENABLE CONTROLS
    set(handles.ChooseSettings,'Enable','On');
    % Initialize is only available if the settings file exists
    handles.settingsFile = get(handles.SettingsFile, 'String');
    if ~exist(fullfile(handles.settingsPath, handles.settingsFile), 'file')
        set(handles.Initialize, 'Enable', 'off');
        tstring = 'Please select a settings file...';
    else
        set(handles.Initialize, 'Enable', 'on');
        tstring = 'Ready to initialize protocol...';
    end
    % Update GUI status
    set(handles.StatusText, 'String', tstring);
    % For the protocol title, note that no protocol is now loaded
    set(handles.ProtocolTitle, 'String', 'No protocol is loaded.');
    % The task light is a neutral gray when no protocol is loaded
    ChangeLight(handles.TaskLight, [.5 .5 .5]);

    % RE-ENABLE THE SUBJECT ENTRY, in case want to change subject and continue the
    % program without closing MarmoV6 (should be rare)
    set(handles.OutputPanel, 'Visible', 'On');
    EnableOutputFileNaming(handles, 'off');
    set(handles.OutputSubjectEdit, 'Enable', 'On');

    % Update handles structure
    guidata(hObject, handles);


%% Callbacks: Main loop
function RunTrial_Callback(hObject, eventdata, handles)

    if handles.S.verbose
        cprintf('_[0.5,0.1,0.6]', '\tMV6, callback RunTrial\n');
    end

    % SET THE TASK TO RUN
    handles.runTask = true;

    if ~handles.runImage
        handles.lastRunWasImage = false;
    else
        handles.lastRunWasImage = true;
    end
    %****************************

    % Update UI to reflect task status
    ChangeLight(handles.TaskLight, [0 1 0]);
    EnableOutputFileNaming(handles, 'off');
    set([handles.RunTrial, handles.FlipFrame, handles.Background_Image,...
        handles.Calib_Screen, handles.CloseGui, handles.ClearSettings],...
        'Enable', 'Off');
    set([handles.Parameters, handles.TrialMaxEdit, handles.JuiceVolumeEdit,...
        handles.ChooseSettings, handles.Initialize, handles.ParameterEdit],...
        'Enable','Off');
    if ( isfield(handles.P,'InTrialCalib') && (handles.P.InTrialCalib == 1) && ...
            ~handles.S.DummyEye)
        % Dont allow calibration if dummy screen (use mouse)
        if ~handles.S.DummyEye
            EnableEyeCalibration(handles,'On');
        else
            EnableEyeCalibration(handles,'Off');
            set([handles.GraphZoomIn, handles.GraphZoomOut],'Enable','On');
        end
        UpdateEyeText(handles);
    else
        EnableEyeCalibration(handles, 'Off');
        UpdateEyeText(handles);
    end
    set(handles.PauseTrial, 'Enable', 'On');


    handles.eyetrack.unpause();

    %********************************

    % UPDATE GUI STATUS
    set(handles.StatusText, 'String', 'Protocol trials are running.');

    % RESET THE JUICER COUNTER BEFORE ENTERING THE RUN LOOP
    handles.A.juiceCounter = 0;
    % UPDATE THE HANDLES
    guidata(hObject, handles); drawnow;

    % MOVE TASK RELATED STRUCTURES OUT OF HANDLES FOR THE RUN LOOP -- this way
    % if a callback interrupts the run task function, we can update any changes
    % the interrupting callback makes to handles without affecting those task
    % related structures. E.g. we can run the task using parameters as they
    % were at the start of the trial, while getting ready to cue any changes
    % the user made on the next trial.
    A = handles.A;   % these structs are small enough we will pass them
    if ~handles.runImage
        S = handles.S;   % as arguments .... don't make them huge ... larger
        P = handles.P;   % data should stay in D, or inside the PR or FC objects
    else
        S = handles.SI;  % pull other arguments for image protocol
        P = handles.PI;
    end

    % Create data file and, once opened, append to it for each new trial data
    % IF NOT DATA FILE OPENED, CREATE AND INSERT S Struct first
    %****** ONCE OPENED, YOU ONLY APPEND TO THAT FILE EACH TRIAL NEW DATA
    cd(handles.outputPath);             % goto output directory
    if ~exist(A.outputFile, 'file')
        save(A.outputFile, 'S');     % save settings struct to output file
    end
    cd(handles.taskPath);               % return to task directory

    % These are here in case user updated calibration or params while paused
    handles.FC.update_eye_calib(A.c, A.dx, A.dy, A.rot);
    handles.FC.update_args_from_Pstruct(P);


    % ----------
    % RUN TRIALS
    % ----------
    CorCount = 0;   % count consecutive correct trials (for BackImage interleaving)
    SetRunBack = 0; % flag for swapping to interleaved image trials and back

    while handles.runTask && A.j <= A.finish
        % 'pause', 'drawnow', 'figure', 'getframe', or 'waitfor' will allow
        % other callbacks to interrupt this run task callback -- be aware that
        % if handles aren't properly managed then changes either in the run
        % loop or in other parts of the GUI may be out-of-sync. Nothing changes
        % to GUI-wide handles until the local callback puts them there. If
        % other callbacks change handles, and they are not brought into this
        % callback, then those changes are lost when this run loop updates that
        % handles. This concept is explained further right below during the
        % nextCmd handles management.

        % Check if automatic interleaving of BackImage trials and set the trial
        if isfield(handles.P,'CycleBackImage')
            if handles.P.CycleBackImage > 0
                if ~mod((CorCount+1),handles.P.CycleBackImage)
                    handles.runImage = true;
                    SetRunBack = 1;
                    S = handles.SI;
                    P = handles.PI;
                end
            end
        end

        % EXECUTE THE NEXT TRIAL COMMAND
        if ~handles.runImage
            P = handles.PR.next_trial(S,P);
        else
            P = handles.PRI.next_trial(S,P);
        end

        % Update in case juice volume was set in parameters (TODO, standardize)
        if handles.A.juiceVolume ~= A.juiceVolume
            handles.reward.setVolume(A.juiceVolume);
            if (handles.S.rewardType == "Solenoid")
                set(handles.JuiceVolumeText,...
                    'String', sprintf('%3i ms',A.juiceVolume*1e3));
            else
                set(handles.JuiceVolumeText,...
                    'String', sprintf('%3i ul',A.juiceVolume*1e3));
            end
            handles.A.juiceVolume = A.juiceVolume;
        end
        % UPDATE HANDLES FROM ANY CHANGES DURING NEXT TRIAL -- IF THIS ISN'T
        % DONE, THEN THE OTHER CALLBACKS WILL BE USING A DIFFERENT HANDLES
        % STRUCTURE THAN THIS LOOP IS
        cprintf('[0.5 0.5 0.5]', 'Callback pause ');
        guidata(hObject,handles);
        % ALLOW OTHER CALLBACKS INTO THE QUEUE AND UPDATE HANDLES --
        % HERE, HAVING UPDATED ANY RUN LOOP CHANGES TO HANDLES, WE LET OTHER
        % CALLBACKS DO THEIR THING. WE THEN GRAB THOSE HANDLES SO THE RUN LOOP
        % IS ON THE SAME PAGE. FORTUNATELY, IF A PARAMETER CHANGES IN HANDLES,
        % THAT WON'T AFFECT THE CURRENT TRIAL WHICH IS USING 'P', NOT handles.P
        pause(.001); handles = guidata(hObject);
        cprintf('[0.5 0.5 0.5]', '   resume\n');

        % -----------------------------
        % EXECUTE THE RUN TRIAL COMMAND
        % -----------------------------
        cprintf('[1 0.2 1]', '\tMV6, prep run trial\n');

        %******** IMPLEMENT DEFAULT RUN TRIAL HERE DIRECTLY **********
        %***** Note, PR will refer to the PROTOCOL object ************
        if ~handles.runImage
            [FP, TS] = handles.PR.prep_run_trial();
        else
            [FP, TS] = handles.PRI.prep_run_trial();
        end
        % load values into class for plotting (FP) and to label TimeSensitive
        % states (TS)
        handles.FC.set_task(FP, TS);

        % Task Controller flips first frame and logs the trial start
        [ex,ey] = handles.eyetrack.getgaze();
        pupil = handles.eyetrack.getpupil();

        % This is where to perform TimeStamp Syncing (start of trial)
        cprintf('[1 0.2 1]', '\tMV6, setting clock\n');
        STARTCLOCK = handles.FC.prep_run_trial([ex,ey],pupil);
        STARTCLOCKTIME = GetSecs;
        if (S.DataPixx)
            datapixx.strobe(63,0);  % send all bits on to mark trial start
        end
        %***********************
        tstring = sprintf('TRIALSTART:TRIALNO:%5i %2d %2d %2d %2d %2d %2d',...
            handles.A.j, STARTCLOCK(1:6));   % code the sixlet
        handles.eyetrack.sendcommand(tstring);
        %***********************************************************
        if (S.DataPixx)
            for k = 1:6
                datapixx.strobe(STARTCLOCK(k),0);
            end
        end
        %**************************************************

        if S.eyetrackerType == "Trackpixx"
            handles.eyetrack.unpause();
        end
        % ----------------
        % Start trial loop
        % ---------------------------------------------------------------------
        rewardtimes = [];
        runloop = 1;
        %****** added to control when juice drop is delivered based on graphics
        %****** demands, drop juice on frames with low demands basically
        screenTime = GetSecs();
        frameTime = (0.5/handles.S.frameRate);
        holdrop = 0;
        dropreject = 0;
        %**************

        while runloop
            if ~handles.runImage
                state = handles.PR.get_state();
            else
                state = handles.PRI.get_state();
            end

            % ------------------
            % GET ON-LINE VALUES
            % -----------------------------------------------------------------

            [ex,ey] = handles.eyetrack.getgaze();
            pupil = handles.eyetrack.getpupil();
            [currentTime, x, y] = handles.FC.grabeye_run_trial(...
                state, [ex, ey], pupil);

            if ~handles.runImage
                drop = handles.PR.state_and_screen_update(currentTime, x, y);
            else
                drop = handles.PRI.state_and_screen_update(currentTime, x, y);
            end

            % One idea, only deliver drop if there is alot of time before the
            % next screen flush (since drop command takes time)
            if drop > 0
                holdrop = 1;
                dropreject = 0;
            end
            if holdrop
                droptime = GetSecs();
                if ( (droptime-screenTime) < frameTime) || (dropreject > 12)
                    holdrop = 0;
                    rewardtimes = [rewardtimes, droptime];
                    handles.reward.deliver();
                else
                    dropreject = dropreject + 1;
                end
            end

            % --------------------------------------------------
            % EYE DISPLAY, SCREEN FLIP, GUI UPDATING (if not TS)
            % -----------------------------------------------------------------
            [updateGUI, screenTime] = handles.FC.screen_update_run_trial(state);

            if updateGUI
                drawnow;  % grab the pause button hit
                % Update any changes made to the calibration
                handles = guidata(hObject);
                %*** pass update back into task controller
                A.c = handles.A.c;
                A.dx = handles.A.dx;
                A.dy = handles.A.dy;
                A.rot = handles.A.rot;
                handles.FC.update_eye_calib(A.c, A.dx, A.dy, A.rot);
            end
            if ~handles.runImage
                runloop = handles.PR.continue_run_trial(screenTime);
            else
                runloop = handles.PRI.continue_run_trial(screenTime);
            end
        end

        %******** Update eye trace window before ITI start
        ENDCLOCK = handles.FC.last_screen_flip();   % set screen to gray, trial over, start ITI
        ENDCLOCKTIME = GetSecs();
        % Stop acquisition of data to the buffer.
        if S.eyetrackerType == "Trackpixx"
            handles.eyetrack.pause();
        end

        %******* the data pix strobe will take about 0.5 ms **********
        if (S.DataPixx)
            % send all bits on but first (254) to mark trial end
            datapixx.strobe(62,0);
        end

        %****** AGAIN this is a place for timing event to synch up trial ends
        % this takes about 2 ms to send VPX command string
        tstring = sprintf('TRIALENDED:TRIALNO:%5i %2d %2d %2d %2d %2d %2d',...
            handles.A.j, ENDCLOCK(1:6));   % code the sixlet
        handles.eyetrack.sendcommand(tstring);
        %****** send the rest of the sixlet via DataPixx
        % this sixlet of numbers takes about 2 ms, but not used for time strobe
        if S.DataPixx
            for k = 1:6
                datapixx.strobe(ENDCLOCK(k),0);
            end
        end
        %**********************************************************

        % Any final clean-up for PR in the trial, return duration of iti
        if ~handles.runImage
            Iti = handles.PR.end_run_trial();
        else
            Iti = handles.PRI.end_run_trial();
        end

        %* --------------------
        %* INTER-TRIAL INTERVAL
        %* ------------------------------------------------------------------------

        % PLOT THE EYETRACE and enforce an ITI interval
        itiStart = GetSecs();
        subplot(handles.EyeTrace); hold off;  % clear old plot
        if ~handles.lastRunWasImage
            handles.PR.plot_trace(handles); hold on;
        else
            handles.PRI.plot_trace(handles); hold on;
        end
        handles.FC.plot_eye_trace_and_flips(handles);  %plot the eye traces

        while (GetSecs() < (itiStart + Iti))
            drawnow;   % grab GUI events while running ITI interval
            handles = guidata(hObject);
        end

        % UPDATE HANDLES FROM ANY CHANGES DURING RUN TRIAL
        guidata(hObject,handles);
        % ALLOW OTHER CALLBACKS INTO THE QUEUE AND UPDATE HANDLES
        pause(.001); handles = guidata(hObject);

        % ---------------------
        % CREATE DATA STRUCTURE
        % -------------------------------------------------------------------------
        % Some Data is uploaded automatically from Task Controller
        D = struct();
        D.P = P; % THE TRIAL PARAMETERS
        D.STARTCLOCK = STARTCLOCK;
        D.ENDCLOCK = ENDCLOCK;
        D.STARTCLOCKTIME = STARTCLOCKTIME;
        D.ENDCLOCKTIME = ENDCLOCKTIME;

        if ~handles.runImage
            %if critical trial info save as D.PR
            D.PR.name = handles.S.protocol;
            D.PR = handles.PR.end_plots(P,A);
            if (D.PR.error == 0)
                CorCount = CorCount + 1;
            end
        else
            D.PR.name = 'BackImage';
            D.PR = handles.PRI.end_plots(P,A);
        end

        if handles.S.eyetrackerType == "Trackpixx"
            D.TPxData = handles.eyetrack.getDataOnBuffer();
            fprintf('%u total: %.2f left eye, %.2f right eye\n', height(D.TPxData),...
                100*nnz(~isnan(D.TPxData.LeftEyeRawX)) / height(D.TPxData),...
                100*nnz(~isnan(D.TPxData.RightEyeRawX)) / height(D.TPxData));
        else
            D.TPxData = [];
        end
        D.eyeData = handles.FC.upload_eyeData();
        [c,dx,dy,rot] = handles.FC.upload_C();
        D.c = c; D.dx = dx; D.dy = dy; D.rot = rot;

        % log: 1) time of juice pulses, 2) supplementary juice, 3) volume
        D.rewardtimes = rewardtimes;
        D.juiceButtonCount = handles.A.juiceCounter;
        D.juiceVolume = A.juiceVolume;  %#ok<STRNU>

        % -------------
        % SAVE THE DATA
        % ---------------------------------------------------------------------
        cd(handles.outputPath);
        % % will store trial data in this variable
        Dstring = sprintf('D%d', A.j);
        cprintf('*[1 0.2 0.5]', 'eval cmd is %s = D\n', Dstring);
        eval(sprintf('%s = D;',Dstring));   % set variable

        % append file
        save(A.outputFile, '-append', 'S', Dstring);

        cd(handles.taskPath);               % return to task directory
        eval(sprintf('clear %s;',Dstring));
        clear D;                 % release the memory for D once saved

        %******************************************************************
        %************** END OF THE TRIAL DATA SECTION *********************
        %******************************************************************

        % Update trial count
        A.j = A.j+1;
        set(handles.TrialCountText, 'String', num2str(A.j-1));

        if ~handles.runOneTrial
            A.finish = handles.A.finish;
            set(handles.TrialMaxText, 'String', num2str(A.finish));
        end

        % Check for updates in juice volume during trial
        if handles.A.juiceVolume ~= A.juiceVolume
            if handles.S.rewardType == "NewEra"
                fprintf(A.pump,['0 VOL ' num2str(A.juiceVolume/1000)]);
            end
            if handles.S.rewardType == "Solenoid"
                set(handles.JuiceVolumeText, 'String', [num2str(A.juiceVolume) ' ms']);
            else
                set(handles.JuiceVolumeText, 'String', [num2str(A.juiceVolume) ' ul']);
            end
        end

        % UPDATE THE TASK RELATED STRUCTURES IN CASE OF LEAVING THE RUN LOOP
        handles.A = A;
        if ~handles.runImage
            handles.S = S;
            handles.P = P;
        else
            handles.SI = S;
            handles.PI = P;
        end

        % If it was an interleave Image trial, set it back proper
        if SetRunBack == 1
            handles.runImage = false;
            SetRunBack = 0;
            S = handles.S;
            P = handles.P;
            CorCount = 0;
        end
        %************************************

        % UPDATE THE PARAMETER LIST TO SHOW THE NEXT TRIAL PARAMETERS
        updateParameterDisplay(handles);

        % UPDATE THE HANDLES STRUCTURE FROM ALL OF THESE CHANGES
        guidata(hObject,handles);
        % ALLOW OTHER CALLBACKS INTO THE THE QUEUE. IF PARAMETERS ARE CHANGED BY
        % CHANCE THIS LATE IN THE LOOP, THEY WILL NOT BE CHANGED UNTIL REACHING THE
        % END OF THE NEXT TRIAL, BECAUSE P HAS ALREADY BEEN ESTABLISHED FOR THE
        % NEXT TRIAL. IF YOU EXIT THE LOOP, THOUGH, THEN P WILL BE UPDATED BY WILL
        % BE UPDATED BY ANY CHANGES TO THE HANDLES
        pause(.001); handles = guidata(hObject);

        % STOP RUN TASK IF SET TO DO SO
        if handles.stopTask || handles.runOneTrial
            handles.runTask = false;
        end
    end

    %************************ LOOP IS COMPLETE ****************************

    % PAUSE THE EYETRACKER
    handles.eyetrack.pause();

    % NO TASK RUNNING FLAGS SHOULD BE ON ANYMORE
    handles.runTask = false;
    handles.stopTask = false;

    % UPDATE THE PARAMETERS LIST IN CASE OF ANY CHANGES MADE AFTER RUNNING THE
    % END TRIAL COMMAND
    updateParameterDisplay(handles);

    % Turn GUI back on...
    ChangeLight(handles.TaskLight, [0 1 0]);
    EnableOutputFileNaming(handles, 'on');
    set([handles.RunTrial, handles.FlipFrame, handles.Background_Image,...
        handles.Calib_Screen, handles.CloseGui, handles.ClearSettings],...
        'Enable', 'On');
    set([handles.Parameters, handles.TrialMaxEdit, handles.JuiceVolumeEdit,...
        handles.ChooseSettings, handles.Initialize, handles.ParameterEdit],...
        'Enable', 'On');
    if ~handles.S.DummyEye
        EnableEyeCalibration(handles, 'On');
    end
    set(handles.PauseTrial,'Enable','Off');
    UpdateEyeText(handles);
    % Done and ready for another protocol
    ChangeLight(handles.TaskLight,[1 0 0]);
    set(handles.StatusText, 'String', 'Protocol is ready to run trials.');

    guidata(hObject,handles);

%% Callbacks: Trial control
% STOP THE TRIAL LOOP ONCE THE CURRENT TRIAL HAS COMPLETED
function PauseTrial_Callback(hObject, eventdata, handles)
    % Pause button can also act as an unpause button
    if ~handles.stopTask
        handles.stopTask = true;
        % SET TASK LIGHT TO ORANGE
        ChangeLight(handles.TaskLight, [.9 .7 .2]);
    end

    guidata(hObject,handles);


% GIVE A JUICE REWARD
function GiveJuice_Callback(hObject, eventdata, handles)
    handles.reward.deliver();
    handles.A.juiceCounter = handles.A.juiceCounter + 1;
    guidata(hObject,handles);


% CHANGE THE SIZE OF THE JUICE REWARD TO BE DELIVERED
function JuiceVolumeEdit_Callback(hObject, eventdata, handles)
    % Volume is entered in microliters, classes take milliliters
    vol = get(hObject, 'String');
    volML = str2double(vol) / 1e3;
    handles.reward.setVolume(volML);
    if handles.S.rewardType == "Solenoid"
        set(handles.JuiceVolumeText, 'String', [vol ' ms']);
    else
        set(handles.JuiceVolumeText, 'String', [vol ' ul']);
    end
    set(hObject, 'String', '');
    % A.juiceVolume should *always* be in milliliters!
    handles.A.juiceVolume = volML;
    guidata(hObject,handles);


% RESETS THE DISPLAY SCREEN IF IT WAS INTERUPTED (BY E.G. ALT-TAB)
function FlipFrame_Callback(hObject, eventdata, handles)
    % If a bkgd parameter exists, flip frame with background color value
    if isfield(handles.P, 'bkgd')
        if handles.S.use8Bit
            bkgd = uint8(handles.P.bkgd);
        else
            bkgd = handles.P.bkgd;
        end
        Screen('FillRect', handles.A.window, bkgd);
    end
    Screen('Flip', handles.A.window);


%% Callbacks: Parameter control
function Parameters_Callback(hObject, eventdata, handles)
    % Get the index of the selected field
    i = get(hObject,'Value');
    % Set the parameter text to a description of the parameter
    set(handles.ParameterText,'String',handles.S.(handles.pNames{i}));
    % Set the parameter edit to the current value of that parameter
    set(handles.ParameterEdit,'String',num2str(handles.P.(handles.pNames{i})));
    % Update handles structure
    guidata(hObject,handles);

function ParameterEdit_Callback(hObject, eventdata, handles)
    % Get the new parameter value
    pValue = str2double(get(hObject,'String'));
    % Get the parameter name
    pName = handles.pNames{get(handles.Parameters,'Value')};
    % If the parameter value is a number
    if ~isnan(pValue)
        % Change the parameter value
        handles.P.(pName) = pValue;
        % Update the parameter list immediately if not in the run loop
        if ~handles.runTask
            tName = sprintf('%s = %2g',pName,handles.P.(pName));
            handles.pList{get(handles.Parameters, 'Value')} = tName;
            set(handles.Parameters,'String',handles.pList);
        end
    else
        % Revert the parameter text to the previous value
        set(hObject,'String',num2str(handles.P.(pName)));
    end
    % Update handles structure
    guidata(hObject,handles);

function TrialMaxEdit_Callback(hObject, eventdata, handles)
    % Get the new count
    newFinal = round(str2double(get(hObject,'String')));
    % Make sure the new final trial is a positive integer
    if newFinal > 0
        % Update the final trial
        handles.A.finish = newFinal;
        % Set the count
        set(handles.TrialMaxText,'String',get(hObject,'String'));
    end
    % Clear the edit string
    set(hObject,'String','');

    % Update handles structure
    guidata(hObject,handles);

%% Callbacks: Shift eye position
function CenterEye_Callback(hObject, eventdata, handles)
    [x, y] = handles.eyetrack.getgaze();
    handles.A.c = [x, y];
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function GainSize_Callback(hObject, eventdata, handles)
    gainSize = str2double(get(hObject,'String'));
    if ~isnan(gainSize)
        handles.gainSize = gainSize;
        guidata(hObject,handles);
    else
        set(handles.GainSize,'String',num2str(handles.gainSize));
    end

function GainUpX_Callback(hObject, eventdata, handles)
    % Note we divide by dx, so reducing dx increases gain
    handles.A.dx = (1-handles.gainSize)*handles.A.dx;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function GainDownX_Callback(hObject, eventdata, handles)
    handles.A.dx = (1+handles.gainSize)*handles.A.dx;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function GainUpY_Callback(hObject, eventdata, handles)
    handles.A.dy = (1-handles.gainSize)*handles.A.dy;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function GainDownY_Callback(hObject, eventdata, handles)
    handles.A.dy = (1+handles.gainSize)*handles.A.dy;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);


function ShiftSize_Callback(hObject, eventdata, handles)
    shiftSize = str2double(get(hObject,'String'));
    if ~isnan(shiftSize)
        handles.shiftSize = shiftSize;
        guidata(hObject,handles);
    else
        set(handles.ShiftSize,'String',num2str(handles.shiftSize));
    end

function ShiftLeft_Callback(hObject, eventdata, handles)
    handles.A.c(1) = handles.A.c(1) + ...
        handles.shiftSize*handles.A.dx*handles.S.pixPerDeg;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function ShiftRight_Callback(hObject, eventdata, handles)
    handles.A.c(1) = handles.A.c(1) - ...
        handles.shiftSize*handles.A.dx*handles.S.pixPerDeg;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function ShiftDown_Callback(hObject, eventdata, handles)
    handles.A.c(2) = handles.A.c(2) + ...
        handles.shiftSize*handles.A.dy*handles.S.pixPerDeg;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function ShiftUp_Callback(hObject, eventdata, handles)
    handles.A.c(2) = handles.A.c(2) - ...
        handles.shiftSize*handles.A.dy*handles.S.pixPerDeg;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

function RotationAngleText_Callback(hObject, eventdata, handles)
    roto = str2double(get(hObject,'String'));
    handles.A.rot = roto;
    guidata(hObject,handles);
    UpdateEyeText(handles);
    UpdateEyePlot(handles);

%% UICONTROL CREATE FUNCTIONS
function RotationAngleText_CreateFcn(hObject, eventdata, handles)
function ShiftSize_CreateFcn(hObject, eventdata, handles)
function GainSize_CreateFcn(hObject, eventdata, handles)
function TrialMaxEdit_CreateFcn(hObject, eventdata, handles)
function ParameterEdit_CreateFcn(hObject, eventdata, handles)
function Parameters_CreateFcn(hObject, eventdata, handles)
function OutputSuffixEdit_CreateFcn(hObject, eventdata, handles)
function OutputPrefixEdit_CreateFcn(hObject, eventdata, handles)
function OutputSubjectEdit_CreateFcn(hObject, eventdata, handles)
function OutputDateEdit_CreateFcn(hObject, eventdata, handles)
function JuiceVolumeEdit_CreateFcn(hObject, eventdata, handles)

%% OUTPUT PANEL CALLBACKS
function OutputPrefixEdit_Callback(hObject, eventdata, handles)
    handles.outputPrefix = get(hObject,'String');
    handles = UpdateOutputFilename(handles);
    guidata(hObject,handles);

function OutputSubjectEdit_Callback(hObject, eventdata, handles)
    handles.outputSubject = get(hObject,'String');
    handles.S.subject = handles.outputSubject;
    handles = UpdateOutputFilename(handles);
    guidata(hObject,handles);

function OutputDateEdit_Callback(hObject, eventdata, handles)
    handles.outputDate = get(hObject,'String');
    handles = UpdateOutputFilename(handles);
    guidata(hObject,handles);

function OutputSuffixEdit_Callback(hObject, eventdata, handles)
    handles.outputSuffix = get(hObject,'String');
    handles = UpdateOutputFilename(handles);
    guidata(hObject,handles);

%%%%% CLOSE THE GUI %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function CloseGui_Callback(hObject, eventdata, handles)
    % Close Psychtoolbox screens
    Screen('Close'); sca;

    % If Data File Open, condense appended D's into one struct ****
    CondenseAppendedData(hObject,handles);

    % Save any changes to the calibration
    c = handles.A.c; dx = handles.A.dx; dy = handles.A.dy; rot = handles.A.rot;
    if ~handles.S.DummyEye
        save([handles.supportPath 'MarmoViewLastCalib.mat'],'c','dx','dy','rot');
    end

    % Close the pump
    handles.reward.report()
    if handles.S.rewardType == "Kinesis"
        handles.reward.disconnect();
    end
    delete(handles.reward);
    handles.reward = NaN;

    % Close the trackpixx
    % TODO: This should be in trackpixx class
    if handles.S.eyetrackerType == "Trackpixx" && handles.eyetrack.isAwake
        status = Datapixx('GetTPxStatus');
        toRead = status.newBufferFrames;
        if toRead > 0
            cprintf('_[0.5,0.5,0.5]', 'Closing MView, clearing %u frames on buffer\n', toRead);

            Datapixx('ReadTPxData', toRead);
        end
        Datapixx('SetTpxSleep');
        Datapixx('RegWrRd');
    end

    % Close the datapixx
    if handles.S.DataPixx
        datapixx.close();
    end

    % Close the gui window
    close(handles.figure1);

%% AUXILLIARY FUNCTIONS
function ChangeLight(h, newColor)
    scatter(h, .5, .5, 600,...
        'o', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', newColor);
    axis(h,[0 1 0 1]); bkgd = [.931 .931 .931];
    set(h, 'XColor', bkgd, 'YColor', bkgd, 'Color', bkgd);

% THIS FUNCTION UPDATES THE RAW EYE CALIBRATION NUMBERS IN THE GUI
function UpdateEyeText(h)
    set(h.CenterText, 'String', sprintf('[%.3g %.3g]',h.A.c(1),h.A.c(2)));
    dx = 100*h.A.dx; dy = 100*h.A.dy;
    set(h.GainText,'String',sprintf('[%.3g %.3g]',dx,dy));
    set(h.RotationAngleText, 'String', sprintf('%.3g', h.A.rot));

% THIS FUNCTION UPDATES PLOTS OF THE EYE TRACE
function UpdateEyePlot(handles)
    % At least 1 trial must be complete in order to plot the trace
    if ~handles.runTask && handles.A.j > 1
        subplot(handles.EyeTrace); hold off;  % clear old plot
        if ~handles.lastRunWasImage
            handles.PR.plot_trace(handles); hold on; % command to plot on eye traces
        else
            handles.PRI.plot_trace(handles); hold on; % command to plot on eye traces
        end
        handles.FC.plot_eye_trace_and_flips(handles);  %plot the eye traces
    end

function handles = UpdateOutputFilename(handles)
    % Generate the file name
    if (~isempty(handles.outputPrefix) && ~isempty(handles.outputSubject) && ...
            ~isempty(handles.outputDateEdit) && ~isempty(handles.outputSuffixEdit) )
        handles.A.outputFile = strcat(handles.outputPrefix,'_',handles.outputSubject,...
            '_',handles.outputDate,'_',handles.outputSuffix,'.mat');
        set(handles.OutputFile, 'String',handles.A.outputFile);
        % If the file name already exists, provide a warning that data will be
        % overwritten
        if exist([handles.outputPath handles.A.outputFile],'file')
            w=warndlg('Data file alread exists, running the trial loop will overwrite.');
            set(w,'Position',[441.75 -183 270.75 75.75]);
        end
        % Note that a new output file is being used. For example, someone might
        % want to be sure the trials list is started over if the output file name
        % changes. Currently I don't have any protocols implementing this.
        handles.A.newOutput = 1;
    else
        if ( ~isempty(handles.outputSubject) && ~strcmp(handles.outputSubject,'none') )
            %****** then it should be possible to initialize a protocol with name
            set(handles.SettingsPanel,'Visible','on');
            if ~exist([handles.settingsPath handles.settingsFile],'file')
                set(handles.Initialize,'Enable','off');
                tstring = 'Please select a settings file...';
            else
                set(handles.Initialize,'Enable','on');
                tstring = 'Ready to initialize protocol...';
            end
            % Update GUI status
            set(handles.StatusText,'String',tstring);
            %*******************************************
        end
    end

% Turn on or off all controls related to eye calibration
function EnableEyeCalibration(handles,state)
    set(handles.CenterEye,'Enable',state);
    set(handles.ShiftUp,'Enable',state);
    set(handles.ShiftDown,'Enable',state);
    set(handles.ShiftLeft,'Enable',state);
    set(handles.ShiftRight,'Enable',state);
    set(handles.GainUpY,'Enable',state);
    set(handles.GainDownY,'Enable',state);
    set(handles.GainUpX,'Enable',state);
    set(handles.GainDownX,'Enable',state);
    set(handles.ShiftSize,'Enable',state);
    set(handles.GainSize,'Enable',state);
    set(handles.RotationAngleText,'Enable',state);
    set(handles.GraphZoomIn,'Enable',state);
    set(handles.GraphZoomOut,'Enable',state);

% --- Toggles controls related to output specification
function EnableOutputFileNaming(handles, state)
    set(handles.OutputPrefixEdit, 'Enable', state);
    set(handles.OutputDateEdit, 'Enable', state);
    set(handles.OutputSuffixEdit, 'Enable', state);

% --- Executes on button press in Calib_Screen.
function Calib_Screen_Callback(hObject, eventdata, handles)
    % If a bkgd parameter exists, flip frame with background color value
    % Screen('FillRect',handles.A.window,uint8(0));
    % Screen('Flip',handles.A.window);
    handles.runImage = true;
    handles.runOneTrial = true; % keep running till paused, or true stop at one
    hold_dir = handles.SI.ImageDirectory;
    handles.PRI.load_image_dir(['SupportData', filesep, 'ForagePoint']);
    guidata(hObject,handles);
    RunTrial_Callback(hObject, eventdata, handles)
    % it appears if handles changed, you need to regrab it
    % what lives in this function is the old copy of it
    handles = guidata(hObject);
    %**********
    handles.runImage = false;
    handles.runOneTrial = false;
    handles.PRI.load_image_dir(hold_dir);
    guidata(hObject,handles);


% --- Executes on button press in Background_Image.
function Background_Image_Callback(hObject, eventdata, handles)
    % Idea is the following, turn on flag and run PRI object instead
    % of the PR object, otherwise data logging and other tracking identical
    handles.runImage = true;
    handles.runOneTrial = true; % keep running till paused, or true stop at one
    guidata(hObject,handles);
    RunTrial_Callback(hObject, eventdata, handles)
    % it appears if handles changed, you need to regrab it
    % what lives in this function is the old copy of it
    handles = guidata(hObject);

    handles.runImage = false;
    handles.runOneTrial = false;
    guidata(hObject,handles);

% --- Executes on button press in GraphZoomIn.
function GraphZoomIn_Callback(hObject, eventdata, handles)
    if handles.eyeTraceRadius > 2.5
        handles.eyeTraceRadius = handles.eyeTraceRadius-2.5;
    end
    guidata(hObject,handles);
    UpdateEyePlot(handles);


% --- Executes on button press in GraphZoomOut.
function GraphZoomOut_Callback(hObject, eventdata, handles)
    if handles.eyeTraceRadius < 30
        handles.eyeTraceRadius = handles.eyeTraceRadius+2.5;
    end
    guidata(hObject,handles);
    UpdateEyePlot(handles);

function updateVolumeDisplay(gObj, S, vol)
    % Takes handle to graphics object, settings, and volume
    vol = sprintf('%3i', vol);
    if handles.S.rewardType == "Solenoid"
        set(gObj, 'String', [vol ' ms']);
    else
        set(gObj, 'String', [vol ' ul']);
    end

function updateParameterDisplay(handles)
    for i = 1:size(handles.pNames,1)
        pName = handles.pNames{i};
        tName = sprintf('%s = %2g', pName,handles.P.(pName));
        handles.pList{i, 1} = tName;
    end
    set(handles.Parameters, 'String', handles.pList);

% --- Executes on button press in Refresh_Trials.
function Refresh_Trials_Callback(hObject, eventdata, handles)
    %REBUILD A NEW TRIALS LIST FROM CURRENT PARAMS
    handles.PR.generate_trialsList(handles.S,handles.P);
    % DE-INITIALIZE OBJECTS (may need to make new if Param changed)
    handles.PR.closeFunc();
    % RE-INITIALIZE OBJECTS (may need to make new if Param changed)
    fprintf('Initializing protocol...'); % Bc this can take time
    handles.PR.initFunc(handles.S,handles.P);
    fprintf('Done\n');
    %******* load changes in handles back to the GUI
    guidata(hObject,handles);


function CondenseAppendedData(hObject, handles)
    % We store trial by trial data while running but before closing, we
    % condense it back to a single D struct. NOTE: if MarmoView hangs or
    % crashes, you would still be able to call this routine on what is saved

    guidata(hObject,handles); drawnow;

    A = handles.A;   % get the A struct (carries output file names)
    %******* go to outputPath and load current data
    if strcmp(A.outputFile, 'none')  % could be in state with no open file
        return
    end
    cd(handles.outputPath);             % goto output directory
    if exist(A.outputFile,'file')
        NewOutput = [A.outputFile(1:(end-4)),'z.mat'];
        fprintf('Condensing data for file %s to %s\n', A.outputFile, NewOutput);
        zdata = load(A.outputFile);    % load in all data
        S = zdata.S;                   % get settings struct
        D = cell(1,1);
        ND = length(fields(zdata));      % includes all trials, minus one for S
        for k = 1:(ND-1)
            Dstring = sprintf('D%d',k);
            D{k,1} = zdata.(Dstring);
        end
        clear zdata;
        %********
        save(NewOutput, 'S', 'D');   % append file
        clear D;
        fprintf('Data file %s reformatted.\n',NewOutput);
    end
    cd(handles.taskPath);            % return to task directory

