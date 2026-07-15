# CHANGELOG
Key changes to the core functionality of MarmoView

### 7/15/2026
- Switched to __MarmoV7__, have to change repo name etc to avoid future conflicts
- Removing use8Bit option entirely

### 7/12/2026
- Migrated to `PsychDefaultSetup(2)`. Core protocols work now
- Added duty cycle option to `PR_Speed_Motion_OKN`

### 6/24/2026
- Thorlabs Kinesis motor syringe pump class is working (TODO: Polling!!!)

### 6/22/2026
- Assumes `PsychStartup` is called by computer's `startup.m`. No longer calling inside marmoview

### 6/18/2026
- Eyetracking with Trackpixx is up and running

### 6/16/2026
- Added `'UseDatapixx'` to PTB tasks in `openScreen.m`
- Replaced `eval` commands with `str2func` for clarity. Takes a moment when first called, but very fast for subsequent calls. 
