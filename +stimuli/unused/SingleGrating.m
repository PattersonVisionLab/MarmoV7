classdef SingleGrating < handle
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
        % Grating phase in degrees
        phase           double = 0;  
        square          logical = false;
        squareAperture  logical = false;
        ring            logical = false;
        % Background intensity (normalized, 0-1)
        bkgd            double = 127;
        % Peak amplitude (normalized, 0-1)
        range           double = 127;
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
        function obj = SingleGrating(winPtr, varargin)
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
            p.addParameter('phase', obj.phase, @isfloat);
            p.addParameter('square', obj.square, @islogical);
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

            obj.position = p.Results.position;
            obj.radius = p.Results.radius;
            obj.orientation = p.Results.orientation;
            obj.cpd = p.Results.cpd;
            obj.phase = p.Results.phase;
            obj.square = p.Results.square;
            obj.ring = p.Results.ring;
            obj.gauss = p.Results.gauss;
            obj.bkgd = p.Results.bkgd;
            obj.range = p.Results.range;
            obj.pixperdeg = p.Results.pixperdeg;
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
            
            %*********
            % Filter for square wave
            if (obj.square)
                s1( s1 > 0 ) = 1;
                s1( s1 < 0 ) = -1;
            end
            if ~isinf(obj.radius)
                if (obj.squareAperture)
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
            rim = uint8(zeros(size(g1,1), size(g1,2),4));
            rim(:,:,1) = g1;
            rim(:,:,2) = g1;
            rim(:,:,3) = g1;
            %**** set transparency
            rim(:,:,4) = uint8(t1);
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
