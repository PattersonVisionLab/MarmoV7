classdef eyetrack_trackpixx < handle

    properties (SetAccess = private)
        whichEye            (1,1)   string = "right"
        ledIntensity        (1,1)   double
        expectedIrisSize    (1,1)   double
    end

    properties
        EyeDump             (1,1)   logical
        eyeFile = []
        eyePath = []
    end

    properties (SetAccess = private)
        isAwake     (1,1)       logical     = false
    end

    % Magic numbers and future parameters
    properties (Hidden, Constant)
        LENS = 3;
        SPECIES = 1;
    end

    methods
        function obj = eyetrack_trackpixx(~, varargin) 

            ip = inputParser();
            ip.KeepUnmatched = true;
            ip.CaseSensitive = false;
            addParameter(ip, 'LedIntensity', 8, @isnumeric);
            addParameter(ip, 'ExpectedIrisSize', 115, @isnumeric);
            addParameter(ip, 'EyeDump', true, @islogical); 
            parse(ip, varargin{:});

            obj.EyeDump = ip.Results.EyeDump;
            obj.ledIntensity = ip.Results.LedIntensity;
            obj.expectedIrisSize = ip.Results.ExpectedIrisSize;

            obj.initialize();
        end
        
        function setEye(obj, whichEye)
            if ~ismember(whichEye, "right", "left")
                warning('setEye had invalid input');
                disp(whichEye);
                return
            end
            obj.whichEye = whichEye;
        end

        function initialize(obj)
            cprintf('_[0.7,0.3,0.5]', '\tTrackpixx, call initialize\n');
            Datapixx('Open');
            Datapixx('SetTPxAwake');
            obj.isAwake = true;
            Datapixx('SetTrackingSpecies', 1);  % NHP
            Datapixx('SetLens', 3);  % 75 mm
            %Datapixx('SetLedIntensity', obj.ledIntensity);
            %Datapixx('SetExpectedIrisSizeInPixels', obj.expectedIrisSize);
            Datapixx('RegWrRd');
        end

        function startfile(~, ~)
            Datapixx('Open');
            Datapixx('SetupTPxSchedule');
            Datapixx('RegWrRd');
        end
        
        function tpxData = getDataOnBuffer(obj)
            cprintf('_[0.7,0.3,0.5]', '\tTrackpixx, call getDataOnBuffer\n');
            
            if ~obj.EyeDump
                tpxData = [];
                return
            end
            tpxData = trackpixx.readTrackpixxBuffer();
        end

        function closefile(obj)
            cprintf('_[0.7,0.3,0.5]', '\tTrackpixx, call closeFile\n');
            Datapixx('SetTpxSleep');
            Datapixx('RegWrRd');
            obj.isAwake = false;
            Datapixx('Close');
        end

        function unpause(~)
            cprintf('_[0.7,0.3,0.5]', '\tTrackpixx, call unpause\n');
            Datapixx('StartTpxSchedule');
            Datapixx('RegWrRd');
        end

        function pause(~)
            cprintf('_[0.7,0.3,0.5]', '\tTrackpixx, call pause\n');
            Datapixx('StopTpxSchedule');
            Datapixx('RegWrRd');
        end

        function [x, y] = getgaze(obj)
            % GETGAZE  Runs each frame flip
            if ~obj.EyeDump
                x = 0; y = 0;
                return
            end

            [~, ~, ~, ~, xRawRight, yRawRight, xRawLeft, yRawLeft, ~] = ...
                Datapixx('GetEyePosition');
         
            if obj.whichEye == "right"
                x = xRawRight ;
                y = 1 - (yRawRight );
            else
                x = xRawLeft;
                y = 1 - (yRawLeft);
            end
        end

        function r = getpupil(obj)
            % GETPUPIL  Runs each frame flip
            if obj.EyeDump
                r = Datapixx('GetPupilSizeSimple');
            else
                r = 1;
            end
        end

        function sendcommand(obj, tstring)
            cprintf('_[0.5,0.5,0.5]', '\t\tTrackpixx, call sendcommand %s\n', tstring);
        end

    end 

    methods  (Static) % Extra trackpixx methods
        function setLedIntensity(value)
            Datapixx('SetLedIntensity', value);
        end

        function value = getLedIntensity()
            value = Datapixx('GetLedIntensity');
        end

        function img = getEyeImage()
            img = Datapixx('GetEyeImage');
        end
    end
end 
