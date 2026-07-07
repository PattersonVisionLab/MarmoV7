function A = openScreen(S, A)
% OPENSCREEN Opens PTB window with parameters specified in S
%
% Syntax:
%   A = marmoview.openScreen(S, A)
%
% History:
%   Original from Jude's MarmoV6
%   14Jun2026 - Added SkipSyncTests for DummyScreen
%   16Jun2026 - Added UseDataPixx
%   22Jun2026 - Removed PsychStartup(), put in startup.m
%   23Jun2026 - Moving to normalized values for PTB! Setup 2
% -------------------------------------------------------------------------

    % Disable PTB welcome screen
    Screen('Preference', 'VisualDebuglevel', 3);

    % close any open windows
    Screen('CloseAll');

    % 22Jun2026 - normalized values (0-1), not 8-bit
    AssertOpenGL;
    PsychDefaultSetup(0);

    % setup the image processing pipeline for ptb
    PsychImaging('PrepareConfiguration');
    if S.DataPixx  % 06.16.2026
        PsychImaging('AddTask', 'General', 'UseDataPixx');
        PsychImaging('AddTask','General','FloatingPoint16Bit');
    else
        PsychImaging('AddTask','General','FloatingPoint16Bit');
    end

    % Applies a simple power-law gamma correction
    PsychImaging('AddTask', 'FinalFormatting',...
        'DisplayColorCorrection', 'SimpleGamma');

    % create the ptb window...
    if isfield(S,'DummyScreen') && S.DummyScreen
        Screen('Preference', 'SkipSyncTests', 1);
        [A.window, A.screenRect] = PsychImaging('OpenWindow',...
            0, S.bgColour, S.screenRect);
    else
        [A.window, A.screenRect] = PsychImaging('OpenWindow',...
            S.screenNumber, S.bgColour);
        % Add gamma correction
        PsychColorCorrection('SetEncodingGamma', A.window, 1 / S.gamma);
        
        % Ensure that the graphics board's gamma table does not transform our pixels
        % Screen('LoadNormalizedGammaTable', A.window, linspace(0, 1, 256)' * [1, 1, 1]);
    end

    A.frameRate = FrameRate(A.window);

    % bump ptb to maximum priority
    A.priorityLevel = MaxPriority(A.window);

    % set alpha blending/antialiasing etc.
    Screen(A.window, 'BlendFunction', GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    % TODO: This should not be here!
    if isfield(S, 'DataPixx') && S.DataPixx
        if Datapixx('IsViewPixx')
            Datapixx('Open');
            cprintf('*[1,0.25,0.25]', '\topenScreen, Opened datapixx');
        end
    end
