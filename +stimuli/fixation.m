classdef fixation < handle
    % Matlab class for drawing fixation target(s) using the psych. toolbox.
    %
    % The fixation target consists of a central circular target and a
    % concentric circular surround (usually contrasting). The size and colour
    % of both the centre and surround can be configured independently.
    %
    % The class constructor can be called with a range of arguments:
    %
    %   centreSize - diameter of centre (pixels)
    %   surroundRadius - diameter of surround (pixels)
    %   centreColour - colour of centre (clut index or [r,g,b])
    %   surroundColour - colour of surround (clut index or [r,g,b])
    %   position - center of target (x,y; pixels)
    
    % 16-06-2016 - Shaun L. Cloherty <s.cloherty@ieee.org>
    % 12-07-2026 - SSP, added switches, descriptions, and cut extra calls

    properties 
        % Diameter of target center, pixels
        cSize = 2; % pixels
        % Diameter of surround ring for target, pixels
        sSize = 4; % pixels
        % Extra larger area around target, pixels
        oSize = 8;
        cColour = [0 0 0]; 
        sColour = [1 1 1];
        sbColour = [0 0 0];
        % Position on the screen, [x, y] pixels
        position = [0, 0];
    end
    
    properties (Access = private)
        winPtr; % ptb window
    end
    
    methods
        function obj = fixation(winPtr, varargin)
            obj.winPtr = winPtr;
            
            if nargin == 1
                return
            end
            
            % initialise input parser
            p = inputParser();
            p.StructExpand = true;
            p.CaseSensitive = false;
            p.addParameter('centreSize', obj.cSize, @isfloat); 
            p.addParameter('surroundSize', obj.sSize, @isfloat);
            p.addParameter('centreColour', obj.cColour, @isfloat); 
            p.addParameter('surroundColour',obj.sColour, @isfloat);
            p.addParameter('surroundColourBlack', obj.sbColour, @isfloat);
            p.addParameter('position', obj.position, @isfloat); 
            
            try
                p.parse(varargin{:});
            catch ME
                warning(ME.id, '%s', ME.message);
                return;
            end
            
            obj.cSize = p.Results.centreSize;
            obj.sSize = p.Results.surroundSize;
            obj.cColour = p.Results.centreColour;
            obj.sColour = p.Results.surroundColour;
            obj.sbColour = p.Results.surroundColourBlack;
            obj.position = p.Results.position;
        end
        
        function beforeTrial(~)
        end
        
        function beforeFrame(obj, state)
            obj.drawFixation(state);
        end
        
        function afterFrame(~)
        end
        
        function updateTextures(~)
        end
        
        function CloseUp(~)
        end
    end 
    
    methods 
        function drawFixation(obj, state)
            switch state
                case 1  %normal black center, white outline
                    r = floor(obj.sSize ./ 2); % radius in pixels
                    rect = kron([1,1], obj.position) + kron(r(:),[-1, -1, +1, +1]);
                    Screen('FillOval', obj.winPtr, obj.sColour, rect');
                    r = floor(obj.cSize ./ 2);
                    rect = kron([1,1],obj.position) + kron(r(:),[-1, -1, +1, +1]);
                    Screen('FillOval', obj.winPtr, obj.cColour, rect');
                case 2   %larger white empty point
                    r = floor(2 * obj.cSize);
                    rect = kron([1, 1], obj.position) + kron(r(:), [-1, -1, +1, +1]);
                    Screen('FrameOval', obj.winPtr, obj.sColour, rect', floor(r/4));
                case 3  %all black filled fixation point
                    r = floor(obj.cSize ./ 2);
                    rect = kron([1, 1], obj.position) + kron(r(:),[-1, -1, +1, +1]);
                    Screen('FillOval', obj.winPtr, obj.cColour, rect');
                case 4   %larger black empty point
                    r = floor(2 * obj.oSize);
                    rthin = floor( 2 * obj.cSize);
                    rect = kron([1, 1], obj.position) + kron(r(:), [-1, -1, +1, +1]);
                    Screen('FrameOval', obj.winPtr, obj.sbColour, rect', floor(rthin/4));
            end
        end
    end 
end 
