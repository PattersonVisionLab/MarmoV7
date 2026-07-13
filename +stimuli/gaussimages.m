classdef gaussimages < handle
    % Matlab class for drawing an image (typically a face) in a Gauss window
    %
    % The class constructor can be called with file name that is a .mat of images
    %  and what is the background gray scale (for Gauss windowing of image)
    %
    %   bkgd  - background gray
    %   gray  - true if gray only, else full color
    %
    % 26-08-2018 - Jude Mitchell
    
    % TODO - figure out why transparency is set to bkgd
    
    properties
        tex;
        texDim;
        imagenum = 0;   %if set zeros, picks at random which to show
        position = [0.0, 0.0]; % [x,y] (pixels)
        radius = 1;  % size in pixels, must be set
        bkgd  = 0.5;  % normalized 0-1
        gray = true;
        transparency  = 0.5;
        contrast  = 1;
    end
    
    properties (Access = private)
        winPtr; % ptb window
    end
    
    methods
        function obj = gaussimages(winPtr, varargin) 
            obj.winPtr = winPtr;
            obj.tex = [];
            obj.texDim = [];
            
            if nargin == 1
                return
            end
            
            % initialise input parser
            ip = inputParser;
            ip.CaseSensitive = false;
            ip.StructExpand = true;
            
            ip.addParameter('Position', obj.position, @isfloat);
            ip.addParameter('Radius', obj.radius, @isfloat);
            ip.addParameter('Gray', obj.gray, @islogical);
            ip.addParameter('Bkgd', obj.bkgd, @isfloat);
            ip.addParameter('Imagenum', obj.imagenum, @isfloat);
            ip.addParameter('transparency', obj.transparency, @isfloat);
            
            try
                ip.parse(varargin{:});
            catch ME
                warning(ME.identifier, '%', ME.message);
                return;
            end
            
            obj.position = ip.Results.Position;
            obj.radius = ip.Results.Radius;
            obj.gray = ip.Results.Gray;
            obj.bkgd = ip.Results.Bkgd;
            obj.transparency = ip.Results.transparency;
        end
        
        function obj = loadimages(obj, fName)

            F = load(fName);
            images = fields(F);
            n = length(images);
            obj.tex = nan(n,1);
            obj.texDim = nan(n,1);
            for i = 1:n
                imo = double(F.(images{i})) / 255;  % uint8 --> 0-1
                obj.texDim(i) = length(imo);
                [x,y] = meshgrid((1:obj.texDim(i))-obj.texDim(i)/2);
                g = exp(-(x.^2+y.^2)/(2*(obj.texDim(i)/6)^2));
                g = repmat(g,[1 1 3]);
                im = (g.*imo) + obj.bkgd*(1-g);
                if (obj.gray)
                    im = squeeze(mean(im,3));  % go to grayscale
                end

                % then define transparency for g-blending (alpha, 0-1)
                if (obj.transparency > 0)
                    t1 = double(squeeze(mean(g,3)) > 0.05);
                else
                    t1 = squeeze(mean(g,3));
                end
                rim = zeros(size(im,1),size(im,2),4);
                rim(:,:,1) = im(:,:,1);
                rim(:,:,2) = im(:,:,2);
                rim(:,:,3) = im(:,:,3);
                %**** set transparency
                rim(:,:,4) = t1;
                % Create the gauss texture (normalized 0-1, matches PsychDefaultSetup(2))
                obj.tex(i) = Screen('MakeTexture', obj.winPtr, rim);

                %**** initialize default radius based on last loaded image size
                obj.radius = length(imo);
            end
        end
        
        function CloseUp(obj)
            if ~isempty(obj.tex)
                for i = 1:size(obj.tex,1)
                    Screen('Close',obj.tex(i));
                end
                obj.tex = [];
            end
        end
        
        function beforeTrial(~)
        end
        
        function beforeFrame(obj)
            if (obj.imagenum)
                obj.drawGaussImage(obj.imagenum);
            else
                rd = randi(length(obj.tex));
                obj.drawGaussImage(rd);
            end
        end
        
        function afterFrame(~)
        end
        
        function drawGaussImage(obj, imagenum)
            if ( (imagenum>0) && (imagenum <= size(obj.tex,1)) )
                if (~isempty(obj.tex(imagenum)))
                    rect = kron([1,1],obj.position) + kron(obj.radius,[-1, -1, +1, +1]);
                    texrect = [0 0 obj.texDim(imagenum) obj.texDim(imagenum)];
                    if (obj.contrast > 0)
                        % use transparency to change contrast
                        Screen('DrawTexture',obj.winPtr,...
                            obj.tex(imagenum), texrect, rect, 0, 0, obj.contrast);  
                    end
                end
            end
        end
    end
end
