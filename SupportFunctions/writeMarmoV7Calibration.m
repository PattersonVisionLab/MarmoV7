function writeMarmoV7Calibration(S, fName)
% WRITEMARMOV7CALIBRATION
%
% Description:
%   Writes last calibration as json for easy reading outside matlab
% -------------------------------------------------------------------------

    arguments
        S           struct
        fName       string      = "MarmoViewLastCalib.json"
    end

    [fPath, ~, ext] = fileparts(fName);
    if isempty(ext)
        fName = fPath + ".json";
    end


    if isempty(fileparts(fName))
        fName = fullfile(getMarmoViewPath(), "SupportData", fName);
    end

    try
        output = struct("c", S.c, "dx", S.dx, "dy", S.dy, "rot", S.rot,...
            "LastModified", datestr('now'));
    catch ME
        warning(ME.identifier, "%s", ME.message);
    end

    writeStruct(output, fName);
