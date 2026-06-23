classdef KinesisMotorSyringe < marmoview.liquid
% KINESISSYRINGE
%
% Properties to define in rig settings:
%   - serialNumber      (e.g., '26000001')
%   - controllerType    (e.g., 'KST201')
%   - stageName         (e.g., 'HS Z912B')
%   - syringeDiameter   in mL
%   - moveDirection     -1 or 1
%   - stepSize          in mm
% -------------------------------------------------------------------------

    properties
        volume   
    end

    properties (SetAccess = private)
        DEVICE
        moveDirection   (1,1)   string      {mustBeMember(moveDirection, ["up", "down"])} = "up"
        stepSize        (1,1)   double 
        % The diameter of the syringe in mm, dictates mm -> ml mapping
        syringeDiameter (1,1)   double
        verbose         (1,1)   logical = true
        totalVolume
    end

    properties (Dependent)
        position
        positionLimits
    end

    methods
        function obj = KinesisMotorSyringe(h, device, varargin)
            obj = obj@marmoview.liquid(h);
            obj.DEVICE = device;
            obj.totalVolume = 0;

            ip = inputParser();
            ip.CaseSensitive = false;
            addParameter(ip, 'MoveDirection', "down", @(x) ismember(x, ["up", "down"]));
            addParameter(ip, 'StepSize', 0.01, @isnumeric);
            addParameter(ip, 'SyringeDiameter', 10, @isnumeric);
            parse(ip, varargin{:});

            obj.moveDirection = ip.Results.MoveDirection;
            obj.stepSize = ip.Results.StepSize;
            obj.syringeDiameter = ip.Results.SyringeDiameter;

            obj.initialize();
        end

        function set.volume(obj, value)
            obj.volume = value;
            obj.setStepSize(obj.ml2mm(value), false);
        end

        function deliver(obj)
            obj.DEVICE.jog(obj.moveDirection);
            if obj.verbose
                fprintf('\n\nNew motor position: %.3f\n', obj.position);
            end
        end

        function r = report(~)
            r.totalVolume = obj.totalVolume;
        end

        function txt = getVolumeText(obj, value)
            if nargin < 2
                value = obj.volume * 1000;  % uL
            end
            txt = fprintf('%3id uL', value);
        end

        function ml = mm2ml(obj, mm)
            ml = obj.syringeDiameter * pi * mm;
        end

        function mm = ml2mm(obj, ml)
            mm = (obj.syringeDiameter * pi) / ml;
        end
    end

    methods
        function home(obj)
            obj.DEVICE.home();
        end

        function retract(obj)
            switch obj.moveDirection
                case "up"
                    obj.DEVICE.move(0);
                case "down" 
                    obj.DEVICE.move(obj.positionLimits(end))
            end
        end

        function setStepSize(obj, value, updateVolume)
            % updateVolume option prevents circular calls with volume setter
            if narign < 3
                updateVolume = true;
            end
            obj.DEVICE.setJogStepSize(value);
            obj.stepSize = value;
            if updateVolume
                obj.volume = obj.mm2ml(value);
            end
            fprintf('Set kinesis step size to %.4f\n', obj.stepSize);
        end

        function disconnect(obj)
            obj.DEVICE.disconnect();
        end
    end

    methods (Access = private)
        function initialize(obj)
            obj.setStepSize(obj.stepSize);

            if ~obj.DEVICE.isHomed
                warndlg('Motor controller is not homed! Run home method');
            end
        end
    end

    % Dependent set/get methods
    methods
        function value = get.position(obj)
            value = obj.DEVICE.position;
        end

        function value = get.positionLimits(obj)
            value = [0 obj.DEVICE.maxPosition];
        end
    end
end
