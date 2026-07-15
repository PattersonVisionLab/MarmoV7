# MarmoV7

Running notes on parsing how MarmoV6 works.

### Important for running this version
- Assumes `PsychStartup()` is called in `startup.m` as of 22Jun2026

### Version discrepancies
Rig computer (simulation and experiment modes)
- Windows 11, MATLAB 2020a and 2024b
Sara Laptop
- Windows 11, MATLAB 2025b (needed to adjust verLessThan calls in PTB)


### Hardware integration
PLDAPS sync with Plexon strobes using first 16 DOut channels so "blue" pixel sync options should be open for us to do whatever we'd like.

NewEra syringe pump could go thru USB.

Trackpixx calibration contains 9 coefficients (left x, right x, left y, right y). 1 = const, 2 = x, 3 = y, 4 = x^2, 5 = y^2, 6 = x^3 || xy^2, 7 = xy, 8 = x^2y, 9 = x^2y^2

### Structures
- **`S`**:  Settings (`MarmoViewRigSettings` but also other things added after each reload in UI and in `Settings\` runs?)
    - Output of `MarmoViewRigSettings` (called in UI)
    - Output of protocol settings (calls rig settings too), descriptors for fields in `P`
    - Misc things in MarmoV6 
- **`P`**:  Parameters (set only by protocol setting functions?)
- **`C`**:  Calibration. This never changes, but the copy in `A` does.
- **`A`**: 
- **`D`**:  Data (P, eyeData, PR, C)
- **`PR`**: Protocol 
- **`PRI`**: BackImage Protocol (`lastRunWasImage`)
- **`FC`**: FrameControl object


> Different structures serve as sites for "working" copy of variables and initial copy (e.g., used when resetting something). For example, `PR` is the working copy of P? And the fields of `C` are also in `A`, but `C` never changes and `A` is working copy? Some features of `S` like rig settings are static but have to be reloaded when `S` is reset by a protocol setting file to append protocol-specific info and then the MarmoV6 additions (subject info) need to be appended too. 

- RigSettings (Monitor, Reward, Eyetrack, Datapixx, misc params)
- StimulusProtocol
- BackgroundImageProtocol
- _CurrentProtocol_
- ProtocolParameters (separate from protocol itself but merge descriptors?)
- BaseCalibration
- _Calibration_
- Data

### Light
- Grey: no protocol selected
- Red: protocol loaded but not running
- Blue: protocol initializing
- Green: protocol running
- Yellow: pressed pause

# Classes
### Eyetracker
- `startfile`: needed for arrington, automatic for eyelink, up to us for trackpixx
- `closefile`: needed for eyelink and arrington
- `pause`: 
- `unpause`: 
- `getgaze`: runs on each flip
- `getpupil`: runs on each flip
- `sendcommand`: necessary for arrington only, useful for logging 
- `initialize`: formerly in the constructor, let's get it into a dedicated fcn


### Protocol
- `generate_trialsList(obj, S, P)`
- `P = next_trial(obj, S, P)`
- `closeFunc(obj)`
- `keepgoing = continue_run_trial(obj, screenTime)`
- `drop = state_and_screen_update(currentTime, x, y)`
- `P = next_trial(obj, S, P)`
- `[FP, TS] = prep_run_trial(obj)`
- `Iti = end_run_trial(obj)`
- `plot_trace(obj, handles)`
- `PR = end_plots(obj, P, A)`


# WORKFLOW
#### Initialize a Protocol
-	obj = TrialIndexer()
-	MViewRigSettings()
-	PsychStartup()
-	A = openScreen(S, A)
-	PR = Protocol (handles.A.window)
-	Protocol.generateTrialsList(S, P)
-	Protocol.initFunc(S, P)
-	PRI = BackImage(handles.A.window)
-	FrameControl.initialize()
-	FrameControl.updateArgsFromPStruct(P)
-	EyeTrack.startFile()

#### Run the Protocol
-	MV6 Callback: RunTrial
-	EyeTrack.unpause()
-	FrameControl.updateEyeCalib(A.c, A.dx, A.dy, A.rot)
-	FrameControl.updateArgsFromPStruct(P)

Each Trial
-	P = Protocol.nextTrial(S, P)
-	[FP, TS] = Protocol.prepRunTrial()
-	FrameControl.setTask(FP, TS)
-	[x, y] = EyeTrack.getgaze()
-	r = EyeTrack.getpupil()
-	STARTCLOCK = FrameControl.prepRunTrial()
-	EyeTrack.sendCommand(“TRIAL START”)
-	Datapixx.strobe()
-	EyeTrack.unpause()

Each Frame
-	state = Protocol.getState()
-	[ex, ey] = EyeTrack.getgaze()
-	r = EyeTrack.getpupil()
-	[currentTime, x, y] = FrameControl.grabEyeRunTrial(state, ex, ey, pupil)
-	reward = Protocol.stateAndScreenUpdate(currentTime, x, y)
-	reward.deliver()
-	[updateUI, tStamp] = FrameControl.screenUpdateRunTrial(state)
-	FrameControl.updateEyeCalib(A.c, A.dx, A.dy, A.rot)
-	tf = Protocol.continueRunTrial(tStamp)

Final Frame in Trial
-	ENDCLOCK = FrameControl.lastScreenFlip()
-	EyeTrack.pause()
-	Datapixx.strobe()
-	EyeTrack.sendCommand(“TRIALENDED”)
-	ITI = Protocol.endRunTrial()
-	Protocol.plotTrace(handles)
-	FrameControl.plotEyeTraceAndFlips(handles)
-	D.PR = Protocol.endPlots(P, A)
-	tpxData = EyeTrack.getDataOnBuffer()
-	D.eyeData = FrameControl.uploadEyeData()
-	[c,dx,dy,rot] = FrameControl.uploadC()

Clear Protocol
-	EyeTrack.pause()
-	MView.clearSettings()
-	EyeTrack.closeFile()
-	MView.condenseDataStruct()
-	MViewRigSettings()
