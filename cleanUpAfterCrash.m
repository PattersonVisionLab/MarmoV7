function cleanUpAfterCrash()

    % Psychtoolbox
    Screen('Closeall'); sca;

    try
        tpx = Datapixx('GetTpxStatus');
    catch
        % If error, then Datapixx is not open
        return
    end

    if tpx.IsRecording
        Datapixx('StopTpxSchedule');
        Datapixx('RegWrRd');
    end

    if tpx.newBufferFrames > 0
        fprintf('Clearing %u new buffer frames\n', tpx.newBufferFrames);
        Datapixx('ReadTPxData', tpx.newBufferFrames);
    end


    Datapixx('SetTpxSleep');
    Datapixx('RegWrRd');

    Datapixx('Close');
