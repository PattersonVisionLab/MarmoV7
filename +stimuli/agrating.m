classdef agrating < handle
% Matlab class for drawing a Gabor grating using the psych. toolbox.
%
% The class constructor can be called with a range of arguments:
%
%   position - center of target (x,y; pixels)
%   radius - radius of target (r; pixels) (if Gabor, 2 sigma within it)
%   orientation - orientation of grating (degs)
%   phase - phase of grating (radians)
%   square - 0 or 1, 1 if square wave grating
%   bkgd - background grey of texture
%   range - offset of max rgb value from bkgd
%
% TODO: Still uint8!

% 14-08-2018 - Jude Mitchell

    properties (Access = public)
        position    double  = [0.0, 0.0] % [x,y] (pixels)
        radius      double  = 50; % (pixels)
        orientation double  = 0;  % horizontal
        cpd         double  = 2; % cycles per degree
        cpd2        double  = NaN; % default not used, else composite stim
        phase       double  = 0;  % (radians)
        square      logical = false;
        ring        logical = false;
        bkgd        double  = 127;
        range       double  = 127;
        gauss       logical = true;  %gaussian aperture
        aspect      double  = 1;  % length along line with aspect > 1
        transparent double  = 0.5;  % from 0 to 1, how transparent
        pixperdeg   double  = 0;  % set non-zero to use for CPD computation
        screenRect          = [];   % if radius Inf, then fill whole area
    end

    properties (Access = private)
        winPtr;     % ptb window
        tex;
        texRect;
        goRect;     % default, define same scale as texture
    end

    methods (Access = public)
        function obj = agrating(winPtr, varargin)
            obj.winPtr = winPtr;
            obj.tex = [];
            obj.texRect = [];
            obj.goRect = [];

            if nargin == 1
                return
            end

            % initialise input parser
            p = inputParser();
            p.StructExpand = true;

            p.addParameter('position', obj.position, @isfloat);
            p.addParameter('radius',obj.radius,@isfloat);
            p.addParameter('orientation',obj.orientation,@isfloat);
            p.addParameter('cpd',obj.cpd,@isfloat);
            p.addParameter('cpd2',obj.cpd2,@isfloat);
            p.addParameter('phase',obj.phase,@isfloat);
            p.addParameter('square',obj.square,@islogical);
            p.addParameter('ring',obj.square,@islogical);
            p.addParameter('gauss',obj.gauss,@islogical);
            p.addParameter('bkgd',obj.bkgd,@isfloat);
            p.addParameter('range',obj.range,@isfloat);
            p.addParameter('pixperdeg',obj.pixperdeg,@isdouble);

            try
                p.parse(varargin{:});
            catch ME
                warning(ME.identifier, "%s", ME.message);
                return
            end

            obj.position = p.Results.position;
            obj.radius = p.Results.radius;
            obj.orientation = p.Results.orientation;
            obj.cpd = p.Results.cpd;
            obj.cpd2 = p.Results.cpd2;
            obj.phase = p.Results.phase;
            obj.square = p.Results.square;
            obj.ring = p.Results.ring;
            obj.aspect = p.Results.aspect;
            obj.gauss = p.Results.gauss;
            obj.bkgd = p.Results.bkgd;
            obj.range = p.Results.range;
            obj.pixperdeg = p.Results.pixperdeg;
        end

        function beforeTrial(obj)
        end

        function beforeFrame(obj)
            obj.drawGrating();
        end

        function afterFrame(obj)
        end

        function updateTextures(obj)
            %****** clear previous texture if updaing
            obj.CloseUp();
            %******** Make Gabor Texture for later use
            if isinf(obj.radius)
                if isempty(obj.screenRect)
                    disp('Must define screenRect to grating class for Inf radius');
                    return;
                end
                [X,Y] = meshgrid(1:obj.screenRect(3),1:obj.screenRect(4));
                e1 = ones(size(X));
            else
                % Find diameter
                rPix = floor(obj.radius);
                dPix = 2*rPix+1;
                % Create a meshgrid
                [X,Y] = meshgrid(-rPix:rPix);
                % Standard deviation of gaussian (e1)
                sigma = dPix/8;
                if (obj.aspect > 1)
                    % Create the gaussian (e1)
                    tX = sin(obj.orientation*pi/180) * X + ...
                        cos(obj.orientation*pi/180) * Y;
                    tY = cos(obj.orientation*pi/180) * X - ...
                        sin(obj.orientation*pi/180) * Y;
                    e1 = exp(-.5*( (tX.^2)*(obj.aspect^2) + tY.^2)/sigma^2);
                else
                    e1 = exp(-.5*( X.^2 + Y.^2)/sigma^2);
                end
                % Convert cycles to max radians (s1)
            end
            if (obj.pixperdeg > 0)
                maxRadians = pi * obj.cpd /obj.pixperdeg;
            else
                maxRadians = pi * obj.cpd / 20;
            end
            % Create the sinusoid (s1)
            pha = obj.phase * pi/180;
            s1 = cos( cos(obj.orientation*pi/180) * (maxRadians*Y) + ...
                sin(obj.orientation*pi/180) * (maxRadians*X) + pha);
            %********** composite grating with two CPD
            if ~isnan(obj.cpd2)
                if (obj.pixperdeg > 0)
                    maxRadians2 = pi * obj.cpd2 /obj.pixperdeg;
                else
                    maxRadians2 = pi * obj.cpd2 / 20;
                end
                s2 = cos( cos(obj.orientation*pi/180) * (maxRadians2*Y) + ...
                    sin(obj.orientation*pi/180) * (maxRadians2*X) + pha);
                s1 = s1 + s2;
            end
            %*********
            % Filter for square wave
            if (obj.square)
                s1( s1 > 0 ) = 1;
                s1( s1 < 0 ) = -1;
            end
            if ~isinf(obj.radius)
                if (obj.square)
                    e1( e1 > 0.01) = 1;
                    e1( e1 <= 0.01) = 0;
                end
                %Create the gabor (g1)
                if (obj.transparent < 0)
                    t1 = (255 * abs(obj.transparent)) * e1;
                else
                    t1 = (obj.transparent * 255) * (e1 > 0.01);
                end
                %***** Gauss window
                if (obj.gauss)
                    g1 = s1.*e1;
                else
                    g1 = s1 .* (e1 > 0.01);
                end
                %***** aperture bounding ring?
                if (obj.ring)
                    z = find( (e1 >= 0.01) & (e1 <= 0.015) );
                    g1(z) = -0.5;
                    t1(z) = 255;
                end
            else
                if (obj.transparent)
                    g1 = s1;
                    t1 = (obj.transparent * 255) * ones(size(X));
                end
            end
            % Convert the gabor (g1) to uint8
            g1 = uint8(obj.bkgd + g1 *obj.range);
            % then define transparency for g-blending
            rim = uint8( zeros(size(g1,1),size(g1,2),4) );
            rim(:,:,1) = g1;
            rim(:,:,2) = g1;
            rim(:,:,3) = g1;
            %**** set transparency
            rim(:,:,4) = uint8(t1);
            % Create the gabor texture
            obj.tex = Screen('MakeTexture',obj.winPtr,rim);

            % Determine the texture placement
            if isinf(obj.radius)
                obj.texRect = [1 1 obj.screenRect(3) obj.screenRect(4)];
            else
                obj.texRect = [0 0 dPix dPix];
                dPix2 = floor(dPix/2);
                obj.goRect = obj.texRect + kron(dPix2,[-1, -1, -1, -1]);
            end
        end

        function CloseUp(obj)
            if ~isempty(obj.tex)
                Screen('Close',obj.tex);
                obj.tex = [];
            end
        end
    end 

    methods (Access = public)
        function drawGrating(obj)
            if (~isempty(obj.tex))
                if isinf(obj.radius)
                    rect = obj.texRect;  % same size as screen itself
                else
                    if ~isempty(obj.goRect)
                        rect = kron([1,1],obj.position) + obj.goRect;  % fast if identical size to texture?
                    else
                        rect = kron([1,1],obj.position) + kron(obj.radius,[-1, -1, +1, +1]);
                    end
                end
                Screen('DrawTexture',obj.winPtr,obj.tex,obj.texRect,rect);
            end
        end
    end
end
