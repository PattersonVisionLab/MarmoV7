classdef BinaryNoise < handle
    properties
        % [x, y] (pixels) -- center of stimulus
        position        double = [0.0, 0.0];
        % radius of aperture (pixels); use Inf for full-field 
        radius          double = Inf;
        % size of each noise square (dva)
        squareSizeDeg   double = 2.5;
        % drift speed (deg/s)
        speedDegPerSec  double = 10;
        % drift direction: +1 = rightward, -1 = leftward (relative to viewer)
        direction       double = 1;
        % contrast: 1 = full black/white, <1 reduces contrast toward bkgd
        contrastLevel   double = 1.0;
        % background/mean gray level, normalized 0-1
        bkgd            double = 0.5;
        % set non-zero to use for CPD computation
        pixperdeg       double = 0;
        % Fallback viewing geometry, only used to compute pixPerDeg when
        % pixperdeg is left at 0 
        screenWidthCm     double = 60;
        screenDistanceCm  double = 75;
        % fixed noise-tile width, in multiples of screen width
        tileWidthMultiplier double = 2;
        % RNG seed for the noise pattern; 'shuffle' for a fresh pattern each updateTextures call
        randSeed = 'shuffle';
        % Required when radius is Inf
        screenRect = [];
    end

    properties (Access = private)
        winPtr;
        tex;
        texRect;
        destRect;
        tileWidthPix;
        tileHeightPix;
        srcRectTop;
        squareSizePix;
        pixPerDegActual;
        trialStartTime;
    end

    methods
        function obj = BinaryNoise(winPtr, varargin)
            obj.winPtr = winPtr;
            obj.tex = [];
            obj.texRect = [];
            obj.destRect = [];

            if nargin == 1
                rng(obj.randSeed); % seed once here also
                return
            end

            p = inputParser();
            p.StructExpand = true;
            p.CaseSensitive = false;
            p.addParameter('position', obj.position, @isfloat);
            p.addParameter('radius', obj.radius, @isfloat);
            p.addParameter('squareSizeDeg', obj.squareSizeDeg, @isfloat);
            p.addParameter('speedDegPerSec', obj.speedDegPerSec, @isfloat);
            p.addParameter('direction', obj.direction, @isfloat);
            p.addParameter('contrastLevel', obj.contrastLevel, @isfloat);
            p.addParameter('bkgd', obj.bkgd, @isfloat);
            p.addParameter('screenWidthCm', obj.screenWidthCm, @isfloat);
            p.addParameter('screenDistanceCm', obj.screenDistanceCm, @isfloat);
            p.addParameter('pixperdeg', obj.pixperdeg, @isfloat);
            p.addParameter('tileWidthMultiplier', obj.tileWidthMultiplier, @isfloat);
            p.addParameter('randSeed', obj.randSeed);
            p.addParameter('screenRect', obj.screenRect);

            try
                p.parse(varargin{:});
            catch ME
                warning(ME.identifier, 'binarynoise: %s', ME.message);
                return;
            end

            obj.position = p.Results.position;
            obj.radius = p.Results.radius;
            obj.squareSizeDeg = p.Results.squareSizeDeg;
            obj.speedDegPerSec = p.Results.speedDegPerSec;
            obj.direction = p.Results.direction;
            obj.contrastLevel = p.Results.contrastLevel;
            obj.bkgd = p.Results.bkgd;
            obj.screenWidthCm = p.Results.screenWidthCm;
            obj.screenDistanceCm = p.Results.screenDistanceCm;
            obj.pixperdeg = p.Results.pixperdeg;
            obj.tileWidthMultiplier = p.Results.tileWidthMultiplier;
            obj.randSeed = p.Results.randSeed;
            obj.screenRect = p.Results.screenRect;

            % Seed the RNG once here
            rng(obj.randSeed);
        end

        function beforeTrial(obj)
            % Called by the trial controller at the start of each trial.
            % Draws a fresh random noise pattern and resets the drift clock.
            obj.updateTextures();
            obj.trialStartTime = GetSecs;
        end

        function beforeFrame(obj, vbl)
            % vbl: optional
            if nargin < 2 || isempty(vbl)
                vbl = GetSecs;
            end
            obj.drawNoise(vbl);
        end

        function afterFrame(obj) 
        end

        function updateTextures(obj)
            % Rebuild the noise texture. Call this once per trial so each trial gets a fresh random pattern
            rng(obj.randSeed); % reseed with THIS trial's seed (set by the protocol before calling beforeTrial), so the pattern is reproducible from randSeed alone
            obj.CloseUp();

            if isinf(obj.radius)
                if isempty(obj.screenRect)
                    disp('Must define screenRect to binary noise class for Inf radius');
                    return;
                end
                screenXpixels = obj.screenRect(3);
                screenYpixels = obj.screenRect(4);
            else
                % Finite radius: treat as a square aperture of side 2*radius
                % centered on position
                screenXpixels = 2 * floor(obj.radius);
                screenYpixels = 2 * floor(obj.radius);
            end

            if (obj.pixperdeg > 0)
                obj.pixPerDegActual = obj.pixperdeg;
            else
                pixPerCm = obj.screenRect(3) / obj.screenWidthCm;
                degPerCm = 2 * atand(1 / (2 * obj.screenDistanceCm));
                obj.pixPerDegActual = pixPerCm / degPerCm;
            end

            obj.squareSizePix = round(obj.squareSizeDeg * obj.pixPerDegActual);
            if obj.squareSizePix < 1
                obj.squareSizePix = 1;
            end

            % Fixed-size tileable texture (independent of speed/duration)
            obj.tileWidthPix = ceil(obj.tileWidthMultiplier * screenXpixels / obj.squareSizePix) * obj.squareSizePix;
            obj.tileHeightPix = ceil((screenYpixels + 2 * obj.squareSizePix) / obj.squareSizePix) * obj.squareSizePix;

            nSquaresX = obj.tileWidthPix / obj.squareSizePix;
            nSquaresY = obj.tileHeightPix / obj.squareSizePix;

            obj.srcRectTop = (obj.tileHeightPix - screenYpixels) / 2;

            if isinf(obj.radius)
                obj.destRect = [0 0 screenXpixels screenYpixels];
            else
                obj.destRect = kron([1,1], obj.position) + kron(obj.radius, [-1, -1, +1, +1]);
            end

            binMat = (rand(nSquaresY, nSquaresX) > 0.5); % random binary (0/1) pattern, drawn right after the per-trial reseed above so it's fully determined by obj.randSeed

            % Map binary values to gray levels using contrastLevel
            loVal = obj.bkgd - obj.bkgd * obj.contrastLevel;
            hiVal = obj.bkgd + (1 - obj.bkgd) * obj.contrastLevel;
            lumMat = loVal + (hiVal - loVal) * binMat;

            noiseImg = kron(lumMat, ones(obj.squareSizePix)); % expand each value into a solid square block of pixels

            obj.tex = Screen('MakeTexture', obj.winPtr, noiseImg);
            obj.texRect = [0 0 obj.tileWidthPix obj.tileHeightPix];
        end

        function CloseUp(obj)
            if ~isempty(obj.tex)
                Screen('Close', obj.tex);
                obj.tex = [];
            end
        end
    end

    methods
        function drawNoise(obj, vbl)
            if isempty(obj.tex)
                return;
            end

            if isempty(obj.trialStartTime)
                obj.trialStartTime = vbl; 
            end

            elapsed = vbl - obj.trialStartTime;
            driftSpeedPixSec = obj.speedDegPerSec * obj.pixPerDegActual;
            % NEGATIVE direction so that direction = +1 is rightward, -1 is leftward
            xOffset = mod(-obj.direction * driftSpeedPixSec * elapsed, obj.tileWidthPix);

            screenXpixels = obj.destRect(3) - obj.destRect(1);
            screenYpixels = obj.destRect(4) - obj.destRect(2);

            remainder = obj.tileWidthPix - xOffset;
            if remainder >= screenXpixels
                srcRect = [xOffset, obj.srcRectTop, xOffset + screenXpixels, obj.srcRectTop + screenYpixels];
                % filterMode=0 forces nearest-neighbor sampling. Without this,
                % PTB's default bilinear filtering blends adjacent texture
                % pixels at the (almost always fractional) xOffset, turning
                % hard black/white square edges into visible gray bands as
                % the texture drifts.
                Screen('DrawTexture', obj.winPtr, obj.tex, srcRect, obj.destRect, 0, 0);
            else
                % Sampling window runs past the tile's right edge -- draw in
                % two pieces (remaining tile content, then wrapped content
                % from the tile's start) for continuous scrolling.
                d1 = [obj.destRect(1), obj.destRect(2), obj.destRect(1) + remainder, obj.destRect(4)];
                s1 = [xOffset, obj.srcRectTop, obj.tileWidthPix, obj.srcRectTop + screenYpixels];
                Screen('DrawTexture', obj.winPtr, obj.tex, s1, d1, 0, 0);

                d2 = [obj.destRect(1) + remainder, obj.destRect(2), obj.destRect(3), obj.destRect(4)];
                s2 = [0, obj.srcRectTop, screenXpixels - remainder, obj.srcRectTop + screenYpixels];
                Screen('DrawTexture', obj.winPtr, obj.tex, s2, d2, 0, 0);
            end
        end
    end
end