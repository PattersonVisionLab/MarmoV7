classdef patchdots < handle
  % Matlab class for drawing a patch of random dots.
  %
  % The class constructor can be called with a range of arguments:
  %
  %   size       - dot size (pixels)
  %   speed      - dot speed (pixels/frame),
  %   direction  - radians
  %   numDots    - number of dots
  %   mode       - 0: proportion
  %                1: distribution
  %   coherence  - dot coherence (0-1) (mode = 0)
  %   dist       - 0: gaussian (mode = 1)
  %                1: uniform (mode = 1)
  %   bandwdth   - width of gaussian/uniform noise (mode = 1)
  %   lifetime   - limit of dot lifetime (frames)
  %   minRadius  - minimum radius of aperture (pixels)
  %   maxRadius  - maximum radius of aperture (pixels)
  %   position   - aperture position (x,y; pixels)
  %********
  %***** define a local patch where motion is uniform (not random)
  %   patchN - number of local patch motions
  %   patch - cell array, each with local aperture (x,y,width,direction; pixels, degs)
  
  % 14-06-2016 - Shaun L. Cloherty <s.cloherty@ieee.org>
  
  properties (Access = public),
    size@double; % pixels
    speed@double; % pixels/s
    bspeed@double; % pixels/s
    direction@double; % radians (?)
    numDots@double;
    coherence@double; % pcnt coherence (0-1)
    mode@double; % 0 = proportion, 1 = distribution
    dist@double; % 0 = gaussian, 1 = uniform
    bandwdth@double; % width of gaussian/uniform noise.
    lifetime@double; % dot lifetime (frames)
%     minRadius@double; % minimum radius (pixels)
    truncateGauss = -1;
    maxRadius@double; % maximum radius (pixels)
    Xtop@double; % max X (pixels)
    Xbot@double; % min X (pixels)
    Ytop@double; % max Y (pixels)
    Ybot@double; % min Y (pixels)
    PatchRef = [];  % list which dots are in patch (for color)
    PatchColor = 0;  % if zero, same as other dots
    BackColor = 0;
    position@double; % aperture position (x,y; pixels)
    colour@double;
    bkgd = 127;  % background gray
    visible@logical = true; % are the dots visible
    gaussian@logical = false;
    %*****
    updateCount = 0;  % count updates (BeforeFrame) calls
    HistoryCnt = 0;  % count log changes, catalog the frame they occur
    History = []; % from the TrialStart call, log all changes to patches
                  % and ideally, any other object parameter changes too
                  % but here I'm assuming only patches change over a trial
                  % NOTE: not true if you decide to change random
                  % background, then would have to log those changes too
                  %
  end
    
  properties (Access = public) %private)
    % polar ocordinates (relative to center of aperture)
    radius; % deg.
    theta;  % deg.

    % cartessian coordinates (relative to center of aperture?)
    x; % x coords (pixels)
    y; % y coords (pixels)
    
    % cartesian displacements
    dx; % pixels per frame?
    dy; % pixels per frame?
    
    % frames remaining
    frameCnt;
  end
    
  properties (Access = private)
    winPtr; % ptb window
    %****** force a function to change thses, so we can track history
    %****** from the object's TrialStart
    PatchN = 0;
    Patch = []; % local aperture position (x,y,width; pixels)
    %******* random number generator for this class alone
    myrand = [];  % random number stream, will use to generate rand etc...
    %*******
  end
  
  methods (Access = public)
    function o = patchdots(winPtr,varargin), % marmoview's initCmd
      o.winPtr = winPtr;
      
      o.myrand = RandStream('twister','Seed',randi(1000));
      
      if nargin == 1,
        return
      end

      % initialise input parser
      args = varargin;
      p = inputParser;
%       p.KeepUnmatched = true;
      p.StructExpand = true;
      p.addParamValue('size',10.0,@double); % pixels?
      p.addParamValue('speed',0.2,@double); % deg./s
      p.addParamValue('direction',0.0,@(x) isscalar(x) && isreal(x)); % deg.
      p.addParamValue('numDots',200,@(x) ceil(x));

      p.addParamValue('mode',0,@(x) any(ismember(x,[0, 1]))); % 0 = proportion, 1 = distribution      

      % mode = 0
      p.addParamValue('coherence',1.0,@(x) isscalar(x) && isreal(x)); % 0..1
      
      % mode = 1
      p.addParamValue('dist',0,@(x) any(ismember(x,[0, 1]))); % 0 = gaussian, 1 = uniform
      p.addParamValue('bandwdth',20.0,@(x) isscalar(x) && isreal(x)); % bandwidth (deg.)

      
      p.addParamValue('lifetime',Inf,@double);

%       p.addParamValue('minRadius',0.0,@double); % deg.?
      p.addParamValue('maxRadius',10.0,@double);

      p.addParamValue('position',[0.0,0.0],@(x) isvector(x) && isreal(x)); % [x,y] (pixels)
      
      p.addParameter('colour',[1,0,0],@double);
      p.addParameter('visible',true,@islogical);
      p.addParameter('gaussian',false,@islogical);
      
      try
        p.parse(args{:});
      catch,
        warning('Failed to parse name-value arguments.');
        return;
      end
      
      args = p.Results;
    
      o.size = args.size;
      o.speed = args.speed;
      
      o.direction = args.direction;
      
      o.numDots = args.numDots;

      o.mode = args.mode;
      o.coherence = args.coherence;
      o.dist = args.dist;
      o.bandwdth = args.bandwdth;

      o.truncateGauss = -1; % multiples of std. dev. (i.e., o.bw)
      
      o.lifetime = args.lifetime;
      
      o.maxRadius = args.maxRadius;
      
      o.position = args.position;
      
      o.colour = args.colour;
      o.visible = args.visible;
    end
    
    function setpatch(o,patchcells)
       %***** do nothing if already empty
       if isempty(o.Patch) && isempty(patchcells)
           return;
       end
       if isempty(patchcells)
           o.PatchRef(:,:) = 0;
       end
       %********
       o.PatchN = length(patchcells);
       o.Patch = patchcells;
       %*** correct for mean motion in aperture
       if ~isempty(patchcells)
           for kp = 1:o.PatchN
               o.correct_motion_offset(kp,-0.5);
           end
       end
       %**** log change in patches for reconstruction
       o.HistoryCnt = o.HistoryCnt + 1;
       o.History{o.HistoryCnt}.frame = o.updateCount; 
       o.History{o.HistoryCnt}.command = 'setpatch'; 
       o.History{o.HistoryCnt}.args = o.Patch;
       %******
    end
    
    function setpatchdirs(o,patchdirs)
       %********
       if length(patchdirs) ~= o.PatchN
           return;  % do nothing if it does not match length
       end
       %*** find all dots in patch, changes motion immediately
       for kp = 1:o.PatchN
           idx = find( o.PatchRef == kp);  % find all dots in that patch
           if isnan(patchdirs(kp))  % assign random motions
               n = length(idx);
               directions = o.myrand.rand(n,1) * 360;
               [dx,dy] = pol2cart( directions .* (pi/180), o.speed);
               o.correct_motion_offset(kp,+0.5);  % undo previous change
               o.Patch{kp}(4) = NaN;       
           else   % change their motion directions to single direction
               [dx,dy] = pol2cart(patchdirs(kp) .* (pi/180), o.speed);
               o.correct_motion_offset(kp,+0.5);  % undo previous change
               o.Patch{kp}(4) = patchdirs(kp);      
               o.correct_motion_offset(kp,-0.5);  % apply new change
           end
           o.dx(idx) = dx;
           o.dy(idx) = dy;
       end
       %**** log change in patches for reconstruction
       o.HistoryCnt = o.HistoryCnt + 1;
       o.History{o.HistoryCnt}.frame = o.updateCount; 
       o.History{o.HistoryCnt}.command = 'setpatchdirs'; 
       o.History{o.HistoryCnt}.args = patchdirs;
       %******
    end
    
    function correct_motion_offset(o,kp,gain),
       %*** correct for mean motion in aperture
           di = o.Patch{kp}(4); % motion direction
           if ~isnan(di)
              dxp = gain * cos(di*(pi/180)) * o.speed * o.lifetime;
              dyp = gain * sin(di*(pi/180)) * o.speed * o.lifetime;
              o.Patch{kp}(1) = o.Patch{kp}(1) + dxp;
              o.Patch{kp}(2) = o.Patch{kp}(2) + dyp;
           end
    end
    
    %***** NOTE, all random function calls occur in this function
    function beforeTrial(o),  
      o.History = [];  % reset the history to zero
      o.HistoryCnt = 0;
      o.updateCount = 0;
      if ~isempty(o.PatchRef)
          o.PatchRef(:,:) = 0;  % turn off any past dot memberships
      end
      %**** initialize object with current parameters for all dots
      o.initDots([1:o.numDots]); % all dots!
    end
    
    function beforeFrame(o),
      o.drawDots();
    end
        
    function afterFrame(o),
      % decrement frame counters
      o.frameCnt = o.frameCnt - 1;
      o.moveDots();
      %***** note the update in state
      o.updateCount = o.updateCount + 1;
    end
    
    function CloseUp(o),
    end
    
  end % methods
    
  methods (Access = public)        
    function initDots(o,idx),

      % all random functions occur here, so in principle, you can
      % reconstruct the stimulus if you know the rand seed at the
      % start of this function each time it is called
      % as long as you have all the stimulus parameters for the object
      % and keep a log of any changes to them ... here I'm assuming
      % only the Patch parameters will change over a trial
      %  ... any other params you want to change would need logging

      % initialises dot positions
      nn = length(o.x);  % current number of dots
      n = length(idx); % the number of dots to (re-)place
      
      if (length(o.PatchRef) ~= nn)
          o.PatchRef = int8(zeros(1,nn));
          % initialise dots' lifetime
          if ( o.lifetime ~= Inf)  % if new trial reset lifetimes
              o.frameCnt = o.myrand.randi(o.lifetime,o.numDots,1); % 1:numDots
          else,
              o.frameCnt = inf(o.numDots,1);
          end
      else
          if (n == nn)  % first time initialization in a new trial
              o.frameCnt = o.myrand.randi(o.lifetime,o.numDots,1); % 1:numDots         
          else
             o.frameCnt(idx) = o.lifetime; % default: Inf
          end
      end
      
      if isinf(o.maxRadius)
          x = (o.myrand.rand(n,1) * (o.Xtop - o.Xbot)) + o.Xbot;
          y = (o.myrand.rand(n,1) * (o.Ytop - o.Ybot)) + o.Ybot;
          o.x(idx) = x;
          o.y(idx) = y;
      else
          % dot positions (polar coordinates, r and theta) - store this?
          r = sqrt(o.myrand.rand(n,1).*o.maxRadius.*o.maxRadius); % pixels
          th = o.myrand.rand(n,1).*360.0; % deg.

          % convert r and theta to x and y
          [x,y] = pol2cart(th.*(pi/180.0),r);
          o.x(idx) = x;
          o.y(idx) = y;
      end
      
      % set displacements (dx and dy) for each dot
      [dx,dy] = pol2cart(o.direction.*(pi/180),o.bspeed);
      o.dx(idx) = dx;
      o.dy(idx) = dy;
      
      switch o.mode,
        case 0, % proportion of dots
          if o.coherence == 1.0,
            return;
          end
          
          nc = ceil(o.coherence*o.numDots); % the number of dots moving coherently
          
          % set displacements for the dots moving incoherently
          idx_ = idx(idx > nc);
          if o.coherence == 0.0 || ~isempty(idx),
            direction = o.myrand.rand(size(idx)).*360.0; % deg.

            [dx,dy] = pol2cart(direction*(pi/180),o.bspeed);
            o.dx(idx) = dx;
            o.dy(idx) = dy;
          end
                            
        case 1, % directions sampled from some distribution
          switch o.dist,
            case 0,  % gaussian
              phi = o.bandwdth.*randn(n,1);
              if o.truncateGauss ~= -1
                a = abs(direction/o.bandwdth) > o.truncateGauss;
                while max(a),
                  phi(a) = o.bandwdth .* o.myrand.randn(sum(a),1);
                  a = abs(phi(idx)/o.bandwdth) > o.truncateGauss;
                end
              end
            case 1, % uniform
              phi = o.bandwdth .* o.myrand.rand(n,1) - o.bandwdth/2;
            otherwise
              error('Unknown noiseDist');
          end
         
          %****** IF I KNOW THE OBJECT PARAMS AT THE START OF TRIAL,
          %****** AND KNOW THE RANDOM NUMBER GENERATOR STATE, 
          %****** THEN I ONLY NEED TO KNOW IF ANY PARAMS CHANGE
          %****** DURING THE TRIAL ... PATCH can change ...
          %****** and I might change patch directions ... code that
          %****** into the object history somehow?
          
          direction = o.direction + phi;
          [dx,dy] = pol2cart(direction*(pi/180),o.bspeed);
          o.dx(idx) = dx;
          o.dy(idx) = dy;
        
          %****** search all dots and apply patch constraints
          if o.PatchN
              o.PatchRef(idx) = 0; %default all off
              for kp = 1:o.PatchN
                 xk = o.Patch{kp}(1);
                 yk = o.Patch{kp}(2);
                 rk = o.Patch{kp}(3);
                 di = o.Patch{kp}(4);
                 if ~isnan(di)
                    [dx, dy] = pol2cart( (di * (pi/180)),o.speed);
                 end
                 for k = 1:length(x)                 
                     dist = norm([(x(k)-xk),(y(k)-yk)]);
                     if (dist < rk) 
                         if isnan(di)
                            % direction(k) = o.myrand.rand * 360;
                            % will have only background noise
                         else
                            % direction(k) = di;  % add uniform direction
                            o.dx(idx(k)) = o.dx(idx(k)) + dx;
                            o.dy(idx(k)) = o.dy(idx(k)) + dy;
                         end
                         o.PatchRef(idx(k)) = kp;
                     end
                 end
              end 
          end          
          % o.dx(idx) = o.dx(idx) + dx;
          % o.dy(idx) = o.dy(idx) + dy;
        otherwise
          error('Unknown noiseMode');    
      end  
    end
    
    
    function ret = getstate(o),
        ret = o.myrand.State';    %store the state of random number gen 
    end
    
    function setstate(o,State),
        o.myrand.State = State';
    end
    
    %****** returns a 4N vector, where N is the number of dots, and
    %****** it includes in order:  x pos, y pos, delta x, delta y
    function ret = getbigstate(o),
        ret = [o.x  o.y  o.dx  o.dy double(o.PatchRef)];
    end
    
    function moveDots(o), 
      % calculate future position
      x = o.x + o.dx;
      y = o.y + o.dy;
      
      if isinf(o.maxRadius)
          o.x = x;
          o.y = y;
          %***** reflect off boundardies
          z = find( o.x > o.Xtop );
          o.x(z) = o.x(z) - (o.Xtop - o.Xbot);
          z = find( o.x <= o.Xbot );
          o.x(z) = o.x(z) + (o.Xtop - o.Xbot);
          %*****
          z = find( o.y > o.Ytop );
          o.y(z) = o.y(z) - (o.Ytop - o.Ybot);
          z = find( o.y <= o.Ybot );
          o.y(z) = o.y(z) + (o.Ytop - o.Ybot);
          %***********
      else
         r = sqrt(x.^2 + y.^2);
         idx = find(r > o.maxRadius); % dots that have exited the aperture   
         o.x = x;
         o.y = y;
         if ~isempty(idx),
            % (re-)place the dots on the other side of the aperture
            [th,~] = cart2pol(o.dx(idx),o.dy(idx));
            [xx, yy] = o.rotate(o.x(idx),o.y(idx),-1*th);
            chordLength = 2*sqrt(o.maxRadius^2 - yy.^2);
            xx = xx - chordLength;
            [o.x(idx), o.y(idx)] = o.rotate(xx,yy,th);
         end
      end
      
      idx = find(o.frameCnt == 0); % dots that have exceeded their lifetime
      
      if ~isempty(idx),
        % (re-)place dots randomly within the aperture
        o.initDots(idx);
      end
    end
    
    function drawDots(o),      
      dotColour = o.colour; %zeros([1,3]); %repmat(0,1,3);
      
      % dotType:
      %
      %   0 - square dots (default)
      %   1 - round, anit-aliased dots (fvour performance)
      %   2 - round, anti-aliased dots (favour quality)
      %   3 - round, anti-aliased dots (built-in shader)
      %   4 - square dots (built-in shader)
      dotType = 1;
      
      %************* color matrix for each dot ******************
      if o.gaussian
        colmat = mean(dotColour) .* ones(size(o.x,2),4);
        sigo = 2*((o.maxRadius/2.5)^2);
        %*******
        rad = ((o.x).^2 + (o.y).^2)/sigo;
        val = floor( 255 * exp(-rad));
        colmat(:,4) = val';
      else
        if o.PatchColor
           if (1)  % keep fixed colors, no ramping of the onset
             colmat = o.BackColor * ones(size(o.x,2),4);
             colmat(:,4) = 255;
             colmat((o.PatchRef>0),1:3) = o.PatchColor;
           else
               colmat = (o.BackColor - o.bkgd) * ones(size(o.x,2),4);
               colmat(:,4) = 255;
               % colmat((o.PatchRef == 1),1:3) = 255;
               colmat((o.PatchRef>0),1:3) = (o.PatchColor - o.bkgd);
               %******* modulate by lifetime, peak at mid-point
               L2 = 1+floor( o.lifetime/2);
               colmod = (1-((o.frameCnt - L2)/L2).^2).^3;   % peaks at mid point
               for ik = 1:size(colmat,1)
                   colmat(ik,1:3) = colmat(ik,1:3) * colmod(ik);
               end
               %***********
               colmat(:,1:3) = colmat(:,1:3)+o.bkgd;
           end
        else
           colmat = dotColour';
        end
      end
      %******************
      
      if o.visible,
        Screen('DrawDots',o.winPtr,[o.x(:), -1*o.y(:)]', o.size, colmat', o.position, dotType);
      end
      
    end
  end % methods
  
  methods (Static)
    function [xx, yy] = rotate(x,y,th)
      % rotate (x,y) by angle th

      for ii = 1:length(th),
        % calculate rotation matrix
        R = [cos(th(ii)) -sin(th(ii)); ...
             sin(th(ii))  cos(th(ii))];

        tmp = R * [x(ii), y(ii)]';
        xx(ii) = tmp(1,:);
        yy(ii) = tmp(2,:);
      end
    end
  end % methods
end % classdef
