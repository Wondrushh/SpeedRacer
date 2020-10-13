classdef speedRacer < handle
  
  properties 
    game;
    gameStatus = 1;
    lapTime = 0;
    bestLapTime = 0;
    lastLap = 0;
    totalTime = 0;
    lapCounter = 0;
    maxLaps = 10;
    dispWidth = 160;
    dispHeight = 100;
    display = zeros(100,160,3);
    ax;
    welcomeText = double(imread('welcomeText.png'))./255;
    formula = double(imread('formula.png'))./255;
    formulaW;
    formulaH;
    speed = 0;
    maxSpeed = 20;
    clipSpeedLimit = 5;
    acceleration = 2;
    steering = 8;
    centripetalForceCoef = 0.95;
    curveCoef = 0.10; %increase to make the curve shift quicker
    tick = 0.05;
    lapTimer;
    endScreen;
    
    %colors
    green = [52/255 167/255 0];
    darkGreen = [56/255 118/255 29/255];
    grey = [153/255 153/255 153/255];
    red = [1 0 0];
    lightBlue = [120/255 120/255 255];
    white = [1 1 1];
    black = [0 0 0];
    
    track = [100, 0;
      500, 0;
      600, 0.03;
      600, -0.03;
      800, 0.01;
      400, -0.03;
      500, 0;
      800, 0.02;
      500, -0.02;
      300, 0
      600, -0.025;
      500, 0.03;
      800, 0];
    
    trackRow = 1;
    trackRowsN = 0;
    curvature = 0;
    
    carPos = [0,0];
    distance = 0;
    
    keys = {'w','a','d','s','escape','space'};
    keyStatus = false(1,6);
    
    up = 1;
    left = 2;
    right = 3;
    down = 4;
    escape = 5;
    space = 6;
  end
  
  methods
    function this = speedRacer()
      gameTimer = timer;
      gameTimer.StartFcn = @this.introFcn;
      gameTimer.TimerFcn = @this.gameFcn;
      gameTimer.StopFcn = @this.endFcn;
      gameTimer.Period = this.tick;
      gameTimer.ExecutionMode = 'fixedRate';
      
      start(gameTimer);
      
    end
    
    function introFcn(this, ~, ~)
      this.game = figure('KeyPressFcn',{@this.KeySniffFcn},...
        'KeyReleaseFcn',{@this.KeyRelFcn},...
        'CloseRequestFcn',{@this.QuitFcn},...
        'menubar', 'none',...
        'NumberTitle', 'off',...
        'WindowState', 'maximized');
      this.ax = axes(this.game);
      this.ax.Position = [0 0 1 1];
      this.ax.XTick = [];
      this.ax.YTick = [];
      
      %make the sky blue
      this.display(:,:,1) = this.lightBlue(1);
      this.display(:,:,2) = this.lightBlue(2);
      this.display(:,:,3) = this.lightBlue(3);
      
      image(this.display);
      
      [this.formulaH, this.formulaW,~] = size(this.formula);
      this.carPos = [this.dispWidth/2-this.formulaW/2+1,this.dispHeight*0.85];
      [this.trackRowsN,~] = size(this.track);
    end
    
    function gameFcn(this,~,~)
      switch this.gameStatus
        case 1 %introscreen
          if (this.keyStatus(this.space))
            this.gameStatus = 2; %continue to the game when space is pressed
            %clear sky
            this.display(:,:,1) = this.lightBlue(1);
            this.display(:,:,2) = this.lightBlue(2);
            this.display(:,:,3) = this.lightBlue(3);
            return
          end
          
          this.drawTrack();
          this.drawFormula();
          this.drawWelcome();     
          image(this.display);
          
          this.quitGame()
          
        case 2 %game
          
          %reading the keys and moving the formula
          if (this.keyStatus(this.right))
            this.carPos(1) = this.carPos(1)+this.steering;
          end
          
          if (this.keyStatus(this.left))
            this.carPos(1) = this.carPos(1)-this.steering;
          end
          
          if this.keyStatus(this.up)
            this.speed = this.speed + this.acceleration;
            if this.speed > this.maxSpeed
              this.speed = this.maxSpeed;
            end
            if this.speed < 0
              this.speed = 0;
            end
          else
            this.speed = this.speed - this.acceleration/4;
            if this.speed > this.maxSpeed
              this.speed = this.maxSpeed;
            end
            if this.speed < 0
              this.speed = 0;
            end
          end
          
          if this.keyStatus(this.down)
            this.speed = this.speed - this.acceleration*1.5;
            if this.speed > this.maxSpeed
              this.speed = this.maxSpeed;
            end
            if this.speed < 0
              this.speed = 0;
            end
          end
          
          %when the formula is on the clipping board, slow it down to 5
          if this.carPos(1)< 0.12*this.dispWidth || this.carPos(1) > (1-0.12)*this.dispWidth-this.formulaW
            this.speed = this.speed - this.acceleration*2;
            if this.speed < this.clipSpeedLimit && this.keyStatus(this.up)
              this.speed = this.clipSpeedLimit;
            end
            if this.speed < 0
              this.speed = 0;
            end
          end
          
          %include centripetal force to the steering
          this.carPos(1) = this.carPos(1) - round(this.speed^2/(1/this.curvature)*this.centripetalForceCoef);
          %check whether the formula is on screen, or push it into the screen
          if this.carPos(1)>this.dispWidth-this.formulaW
            this.carPos(1) = this.dispWidth-this.formulaW+1;
          end
          if this.carPos(1) < 1
            this.carPos(1) = 1;
          end
          
          %draw the track on the lower half of the screen
          this.drawTrack()
          %plots the formula
          this.drawFormula()
          
          %calculate distance
          this.distance = this.distance + this.speed;
          
          %change the track when a certain distance is reached and change
          %lap time
          this.manageTrackAndTime()
          
          %curve the track according to the difference between curvature of the
          %track and actual curvature
          if this.curvature - this.track(this.trackRow, 2) ~= 0
            this.curvature = this.curvature + (this.speed/this.maxSpeed)*this.curveCoef*(this.track(this.trackRow, 2) - this.curvature);
          end
          %counts the time
          this.lapTime = this.lapTime + this.tick;
          %display the generated image to the figure
          image(this.display);
          
          delete(this.lapTimer)
          this.lapTimer = text(this.dispWidth*0.05, this.dispHeight*0.1,...
        sprintf('Current time: %0.2f s\nLap %d/%d\nLast lap: %0.2f\nBest lap: %0.2f', this.lapTime,this.lapCounter,this.maxLaps,this.lastLap,this.bestLapTime),...
        'FontWeight', 'bold',...
        'FontName', 'Monospaced',...
        'Color', [0 0 0]);
      
          this.quitGame();
          
        case 3
          this.endScreen = text(this.dispWidth*0.5, this.dispHeight*0.3,...
            sprintf('END!\n\nYour best lap time: %0.2f\nYour total time: %d minutes,%0.2f secons\nPress ESC to exit', this.bestLapTime, floor(this.totalTime/60),(this.totalTime - floor(this.totalTime/60)*60)),...
            'FontSize', 18,...
            'FontName', 'Monospaced',...
            'HorizontalAlignment', 'center');
         this.quitGame()
      end
    end
    
    
    
    
    
    
    
    function endFcn(~, ~, ~)
      listOfTimers = timerfindall;
      if ~isempty(listOfTimers)
        stop(listOfTimers);
        delete(listOfTimers);
      end
      close all
    end
    
    function KeySniffFcn(this,~,event)
      key = event.Key;
      this.keyStatus = (strcmp(key, this.keys) | this.keyStatus);
    end
    
    function KeyRelFcn(this,~,event)
      key = event.Key;
      this.keyStatus = (~strcmp(key, this.keys) & this.keyStatus);
    end
    
    function QuitFcn(~,src,~)
      delete(src);
    end
    
    function manageTrackAndTime(this)
      if this.distance > this.track(this.trackRow,1)
        this.distance = this.distance - this.track(this.trackRow,1);
        this.trackRow = this.trackRow + 1;
        if this.trackRow > this.trackRowsN
          this.trackRow = 1;
          if this.lapTime < this.bestLapTime || this.lapCounter == 0
            this.bestLapTime = this.lapTime;
          end
          this.lastLap = this.lapTime;
          this.totalTime = this.totalTime + this.lapTime;
          this.lapTime = 0;
          this.lapCounter = this.lapCounter + 1;
          if this.lapCounter > this.maxLaps
            this.gameStatus = 3;
            this.lapCounter = this.maxLaps;
          end
        end
      end
    end
    
    function quitGame(this) %quit the game when esc is pressed or figure is closed
      if ~ishghandle(this.game) || this.keyStatus(this.escape)
        stop(timerfindall);
        delete(timerfindall);
        close all
      end
    end
    
    function drawWelcome(this) %draws welcome text
      xx = 1;
      yy = 1;
      for y = this.dispHeight*0.15:this.dispHeight*0.15 + size(this.welcomeText,1)-1%iterating through welcome text size
        for x = this.dispWidth*0.5 - size(this.welcomeText, 2)/2:this.dispWidth*0.5 - size(this.welcomeText, 2)/2 + size(this.welcomeText,2)-1
          if this.welcomeText(yy,xx,1) ~= 1
            this.display(y,x,1:3) = this.welcomeText(yy,xx,1:3);%displays the welcome text
          end
          xx = xx+1;
        end
        xx = 1;
        yy = yy+1;
      end
    end
    
    function drawTrack(this) %draws the track pixel by pixel to the display matrix
      for y = 1:this.dispHeight/2
        for x = 1:this.dispWidth
          row = this.dispHeight/2 + y;
          middlePoint = (this.curvature*(this.dispHeight-row)^(2)+this.dispWidth/2)/this.dispWidth;
          perspective = (y+5)/ (this.dispHeight/2)*0.8;
          roadWidth = perspective;
          clipboardWidth = roadWidth*0.15;
          
          grassChange = abs(sin(10*(1-perspective)^3+0.02*this.distance));
          clipChange = abs(sin(30*(1-perspective)^3+0.1*this.distance));
          roadWidth = roadWidth/2;
          
          leftGrass = (middlePoint-roadWidth-clipboardWidth)*this.dispWidth;
          leftClip = (middlePoint-roadWidth)*this.dispWidth;
          rightClip = (middlePoint+roadWidth)*this.dispWidth;
          rightGrass = (middlePoint+roadWidth+clipboardWidth)*this.dispWidth;
          
          if x>0 && x<leftGrass
            if grassChange>0.5
              this.display(row,x,1:3) = this.green;
            else
              this.display(row,x,1:3) = this.darkGreen;
            end
          end
          if x>=leftGrass && x<leftClip
            if clipChange>0.5
              this.display(row,x,1:3) = this.red;
            else
              this.display(row,x,1:3) = this.white;
            end
          end
          if x>=leftClip && x<rightClip
            if this.trackRow == 1 && this.lapCounter ~= 0
              this.display(row,x,1:3) = this.white;
            else
              this.display(row,x,1:3) = this.grey;
            end
          end
          if x>=rightClip && x<rightGrass
            if clipChange>0.5
              this.display(row,x,1:3) = this.red;
            else
              this.display(row,x,1:3) = this.white;
            end
          end
          if x>=rightGrass && x<=this.dispWidth
            if grassChange>0.5
              this.display(row,x,1:3) = this.green;
            else
              this.display(row,x,1:3) = this.darkGreen;
            end
          end
        end
      end
    end
    
    function drawFormula(this)%draws the formula pixel by pixel on the track
      xx = 1;
      yy = 1;
      for y = this.carPos(2):this.carPos(2)+this.formulaH-1
        for x = this.carPos(1):this.carPos(1)+this.formulaW-1
          if this.formula(yy,xx,1) ~= 175/255 %175 is the transparent "color" code
            this.display(y,x,1:3) = this.formula(yy,xx,1:3);%displays the formula pixel by pixel
          end
          xx = xx+1;
        end
        xx = 1;
        yy = yy+1;
      end
    end
  end
end

