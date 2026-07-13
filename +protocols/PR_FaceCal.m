classdef PR_FaceCal < handle
    % 
    % States:
    %   0   keep going
    %   1   inter-trial interval
    
    properties
        Iti = 1;        % default Iti duration
        startTime = 0;  % trial start time
        faceOff = 0;    % trial face offset time
    end
    
    properties (Access = private)
        winPtr; % ptb window
        state = 0;      % state counter
        error = 0;      % error state in trial
        %************
        S;      % copy of Settings struct (loaded per trial start)
        P;      % copy of Params struct (loaded per trial)
        %********* stimulus structs for use
        Faces;      % object that stores face images for use
        faceConfig; % configuration of images shown per trial number
        texList;  % face textures
        texRects; % size of texture in pixels
        winRects; % locations to draw textures
    end
    
    methods
        function obj = PR_FaceCal(winPtr)
            obj.winPtr = winPtr;
        end
        
        function state = get_state(o)
            state = o.state;
        end
        
        function initFunc(obj, S, ~)
            obj.Faces = stimuli.gaussimages(obj.winPtr,... 
                'bkgd', S.bgColour, 'gray', false);   % uint8, color images
            marmoPath = getMarmoViewPath();
            obj.Faces.loadimages(fullfile(marmoPath, ...
                'SupportData', 'MarmosetFaceLibrary.mat'));
        end
        
        function closeFunc(obj)
            obj.Faces.CloseUp();
        end
        
        function generate_trialsList(~, ~, ~)
            % nothing for this protocol
        end
        
        function P = next_trial(obj, S, P)
            %********************
            obj.S = S;
            obj.P = P;
            %*******************
            
            % UPDATE THE FACE CONFIGURATION
            P.faceConfig = P.faceConfig+1;
            if P.faceConfig > length(S.faceConfigs)
                P.faceConfig = 1;
            end
            
            % Grab the face configuration to use on this trial
            obj.faceConfig = S.faceConfigs{P.faceConfig};
            % Get how many faces in this configuration
            N = size(obj.faceConfig,1);
            % Get texture list
            F = obj.faceConfig(:,3); % face indices
            obj.texList = obj.Faces.tex(F); % corresponding textures
            
            % Rectangles of the source textures
            obj.texRects = zeros(4,N);
            for i = 1:N
                obj.texRects(3:4,i) = zeros(2,1) + obj.Faces.texDim(F(i));
            end
            
            % Rectangles of the window placement
            obj.winRects = zeros(4,N);
            fr = round(P.faceRadius*S.pixPerDeg);
            cp = S.centerPix;
            X = obj.faceConfig(:,1); % X coordinate in degrees
            Y = obj.faceConfig(:,2); % Y coordinate in degrees
            for i = 1:N
                cX = round(cp(1)+X(i)*S.pixPerDeg);
                cY = round(cp(2)-Y(i)*S.pixPerDeg); % INVERT FOR SCREEN DRAWS
                obj.winRects(:,i) = [cX-fr cY-fr cX+fr cY+fr];
            end
        end
        
        function [FP, TS] = prep_run_trial(obj)
            % Setup the state
            obj.state = 0; % Showing the face
            Iti = obj.P.iti;   % set ITI interval from P struct stored in trial
            %*******
            FP(1).states = 0;  % any special plotting of states,
            FP(1).col = 'b';   % FP(1).states = 1:2; FP(1).col = 'b';
            % would show states 1,2 in blue for eye trace
            %******* set which states are TimeSensitive, if [] then none
            TS = [];  % no sensitive states in FaceCal
            %********
            obj.startTime = GetSecs();
        end
        
        function keepgoing = continue_run_trial(obj, ~)
            keepgoing = 0;
            if (obj.state < 1)
                keepgoing = 1;
            end
        end
        
        %******************** THIS IS THE BIG FUNCTION *************
        function drop = state_and_screen_update(obj, currentTime, x, y)
            drop = 0;
            %******* THIS PART CHANGES WITH EACH PROTOCOL ****************
            if obj.state == 0 && currentTime > obj.startTime + obj.P.faceDur
                obj.state = 1; % Inter trial interval
                obj.faceOff = GetSecs();
                drop = 1;
                 cprintf('_[0.5,0.5,0.5]', '\tProtocol, give reward\n');
            end
            % GET THE DISPLAY READY FOR THE NEXT FLIP, STATE SPECIFIC DRAWS
            switch obj.state
                case 0
                    Screen('DrawTextures', obj.winPtr, obj.texList, obj.texRects, obj.winRects)
            end
            %**************************************************************
        end
        
        function Iti = end_run_trial(obj)
            Iti = obj.Iti;  % returns generic Iti interval (not task dep)
        end
        
        function plot_trace(obj, handles)
            %********* append other things eye trace plots if you desire
            h = handles.EyeTrace;
            faceConfig = obj.S.faceConfigs{obj.P.faceConfig};
            set(h,'NextPlot','Replace');
            for i = 1:size(obj.faceConfig,1)
                xF = obj.faceConfig(i,1);
                yF = obj.faceConfig(i,2);
                rF = obj.P.faceRadius;
                plot(h,[xF-rF xF+rF xF+rF xF-rF xF-rF],[yF-rF yF-rF yF+rF yF+rF yF-rF],'-k');
                if (i == 1)
                    set(h,'NextPlot','Add');
                end
            end
            
        end
        
        function PR = end_plots(obj, P, A)   %update D struct if passing back info
            % Note, not passing in any complex information here
            PR = struct;
            PR.error = obj.error;
            PR.faceconfig = obj.faceConfig;
        end
        
    end
end
