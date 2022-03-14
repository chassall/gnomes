% Gnomes Task
% C. Hassall, 2021

%% Standard pre-script code
close all; clear variables; clc; % Clear everything
rng('shuffle'); % Shuffle the random number generator

%% Run flags
demoMode = input('demoMode = (0/1): '); % 1 = demo, 0 = experiment
windowed = 0; % 1 = run in a window, 0 = run fullscreen
sendTriggers = 1; % 1 =  
%% Set up parallel port and triggers
if sendTriggers
    portobject = io64();
    portaddress = hex2dec('D050');
    status = io64(portobject);
    io64( portobject, portaddress,0);
end

%% Define control keys
KbName('UnifyKeyNames'); % Ensure that key names are mostly cross-platform
exitKey = KbName('ESCAPE'); % Exit program
spacebar = KbName('SPACE');
leftKey = KbName('f');
rightKey = KbName('j');

%% Display Settings

% % Home: AOC i2481Fxh 23.8:
% viewingDistance = 600; % mm, approximately
% screenWidth = 538; % mm
% screenHeight = 304; % mm

% % Cam's iMac
% viewingDistance = 690; % mm, approximately
% screenWidth = 596; % mm
% screenHeight = 335; % mm

% Testing Room 2
viewingDistance = 660; % mm, approximately
screenWidth = 599; % mm
screenHeight = 337; % mm

%% Participant info and data
participantData = [];
while ~demoMode
    p_number = input('Enter the participant number:\n','s');  % get the subject name/number
    rundate = datestr(now, 'yyyymmdd-HHMMSS');
    filename = strcat('gnomes_', rundate, '_', p_number, '.txt');
    mfilename = strcat('gnomes_', rundate, '_', p_number, '.mat');
    checker1 = ~exist(filename,'file');
    checker2 = isnumeric(str2double(p_number)) && ~isnan(str2double(p_number));
    if checker1 && checker2
        break;
    else
        disp('Invalid number, or filename already exists.');
        WaitSecs(1);
    end
end

%% Experiment Parameters

% generate some blocks with trials in random order
iGnome = 1:6;
trialTypes = [];
if demoMode
    numBlocks = 5;
else
    numBlocks = 25; % around 19 minutes without instructions and with short breaks
end
for i = 1:numBlocks
    trialTypes = [trialTypes Shuffle(iGnome)];
end
numTrials = length(trialTypes);
gnomeOutcomes = getoutcomes(trialTypes);
pointsPerPoint = 3000;
trialCount = 0;

targetLow = 1/3;
targetHigh = 2/3;

fixationTime = 0;
cueSize = [0.9*0.2, 0.9*0.3];
rtDeadline = 5;
if demoMode
    restFrequency = 5; % Rest break on these trials
else
    restFrequency = 75; % Rest break on these trials
end
% * * * Stim properties * * *

% Visual
bgColour = [64 64 64];
textColour = [255 255 255];
fixationColour = [255 255 255];
responseColour = [128 128 128];
barColour = [255 255 255];
fillColour = [255,128,128];
gnomeDeg = 4;
textSize = 24; % Instructions, etc. (in "pnts" or something)
textOffsetDeg = 1.75; % Some text might appear below the metronome/fixation cross - this is the offset, in degrees
fixCrossDimDeg = 1; % Fixation cross width/heigth (degrees)
fbWidthDeg = 2; % Feedback width (degrees)
barDimDeg = [1,3];
waitframes = 1; % For animation
barSpeedDeg = 1; % In degrees per second

% Stim colours (counterbalanced)
red = [228, 26, 28];
blue = [55, 126, 184];
if demoMode
    if rand() < 0.5
        goodColour = red;
        badColour = blue;
        rewColour = 255.*parula(255);
        rewColour = [255 128 128];
        goodString = 'YELLOW';
        badString = 'BLUE';
    else
        goodColour = blue;
        badColour = red;
        rewColour = 255.*parula(255);
        rewColour = flip(rewColour);
        rewColour = [255 128 128];
        goodString = 'BLUE';
        badString = 'YELLOW';
    end
else
    if mod(num2str(p_number),2) == 1 % Odd
        goodColour = red;
        badColour = blue;
        rewColour = 255.*parula(255);
        rewColour = [255 128 128];
        goodString = 'YELLOW';
        badString = 'BLUE';
    else % Even
        goodColour = blue;
        badColour = red;
        rewColour = 255.*parula(255);
        rewColour = flip(rewColour);
        rewColour = [255 128 128];
        goodString = 'BLUE';
        badString = 'YELLOW';
    end
end

% High-level variables
totalPoints = 0;
allAnimationData = {};

%% Experiment

try
    
    % Open a fullscreen window to get the display resolution
    Screen('Preference', 'SkipSyncTests', 1);
    Screen('Preference', 'TextRenderer', 0); % Necessary on my machine, not sure about lab
    [~, rec] = Screen('OpenWindow', 0, bgColour);
    fullRec = rec;
    Screen('CloseAll');
    
    if windowed
        rec = [0 0 600 400];
        windowWidth = ((rec(3)-rec(1))/fullRec(3))*screenWidth;
        windowHeight = ((rec(4)-rec(2))/fullRec(4))*screenHeight;
        [win, rec] = Screen('OpenWindow', 0, bgColour,rec, 32, 2);
    else
        HideCursor();
        ListenChar(2);
        rec = fullRec;
        windowWidth = screenWidth; % Hard-coded above somewhere
        windowHeight = screenHeight;
        [win, rec] = Screen('OpenWindow', 0, bgColour,rec, 32, 2);
    end
    
    % Set screen properties
    Screen('BlendFunction', win, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen(win,'TextFont','Arial');
    Screen(win,'TextSize',textSize);
    
    % Get screen properties
    refreshRate = Screen('GetFlipInterval',win);
    ifi = Screen('GetFlipInterval', win);
    horRes = rec(3) - rec(1);
    verRes = rec(4)-rec(2);
    xmid = round(rec(3)/2);
    ymid = round(rec(4)/2);
    horizontalPixelsPerMM = horRes/windowWidth;
    verticalPixelsPerMM = verRes/windowHeight;
    
    % * * * Compute stim dimensions, in pixels * * *
    
    % Fair
    fairRect = rec;
    
    % All gnomes
    allGnomesPixWidth =  rec(3)/2;
    allGnomesPixHeight = allGnomesPixWidth * 297/1440;
    allGnomesRect = [xmid - allGnomesPixWidth/2 ymid - allGnomesPixHeight/2 xmid + allGnomesPixWidth/2 ymid + allGnomesPixHeight/2];
    allGnomesRect([2 4]) =  allGnomesRect([2 4]) + verRes/4;
    
    % Single gnome
    gnomeMM = 2 * viewingDistance *tand(gnomeDeg/2);
    gnomePixWidth = gnomeMM*horizontalPixelsPerMM;
    gnomePixHeight = gnomePixWidth * (2400/1600);
    gnomeRect = [xmid - gnomePixWidth/2 ymid - gnomePixHeight/2 xmid + gnomePixWidth/2 ymid + gnomePixHeight/2];

    % Bar
    barDimMM = 2 * viewingDistance *tand(barDimDeg/2);
    barDimPix = [barDimMM(1)*horizontalPixelsPerMM barDimMM(2)*verticalPixelsPerMM];
    barRect = [xmid - barDimPix(1) ymid - barDimPix(2) xmid + barDimPix(1) ymid + barDimPix(2)];
    barHeight = barRect(4) - barRect(2);
   
    % Small gnome
    smallGnomeDeg = 2;
    sgnomeMM = 2 * viewingDistance *tand(smallGnomeDeg/2);
    sgnomePixWidth = sgnomeMM*horizontalPixelsPerMM;
    sgnomePixHeight = sgnomePixWidth * (2400/1600);
    sgnomeRect = [xmid - sgnomePixWidth/2 (ymid - sgnomePixHeight/2+1.2*barDimPix(2)) xmid + sgnomePixWidth/2 (ymid + sgnomePixHeight/2+1.2*barDimPix(2))];
    
    % Bar speed
    barSpeedMMPerSec = 2 * viewingDistance *tand(barSpeedDeg/2);
    barSpeedPixPerSec = barSpeedMMPerSec * verticalPixelsPerMM;
    barSpeedPixPerFrame = barSpeedPixPerSec * ifi;
    
    % Fixation
    fixCrossDimMM = 2 * viewingDistance *tand(fixCrossDimDeg/2);
    fixCrossDimPix = fixCrossDimMM*horizontalPixelsPerMM;
    xCoords = [-fixCrossDimPix/2 fixCrossDimPix/2 0 0];
    yCoords = [0 0 -fixCrossDimPix/2 fixCrossDimPix/2];
    allCoords = [xCoords; yCoords];
    lineWidthPix = 4;
    
    % * * * Load images ***
    
    % Fair
    [fairImage, ~, alpha] = imread('./images/amusement-1298959.png');
    fairImage(:,:,4) = alpha;
    fairTexture = Screen('MakeTexture', win, fairImage);
    
    % All Gnomes
    [allGnomesImage, ~, alpha] = imread('./images/allgnomes.png');
    allGnomesImage(:,:,4) = alpha;
    allGnomesTexture = Screen('MakeTexture', win, allGnomesImage);
    
    % Gnomes
    gnomeImages = {};
    gnomeImageNumbers = Shuffle(1:6);
    for i = 1:6
        [gnomeImages{i}, ~, alpha] = imread(['./images/gnome' num2str(gnomeImageNumbers(i)) '.png']);
        gnomeImages{i}(:,:,4) = alpha;
        gnomeTextures(i) = Screen('MakeTexture', win, gnomeImages{i});
    end
    
    if ~demoMode
        DrawFormattedText(win,'Demographics\n\nPlease read the following questions, then type your answer and press ''enter''\nTo leave a question blank, press ''enter'' twice without entering any text beforehand\nPlease inform the experimenter if you wish to change a response\n\n(press any key to proceed)','center','center',textColour);
        Screen('Flip',win);
        KbReleaseWait(-1);
        KbPressWait(-1);
        
        KbReleaseWait(-1);
        age = Ask(win,'What is your age?  ', textColour,bgColour,'GetChar','center','center',textSize);
        Screen('Flip',win);
        
        KbReleaseWait(-1);
        sex = Ask(win,'What is your sex?  ', textColour,bgColour,'GetChar','center','center',textSize);
        Screen('Flip',win);
        
        KbReleaseWait(-1);
        hand = Ask(win,'Are you left-handed or right-handed (left/right)?  ', textColour,bgColour,'GetChar','center','center',textSize);
        Screen('Flip',win);
        
        % Save participant's info (should be redundant with run sheet)
        run_line = [num2str(p_number) ', ' datestr(now) ', ' age ', ' sex ',  ' hand];
        dlmwrite('participants.txt',run_line,'delimiter','', '-append');
        
        DrawFormattedText(win,'Thank you - press any key to read the task instructions','center','center',textColour);
        Screen('Flip',win);
        KbReleaseWait(-1);
        KbPressWait(-1);
        KbReleaseWait(-1);
    end
    
    % Instructions
    instructions{1} = 'GNOMES\n\nIn this game, six gnomes visit the fair\nThey decide to compete in HIGH STRIKER\n(Swing the hammer as hard as they can to try to raise the puck to the top of the tower)\n\nYour task is to BET on how high the puck will rise for each gnome\nThe closer your guess is to the outcome, the more points you will earn\nPoints will be converted to � at the end of the game\n\n(press any key to continue)';
    instructions{2} = 'TASK DETAILS\n\nAt the beginning of each round, you will see the gnome you''re betting on\nNext, you''ll be shown the tower and use the mouse to place the bar where you think the puck will end up\nFinally, the gnome will swing the hammer and the puck, represented by a coloured bar, will rise';
    instructions{3} = 'EEG QUALITY\n\nPlease try to minimize eye and head movements\nAfter you click the mouse, try not to move your hand until the next round begins\nPlease keep your eyes on the center of the display\nYou will be given a couple of rest breaks\nPlease use these opportunities to rest your eyes, as needed';
    instructions{4} = 'Any questions?\n\nPress any key to begin';
    for i = 1:length(instructions)
        Screen('DrawTexture', win, fairTexture, [], fairRect);
        Screen('DrawTexture', win, allGnomesTexture, [], allGnomesRect);
        DrawFormattedText(win,instructions{i},'center','center',textColour);
        Screen('Flip',win);
        KbReleaseWait(-1);
        KbPressWait(-1);
        KbReleaseWait(-1);
    end
    
    for t = 1:numTrials
       
        % Get gnome
        thisGnomeType = trialTypes(t);
        thisTarget = gnomeOutcomes(t);
        
%         % Get bar height
%         if thisGnomeType == 1
%             thisTarget = targetLow;
%         elseif thisGnomeType == 2
%             thisTarget = targetHigh;
%         elseif thisGnomeType == 3
%             if rand() < 0.5
%                 thisTarget = targetLow;
%             else
%                 thisTarget = targetHigh;
%             end
%         elseif thisGnomeType == 4
%             if rand() < 0.8
%                 thisTarget = targetLow;
%             else
%                 thisTarget = targetHigh;
%             end
%         elseif thisGnomeType == 5
%             if rand() < 0.8
%                 thisTarget = targetHigh;
%             else
%                 thisTarget = targetLow;
%             end
%         else
%             thisTarget = 0.1 + 0.8*rand(); % 0.1-0.9
%         end
        
        % Draw fixation cross
        Screen('DrawLines', win, allCoords,lineWidthPix, fixationColour, [xmid ymid], 2);
        % DrawFormattedText(win,blockInstructions{b},'center',ymid + textOffsetPx);
        Screen('Flip',win);
        if sendTriggers
            io64( portobject, portaddress,thisGnomeType);
            WaitSecs(0.002);
            io64( portobject, portaddress,0);
        end
             
        fixationTime = 0.4 + 0.2*rand();
        WaitSecs(fixationTime);
        
        % Gnome
        Screen('DrawTexture', win, gnomeTextures(thisGnomeType), [], gnomeRect);
        Screen('Flip',win);
        if sendTriggers
            io64( portobject, portaddress,10+thisGnomeType);
            WaitSecs(0.002);
            io64( portobject, portaddress,0);
        end
        WaitSecs(1.5);
        
        % Bar
        Screen('FrameRect',win, barColour, barRect);
        Screen('DrawTexture', win, gnomeTextures(thisGnomeType), [], sgnomeRect);
        Screen('Flip',win);
        if sendTriggers
            io64( portobject, portaddress,20+thisGnomeType);
            WaitSecs(0.002);
            io64( portobject, portaddress,0);
        end
        
        % Get Response
        guessPix = NaN;
        rtStart = GetSecs();
        while 1
            [respX,respY,buttons] = GetMouse();
            
            if any(buttons)
                if sendTriggers
                    io64( portobject, portaddress,30+thisGnomeType);
                    WaitSecs(0.002);
                    io64( portobject, portaddress,0);
                end
                rtEnd = GetSecs();
                responseTime = rtEnd - rtStart;
            end
            
            if respY > barRect(4)
                respY = barRect(4);
            elseif respY < barRect(2)
                respY = barRect(2);
            end
            
            Screen('FrameRect',win, barColour, barRect);
            Screen('DrawLine', win,fixationColour,barRect(1),respY,barRect(3),respY,lineWidthPix);
            Screen('DrawTexture', win, gnomeTextures(thisGnomeType), [], sgnomeRect);
            vbl = Screen('Flip',win);
            
            if any(buttons)
                guessPix = respY;
                break;
            end
        end
        
        preFeedbackTime = 0.4 + 0.2*rand();
        WaitSecs(preFeedbackTime);
        
        % Convert participant guess (in pixels) to a proportion
        guessProp = (barRect(4)-guessPix)/barHeight;
        guessDiff = abs(guessProp - thisTarget);
        
        % Convert guess to points (1-100)
        guessPoints = ceil((1-guessDiff)*100);
        totalPoints = totalPoints + guessPoints;
        
        % Grow the bar
        time = 0;
        barCurr = 0;
        times = [];
        
        thisTargetPix = thisTarget * barHeight;
        animationData = [];
        isFirstFrame = 1;
        animationStartTime = GetSecs();
        relTime = 0; % Time relative to start of animation
        while barCurr <= thisTargetPix
            
            % Increment bar position
            barCurr = barCurr + barSpeedPixPerFrame;
            
            % Convert barCurr to proportion
            barCurrProp  = barCurr/barHeight;
            
            % Convert guessProp to points proportion based on barCurrProp
            pointsCurrProp = 1 - abs(guessProp - barCurrProp);
            
            % Convert guessProp to colour
            currColourI = ceil(pointsCurrProp * size(rewColour,1)); % Convert to an index
            currColour = rewColour(currColourI,:);
            
            fillRect = barRect;
            fillRect(2) = barRect(4) - barCurr;
            Screen('FillRect',win, currColour, fillRect);
            Screen('FrameRect',win, barColour, barRect);
            Screen('DrawLine', win,fixationColour,barRect(1),respY,barRect(3),respY,lineWidthPix); 
            Screen('DrawTexture', win, gnomeTextures(thisGnomeType), [], sgnomeRect);
            
            % Flip to the screen
            vbl  = Screen('Flip', win, vbl + (waitframes - 0.5) * ifi);
            
            % Send a trigger to mark end of first frame
            if isFirstFrame && sendTriggers
                io64( portobject, portaddress,40+thisGnomeType);
                WaitSecs(0.002);
                io64( portobject, portaddress,0);
                isFirstFrame = 0;
            end
            relTime = GetSecs() - animationStartTime;
            
            animationData = [animationData; barCurr barCurrProp pointsCurrProp currColour vbl GetSecs() relTime];
            
            % Increment the time for the animation
            time = time + ifi;
            times = [times time];
            
        end
        
        if sendTriggers
            io64( portobject, portaddress,50+thisGnomeType);
            WaitSecs(0.002);
            io64( portobject, portaddress,0);
        end
        
        % Store animation frame data
        allAnimationData{t} = animationData;
        WaitSecs(1);
        
        % thisLine = [b t preBeepTime responseTime computerRT computerRespCondition judgementMapping participantResponse participantJudgement guessTime preFeedbackTime fbCondition totalPoints thisTrialMargin];
        thisLine = [t thisGnomeType gnomeImageNumbers(thisGnomeType) thisTarget fixationTime rtStart rtEnd responseTime respX respY guessProp guessPoints totalPoints preFeedbackTime];
        if ~demoMode
            dlmwrite(filename,thisLine,'delimiter', '\t', '-append','precision',10);
        end
        participantData = [participantData; thisLine];
        
        % Check for escape key                                            
        [keyIsDown, ~, keyCode] = KbCheck(-1);
        if keyCode(exitKey)
            ME = MException('kh:escapekeypressed','Exiting script');
            throw(ME);
        end
        
        % Check for rest break
        if mod(t,restFrequency) == 0 && t ~= numTrials
            DrawFormattedText(win,['REST BREAK\n\ntotal: £' num2str(totalPoints/pointsPerPoint,'%.2f\n') '\n\n(press any key to proceed)'],'center','center',textColour);
            Screen('Flip',win);
            KbReleaseWait(-1);
            KbPressWait(-1);
        end
        
        
    end
    
catch e
    
    % Save important variables
    if ~demoMode
        save(mfilename, 'allAnimationData','participantData');
    end
    
    if sendTriggers
        % CloseIOPort; %close trigger functions and triggers to eeg
        clear portobject;
    end
    
    % Close the Psychtoolbox window and bring back the cursor and keyboard
    Screen('CloseAll');
    ListenChar();
    ShowCursor();
    
    % Display payout and whatnot
    disp(['Points: ' num2str(totalPoints)]);
    
    rethrow(e);
    
end

%% End Experiment

% Save important variables
if ~demoMode
    save(mfilename, 'participantData');
end

if sendTriggers
    % CloseIOPort; %close trigger functions and triggers to eeg
    clear portobject;
end

% Close the Psychtoolbox window and bring back the cursor and keyboard
Screen('CloseAll');
ListenChar();
ShowCursor();

% Display payout and whatnot
disp(['Points: ' num2str(totalPoints)]);



