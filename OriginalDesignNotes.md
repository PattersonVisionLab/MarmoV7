# Original design notes


## Structures
Protocol (PR), Parameters (P) and Setting (S) structures
- `PR` amd S
- `PRI` and `SI` are bkgd image protocol

The `A` structure contains:
- `EyeTrace`, `DataPlot1` through `DataPlot4`
- `c`, `dx`, `dy`, `rot` (initially `C` but can be changed)
- juiceVolume
- Assigned by **`openScreen`**
    - `window` (winPtr assigned by `openScreen`)
- Set when initializing a protocol
    - `outputFile`
    - `j` (current trial number)
    - `finish` (max trial number)

Handles also contains the following variables
- State variables
    - runTask, stopTask
- BackImage state variables
    - runOneTrial, runImage, lastRunWasImage
- Subject variables (used to generate output file name in `A`)
    - `outputSubject`, `outputPrefix` (protocol name), `outputDateEdit`, `outputSuffixEdit`
- File paths: `taskPath`, `settingsPath`, `outputPath`
- File names: `settingsFile` (protocol settings)
- `pList` (parameter "name=value") and `pNames` (parameter names)
- `eyeTraceRadius`, `shiftSize`, `gainSize`

## Comments


Longer comments pulled from MarmoV6. This was done to streamline the code and to also consolidate useful information into one place about how MarmoView was designed.



Misc notes:
- RigConfig is reloaded for each protocol
- Pausing and then unpausing sends back to the main run loop so before re-entering loop, it's a good time to check whether user changed any parameters

### Larger comments

**Before loading last calibration**
    
    % AS DEFAULT, THE GUI WILL USE THE CALIBRATION SETTINGS AT THE END OF THE
    % LAST GUI RUN, THIS GUI SUPPORT DATA IS IN THE 'SUPPORT DATA' DIRECTORY,
    % A different calibration file can be loaded, if specified as a field in
    % the settings structure, but any changes made will only be saved to the
    % default 'MarmoViewLastCalib.mat' -- I suspect this won't be used, but
    % could be if two subjects had substantially different eye position gains

**Entering trial loop**

    'pause', 'drawnow', 'figure', 'getframe', or 'waitfor' will allow
    other callbacks to interrupt this run task callback -- be aware that
    if handles aren't properly managed then changes either in the run
    loop or in other parts of the GUI may be out-of-sync. Nothing changes
    to GUI-wide handles until the local callback puts them there. If
    other callbacks change handles, and they are not brought into this
    callback, then those changes are lost when this run loop updates that
    handles. This concept is explained further right below during the
    nextCmd handles management.

**At the end of the trial run, when Data structure is setup:**

    SKETCH OF MY DATA SOLUTION HERE
     D should be a struct that stores per trial data (not everything)
       D.P has trial parameters (struct)
       D.eyeData has the eye trace (matrix)
       D.PR has feedback from the protocol (struct)
          if the protocol is complicated (rev cor), this could be large
          for example, might list every stim shown per frame in trial
       D.C has the eye calibration (struct)
       
     In this scenario, the PR.end_plots does not get D at all.
     What does that mean, if your PR wants to plot stats over trials
     then it must store its own internal D with that information in
     a list .... so the experimenter needs to police this function.
     It will get the P struct and A each trial and can update then.


**When initializing reward delivery**

    TYPICALLY, I PREFER TO HANDLES LARGER/SMALLER REWARDS BY NUMBER OF PULSES
    INSTEAD OF CHANGING THE VOLUME, ALTHOUGH THE VOLUME CAN BE CHANGED, I
    SUGGEST ONLY USING A NUMBER OF JUICE PULSE PARAMETER FOR PROTOCOLS.
    !!!IF YOU DO CHANGE JUICE VOLUME, MAKE SURE THE PUMP IS GIVEN TIME TO
    DELIVER EACH PULSE BEFORE STARTING ON THE NEXT ONE, IT TAKES LONGER TO
    DELIVER A BIG JUICE PULSE THAN A SMALL ONE!!!

**Before initializing reward delivery**

    OPEN UP COMMUNICATION WITH THE PUMP FOR REWARD DELIVERY -- THIS IS DONE
    IMMEDIATELY USING THE RIG SETTINGS, SO THAT JUICE IS AVAILABLE TO THE
    MARMOSET WHILE NO PROTOCOLS ARE LOADED


    Also start a juice counter, for now at 0 -- It will be reset upon loading
    a new protocol and between trials. But it's changed with the give juice
    button, so best to assign it now

**Before setting reward volume**


    TYPICALLY, I PREFER TO HANDLES LARGER/SMALLER REWARDS BY NUMBER OF PULSES
    INSTEAD OF CHANGING THE VOLUME, ALTHOUGH THE VOLUME CAN BE CHANGED, I
    SUGGEST ONLY USING A NUMBER OF JUICE PULSE PARAMETER FOR PROTOCOLS.
    !!!IF YOU DO CHANGE JUICE VOLUME, MAKE SURE THE PUMP IS GIVEN TIME TO
    DELIVER EACH PULSE BEFORE STARTING ON THE NEXT ONE, IT TAKES LONGER TO
    DELIVER A BIG JUICE PULSE THAN A SMALL ONE!!!
