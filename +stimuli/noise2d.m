classdef noise2d < handle
    % Matlab class for drawing a moving 2D binary noise (checkerboard) field
    % using the psych. toolbox. Mirrors stimuli.grating, but instead of a
    % sinusoid the pattern is a random binary matrix, and instead of phase
    % the drift is controlled by circularly shifting the pattern by whole
    % squares along x. Constructing several frames that share the same
    % seed but different "shift" values (as done for grating's "phase")
    % produces the same discrete-phase-step drift used elsewhere in the
    % OKN protocols.
    %
    %   position - center of target (x,y; pixels)
    %   radius - radius of target (r; pixels) (Inf to fill screenRect)
    %   squareSize - size of each noise square (degrees)
    %   shift - number of squares to circularly roll the pattern in x
    %   period - number of squares in one full horizontal cycle (must
    %            match across all frames sharing the same seed)
    %   seed - RNG seed used to generate the base binary pattern
    %   bkgd - background grey of texture
    %   range - offset of max rgb value from bkgd

    properties
        % [x, y] (pixels)
        position        double = [0.0, 0.0];
        % Radius of stimulus (Inf to fill screen)
        radius          double = 50; % (pixels)
        % Size of each binary noise square (degrees)
        squareSize      double = 0.2;
        % Number of squares to circularly shift the pattern in x
        shift           double = 0;
        % Number of squares in one full horizontal (tileable) cycle
        period          double = 120;
        % Noise seed. Can be used to recreate stimulus later (0 = random)
        seed            double = 0;
        % Pixel shift to apply to basePattern (only used when basePattern
        % is set; must be a whole multiple of the pixels-per-square)
        shiftPix        double = 0;
        squareAperture  logical = true;
        % Background intensity (normalized, 0-1)
        bkgd            double = 0.5;
        % Peak amplitude offset (normalized, 0-1)
        range           double = 0.5;
        % Whether to create a Gaussian aperture
        gauss           logical = true;
        % How transparent - is this contrast? (0-1)
        transparent     double = 0.5;
        % set non-zero to use for pixels-per-square computation
        pixperdeg       double = 0;
        % Required when radius is Inf
        screenRect = [];
        
        % Pre-computed noise pattern the same length as screen to avoid
        % repeating structure in non-updating noise stimulus drift
        basePattern = [];
    end

    properties (Access = private)
        winPtr; % ptb window
        tex;
        texRect;
        goRect;  % default, define same scale as texture
    end

    methods
        function obj = noise2d(winPtr, pixPerDeg)
            obj.winPtr = winPtr;
            obj.pixperdeg = pixPerDeg;

            obj.tex = [];
            obj.texRect = [];
            obj.goRect = [];
        end

        function tf = validateParameters(obj)
            % If needed, cross-check parameters for internal consistency
            txt = "";
            tf = true;
            if obj.radius == 0 && isempty(obj.screenRect)  
                txt = txt + "ScreenRect must be set to fill screen (radius = 0/inf)";
                tf = false;
            end
            if round(obj.squareSize * obj.pixperdeg) < 1
                txt = txt + "Square size in pixels is less than one";
                tf = false;
            end

            if ~tf                    
                warndlg(txt, "Noise2D parameter conflict");
            end
        end
    end

    methods
        function beforeTrial(obj)
        end

        function beforeFrame(obj)
            obj.drawNoise();
        end

        function afterFrame(obj) %#ok<MANU>
        end

        function updateTextures(obj)
            % Clear  previous texture if updating
            obj.CloseUp();
            % Make sure parameters make sense
            tf = obj.validateParameters();
            if ~tf
                return
            end
            %******** Determine draw area (aperture) in pixels
            if isinf(obj.radius)
                widthPix = obj.screenRect(3);
                heightPix = obj.screenRect(4);
                [X, Y] = meshgrid(1:widthPix, 1:heightPix);
                e1 = ones(size(X));
            else
                rPix = floor(obj.radius);
                dPix = 2 * rPix + 1;
                widthPix = dPix;
                heightPix = dPix;
                [X,Y] = meshgrid(-rPix:rPix);
                sigma = dPix / 8;
                e1 = exp(-.5*(X.^2 + Y.^2) / sigma^2);
            end
            
            if ~isempty(obj.basePattern)
                % Shift existing noise board 
                noiseStim = circshift(obj.basePattern, ...
                    mod(round(obj.shiftPix), size(obj.basePattern,2)), 2);
            else % Create noise board
                pixPerSquare = round(obj.squareSize * obj.pixperdeg);
                
                numSquaresY = ceil(heightPix / pixPerSquare);
                numSquaresX = max(1, round(obj.period));

                noiseStream = RandStream('mt19937ar', 'Seed', obj.seed);
                raw = noiseStream.rand(numSquaresY, numSquaresX);
                
                binaryMat = 2 * double(raw > 0.5) - 1;  
                binaryMat = circshift(binaryMat, mod(obj.shift, numSquaresX), 2);
                % upscale to pixel resolution
                noiseStim = kron(binaryMat, ones(pixPerSquare));
                nRep = ceil(widthPix / size(noiseStim,2));
                noiseStim = repmat(noiseStim, 1, nRep);
            end
            s1 = noiseStim(1:heightPix, 1:widthPix);
            
            % Add decorators
            if ~isinf(obj.radius)
                if (obj.squareAperture)
                    e1( e1 > 0.01) = 1;
                    e1( e1 <= 0.01) = 0;
                end
                if (obj.transparent < 0)
                    t1 = abs(obj.transparent) * e1;
                else
                    t1 = obj.transparent * (e1 > 0.01);
                end
                if (obj.gauss)
                    g1 = s1 .* e1;
                else
                    g1 = s1 .* (e1 > 0.01);
                end
            else
                if (obj.transparent)
                    g1 = s1;
                    t1 = obj.transparent * ones(size(X));
                end
            end
            % Scale based on luminance range (TODO: Use contrast)
            g1 = obj.bkgd + g1 * obj.range;
            % then define transparency for g-blending
            rim = zeros(size(g1,1), size(g1,2),4);
            rim(:,:,1) = g1;
            rim(:,:,2) = g1;
            rim(:,:,3) = g1;
            rim(:,:,4) = t1;

            % Create the noise texture
            obj.tex = Screen('MakeTexture', obj.winPtr, rim);

            % Determine the texture placement
            if isinf(obj.radius)
                obj.texRect = [1 1 obj.screenRect(3) obj.screenRect(4)];
            else
                obj.texRect = [0 0 widthPix heightPix];
                dPix2 = floor(widthPix/2);
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
        function drawNoise(obj)
            if ~isempty(obj.tex)
                if isinf(obj.radius)
                    rect = obj.texRect;  % same size as screen itself
                else
                    if ~isempty(obj.goRect)
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
