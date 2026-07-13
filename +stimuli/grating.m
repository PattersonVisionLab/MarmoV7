classdef grating < handle
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

    % 14-08-2018 - Jude Mitchell

    properties
        % [x, y] (pixels)
        position        double = [0.0, 0.0];
        radius          double = 50; % (pixels)
        orientation     double = 0;  % horizontal
        cpd             double = 2; % cycles per degree
        % Optional: cycles/degree for secondary grating (NaN = off)
        cpd2            double = NaN;
        % Grating phase in degrees
        phase           double = 0;  
        square          logical = false;
        % Fraction of the cycle that is "bright"
        dutyCycle       double = 0.5;
        squareAperture  logical = false;
        ring            logical = false;
        % Background intensity (normalized, 0-1)
        bkgd            double = 0.5;
        % Peak amplitude (normalized, 0-1)
        range           double = 0.5;
        % Whether to create a Gaussian aperture
        gauss           logical = true; 
        % How transparent - is this contrast? (0-1)
        transparent     double = 0.5;
        % set non-zero to use for CPD computation
        pixperdeg       double = 0;
        % Required when radius is Inf
        screenRect = [];  
    end

    properties (Access = private)
        winPtr; % ptb window
        tex;
        texRect;
        goRect;  % default, define same scale as texture
    end

    methods
        function obj = grating(winPtr, varargin)
            obj.winPtr = winPtr;
            obj.tex = [];
            obj.texRect = [];
            obj.goRect = [];

            if nargin == 1
                return
            end

            p = inputParser();
            p.StructExpand = true;
            p.CaseSensitive = false;
            p.addParameter('position', obj.position, @isfloat);
            p.addParameter('radius', obj.radius, @isfloat);
            p.addParameter('orientation', obj.orientation, @isfloat);
            p.addParameter('cpd', obj.cpd, @isfloat);
            p.addParameter('cpd2', obj.cpd2, @isfloat);
            p.addParameter('phase', obj.phase, @isfloat);
            p.addParameter('square', obj.square, @islogical);
            p.addParameter('dutyCycle', obj.dutyCycle, @isfloat);
            p.addParameter('ring', obj.square, @islogical);
            p.addParameter('gauss', obj.gauss, @islogical);
            p.addParameter('bkgd', obj.bkgd, @isfloat);
            p.addParameter('range', obj.range, @isfloat);
            p.addParameter('pixperdeg', obj.pixperdeg, @isdouble);

            try
                p.parse(varargin{:});
            catch ME
                warning(ME.identifier, 'grating: %s', ME.message);
                return;
            end

            f = fieldnames(p.Results);
            for i = 1:numel(f)
                obj.(f{i}) = p.Results(f{i});
            end
        end

        function beforeTrial(obj) %#ok<MANU>
        end

        function beforeFrame(obj)
            obj.drawGrating();
        end

        function afterFrame(obj) %#ok<MANU>
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
                [X, Y] = meshgrid(1:obj.screenRect(3),  1:obj.screenRect(4));
                e1 = ones(size(X));
            else
                % Find diameter
                rPix = floor(obj.radius);
                dPix = 2 * rPix + 1;
                % Create a meshgrid
                [X,Y] = meshgrid(-rPix:rPix);
                % Standard deviation of gaussian (e1)
                sigma = dPix / 8;
                % Create the gaussian (e1)
                e1 = exp(-.5*(X.^2 + Y.^2) / sigma^2);
                % Convert cycles to max radians (s1)
            end
            if (obj.pixperdeg > 0)
                maxRadians = 2 * pi * obj.cpd /obj.pixperdeg;
            else
                maxRadians = 2 * pi * obj.cpd / 20;
            end
            % Create the sinusoid (s1)
            theta = obj.phase * pi/180;
            s1 = cos( cos(obj.orientation*pi/180) * (maxRadians*Y) + ...
                sin(obj.orientation*pi/180) * (maxRadians*X) + theta);
            %********** composite grating with two CPD
            if ~isnan(obj.cpd2)
                if (obj.pixperdeg > 0)
                    maxRadians2 = pi * obj.cpd2 /obj.pixperdeg;
                else
                    maxRadians2 = pi * obj.cpd2 / 20;
                end
                s2 = cos( cos(obj.orientation*pi/180) * (maxRadians2*Y) + ...
                    sin(obj.orientation*pi/180) * (maxRadians2*X) + theta);
                s1 = s1 + s2;
            end
            %*********
            % Filter for square wave
            if (obj.square)
                if obj.dutyCycle == 0.5
                    s1( s1 > 0 ) = 1;
                    s1( s1 < 0 ) = -1;
                else
                    dutyCycleThreshold = cos(pi * obj.dutyCycle);
                    s1( s1 > dutyCycleThreshold ) = 1;
                    s1( s1 <= dutyCycleThreshold ) = -1;
                end
            end
            if ~isinf(obj.radius)
                if (obj.squareAperture)
                    e1( e1 > 0.01) = 1;
                    e1( e1 <= 0.01) = 0;
                end
                %Create the gabor (g1)
                if (obj.transparent < 0)
                    t1 = abs(obj.transparent) * e1;
                else
                    t1 = obj.transparent * (e1 > 0.01);
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
                    t1(z) = 1;
                end
            else
                if (obj.transparent)
                    g1 = s1;
                    t1 = obj.transparent * ones(size(X));
                end
            end
            % Scale gabor (g1) to normalized [0,1]
            g1 = obj.bkgd + g1 * obj.range;
            % then define transparency for g-blending
            rim = zeros(size(g1,1), size(g1,2),4);
            rim(:,:,1) = g1;
            rim(:,:,2) = g1;
            rim(:,:,3) = g1;
            %**** set transparency
            rim(:,:,4) = t1;
            % Create the gabor texture
            obj.tex = Screen('MakeTexture', obj.winPtr, rim);

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
                Screen('Close', obj.tex);
                obj.tex = [];
            end
        end
    end

    methods
        function drawGrating(obj)
            if ~isempty(obj.tex)
                if isinf(obj.radius)
                    rect = obj.texRect;  % same size as screen itself
                else
                    if ~isempty(obj.goRect)
                        % fast if identical size to texture?
                        rect = kron([1,1],obj.position) + obj.goRect;
                    else
                        rect = kron([1,1],obj.position) + kron(obj.radius,[-1, -1, +1, +1]);
                    end
                end
                Screen('DrawTexture', obj.winPtr, obj.tex, obj.texRect, rect);
            end
        end
    end
end
