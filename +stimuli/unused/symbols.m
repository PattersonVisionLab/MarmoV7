classdef symbols < handle
  % Matlab class for drawing circles using the psych. toolbox.
  %
  % The class constructor can be called with a range of arguments:
  %
  %   size     - diameter (pixels)
  %   weight   - line weight (pixels)
  %   colour   - line colour (clut index or [r,g,b])
  %   position - center of aperture (x,y; pixels)
  
  % 14-06-2016 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties (Access = public),
    size = 0; % pixels
    type = 1; % circle for 1, square for 2, triangle 3, diamond 4
    colour = ones([1,3]); % clut index or [r,g,b]
    position = [0.0, 0.0]; % [x,y] (pixels)
  end
        
  properties (Access = private)
    winPtr; % ptb window
  end
  
  methods (Access = public)
    function o = symbols(winPtr,varargin), % marmoview's initCmd?
      o.winPtr = winPtr;
      
      if nargin == 1,
        return
      end

      % initialise input parser
      args = varargin;
      p = inputParser;
%       p.KeepUnmatched = true;
      p.StructExpand = true;
      p.addParamValue('size',o.size,@isfloat); % pixels
      p.addParamValue('type',o.type,@isfloat); % pixels
      p.addParamValue('colour',o.colour,@isfloat); % clut index or [r,g,b]
      p.addParamValue('position',o.position,@isfloat); % [x,y] (pixels)
                  
      try
        p.parse(args{:});
      catch,
        warning('Failed to parse name-value arguments.');
        return;
      end
      
      args = p.Results;
    
      o.size = args.size;
      o.type = args.type;
      o.colour = args.colour;
      o.position = args.position;
    end
        
    function beforeTrial(o), % marmoview's nextCmd?
    end
    
    function beforeFrame(o) % Run to draw object
      o.drawSymbols();
    end
        
    function afterFrame(o) % Run to update object
    end
    
    function updateTextures(o)  % no textures for this stimulus
    end
    
    function CloseUp(o)
    end
    
  end % methods
    
  methods (Access = public)        
    function drawSymbols(o),
        
      r = floor(o.size./2); % radius in pixels
      rect = kron([1,1],o.position) + kron(r(:),[-1, -1, +1, +1]);
      
      if (o.type == 1)  % circle
          Screen('FillOval',o.winPtr,o.colour,rect');
      end
      if (o.type == 2)  % draw a square
         r = floor(o.size./2); % radius in pixels
         %**** rect is [x1 y1 x2 y2] where x1,y1 is lower left corner,
         %****    and x2,y2 is upper right corner
         rect = kron([1,1],o.position) + kron(r(:),[-1, -1, +1, +1]);
         ptlist = [[rect(1),rect(2)]; [rect(1),rect(4)]; [rect(3),rect(4)]; ...
                   [rect(3),rect(2)]; [rect(1),rect(2)] ];
         Screen('FillPoly',o.winPtr,o.colour,ptlist);
      end
      %***** if triangle, diamond ..... need to figure how to draw
      %***** these types of stimuli
       if (o.type == 3) % draw a triangle
          r = floor(o.size./2); % radius in pixels
          rect = kron([1,1], o.position) + kron(r(:),[-1, -1, +1, +1]);
          ptlist = [[rect(1),rect(4)];[rect(3), rect(4)];...
                    [[rect(1) + rect(3)]./2, [rect(2) + rect(2)]./2]; [rect(1),rect(4)]];
          Screen('FillPoly',o.winPtr, o.colour,ptlist); 
       end
      if (o.type == 4) % draw a diamond
          r = floor(o.size./2); %radius in pixels
          rect = kron([1,1], o.position) + kron(r(:), [-1, -1, +1, +1]);
          ptlist = [[[rect(1)+rect(3)]./2, [rect(4)+rect(4)]./2];...
                    [[rect(1)+rect(1)]./2, [rect(4)+rect(2)]./2];...
                    [[rect(1)+rect(3)]./2, [rect(2)+rect(2)]./2];...
                    [[rect(3)+rect(3)]./2, [rect(2)+rect(4)]./2];...
                    [[rect(1)+rect(3)]./2, [rect(4)+rect(4)]./2]];
          Screen('FillPoly', o.winPtr, o.colour, ptlist);
      end
      if (o.type == 5) % draw a cross (two rectangles)
          r = floor(o.size./2); %radius in pixels
          rect = kron([1,1], o.position) + kron(r(:), [-1, -0.4, +1, +0.4]);
          ptlist = [[rect(1),rect(2)]; [rect(1),rect(4)]; [rect(3),rect(4)]; ...
                   [rect(3),rect(2)]; [rect(1),rect(2)] ];
          Screen('FillPoly',o.winPtr,o.colour,ptlist);
          rect = kron([1,1], o.position) + kron(r(:), [-0.4, -1, +0.4, +1]);
          ptlist = [[rect(1),rect(2)]; [rect(1),rect(4)]; [rect(3),rect(4)]; ...
                   [rect(3),rect(2)]; [rect(1),rect(2)] ];
          Screen('FillPoly',o.winPtr,o.colour,ptlist);
      end      
    end
    
  end % methods
  
end % classdef
