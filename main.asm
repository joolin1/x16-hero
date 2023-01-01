;*** main.asm - Entry point for game, setup and main game loop *************************************

!cpu 65c02
!to "hero.prg", cbm
!sl "hero.sym"
!src "includes/x16.asm"

!macro CheckTimer2 .counter, .limit {        ;IN: address of counter, limit as immediate value. OUT: .A = true if counter has reached its goal otherwise false 
        inc .counter
        lda .counter
        cmp #.limit
        bne +
        stz .counter
        lda #1
        bra ++
+       lda #0
++
}

;*** Basic program ("10 SYS 2064") *****************************************************************

*=$0801
	!byte $0E,$08,$0A,$00,$9E,$20,$32,$30,$36,$34,$00,$00,$00,$00,$00
*=$0810

;*** Game globals **********************************************************************************

;Status for game
ST_INITSTARTSCREEN = 0   ;set up start screen
ST_SHOWSTARTSCREEN = 1   ;display start screen
ST_INITMENU        = 2   ;set up menu background
ST_SHOWMENU        = 3   ;show menu, high scores or credits
ST_INITGAME        = 4   ;init new game
ST_INITLEVEL       = 5   ;init level and player
ST_RESUMEGAME      = 6   ;resume game 
ST_RUNNING         = 7   ;normal gameplay
ST_PAUSED          = 8   ;game paused
ST_KILL            = 9   ;player has killed a creature
ST_DEATH           = 10  ;player has been killed
ST_RESTARTLEVEL    = 11  ;restart level if lives left
ST_LEVELCOMPLETED  = 12  ;level/game completed
ST_LEVELCOMPLETED2 = 13  ;level/game completed step 2
ST_GAMEOVER        = 14  ;game over, no lives left
ST_GAMEOVER2       = 15  ;game over step 2
ST_ENTERHIGHSCORE  = 16  ;let player enter name for new high score
ST_QUITGAME        = 17  ;quit game

;*** Main program **********************************************************************************

.StartGame:
        ;init everything
        jsr LoadLeaderboard             ;load leaderboard, if not successful a new file will be created       
        jsr LoadGraphics                ;load tiles and sprites from disk to VRAM
        bcc +
        rts                             ;exit if some resource failed to load
+       lda #ST_INITSTARTSCREEN
        sta _gamestatus
        jsr InitScreenAndSprites
        jsr InitJoysticks               ;check which type of joysticks (game controllers) are being used 
        jsr .SetupIrqHandler

        ;main loop
-       !byte $cb		        ;wait for an interrupt to trigger (ACME does not know the opcode WAI)
        lda .vsynctrigger               ;check if interrupt was triggered by on vertical blank
        beq -
        ;jsr ChangeDebugColor
        jsr .GameTick
        ;jsr RestoreDebugColor
        stz .vsynctrigger     
        lda _gamestatus
        cmp #ST_QUITGAME 
        bne -
        jsr .QuitGame
        rts

_gamestatus             !byte 0       
_noofplayers	        !byte 1    
.defaulthandler_lo 	!byte 0
.defaulthandler_hi	!byte 0
.vsynctrigger           !byte 0
.sprcolinfo             !byte 0
.sprcol_disabled        !byte 0

.SetupIrqHandler:
        sei
	lda IRQ_HANDLER_L	        ;save original IRQ handler
	sta .defaulthandler_lo
	lda IRQ_HANDLER_H
	sta .defaulthandler_hi
	lda #<.IrqHandler	        ;set custom IRQ handler
	sta IRQ_HANDLER_L
	lda #>.IrqHandler
	sta IRQ_HANDLER_H	
	lda #5                          ;enable vertical blanking and sprite collision interrupts
	sta VERA_IEN
	cli
        rts

.IrqHandler:
        lda VERA_ISR
        sta VERA_ISR
        bit #4                          ;sprite collision interrupt?
        beq +
        ldx .sprcol_disabled
        bne +
        ldx .sprcolinfo
        bne +
        and #%11110000                  ;keep only collision info
        sta .sprcolinfo                 ;save info about collision
        jmp (.defaulthandler_lo)
+       bit #1                          ;vertical blank interrupt?
        beq +
        sta .vsynctrigger
        sta VERA_ISR
        lda _gamestatus
        cmp #ST_RUNNING
        bne +
        jsr UpdateView                  ;update screen when game is running
+       cmp #ST_SHOWMENU
        bne +
        jsr UpdateView                  ;update demo background (level 0) when menu is displayed
+       jmp (.defaulthandler_lo)     

.QuitGame:                       
 	sei                             ;restore default irq handler
	lda .defaulthandler_lo
	sta IRQ_HANDLER_L
	lda .defaulthandler_hi
	sta IRQ_HANDLER_H
	cli
        jsr RestoreScreenAndSprites
        rts

.GameTick:                              ;this subroutine is called every jiffy and advances the game one frame
        jsr GetJoys                     ;read game controllers and store for all routines to use           

        lda _gamestatus                 ;first of all check if game paused, then everything including sound effects should be freezed
        cmp #ST_PAUSED                  
        bne +
        jmp .HandlePause

+       jsr SfxTick                     ;update all sound effects that are currently playing

        lda _gamestatus
        cmp #ST_RUNNING                 ;gameplay is running
        bne +
        jmp .LevelTick
+       cmp #ST_INITSTARTSCREEN
        bne +
        jmp .InitStartScreen
+       cmp #ST_SHOWSTARTSCREEN
        bne +
        jmp .ShowStartScreen
+       cmp #ST_INITMENU
        bne +
        jmp .InitMenu
+       cmp #ST_SHOWMENU                    ;show start screen and menu
        bne +
        jmp .ShowMenu
+       cmp #ST_INITGAME
        bne +
        jmp .InitGame
+       cmp #ST_INITLEVEL               ;init level, prepare everything
        bne +
        jmp .InitLevel
+       cmp #ST_RESUMEGAME              ;resume game after pause or player killed
        bne +
        jmp .ResumeGame
+       cmp #ST_DEATH                   ;player has been killed
        bne +
        jmp .HandleDeath
+       cmp #ST_RESTARTLEVEL
        bne +
        jmp .RestartLevel
+       cmp #ST_LEVELCOMPLETED
        bne +
        jmp .LevelCompleted
+       cmp #ST_LEVELCOMPLETED2
        bne +
        jmp .LevelCompleted2
+       cmp #ST_GAMEOVER
        bne +
        jmp .GameOver
+       cmp #ST_GAMEOVER2               ;wait for input from player
        bne +
        jmp .GameOver2
+       cmp #ST_ENTERHIGHSCORE
        bne +
        jmp .EnterHighScore
+       rts

.LevelTick:
+       jsr .CheckForPause              ;check for pause before starting to change the model for next frame
        bcc +
        rts
+       lda .sprcolinfo
        beq ++
        and #$f0
        cmp #$10
        bne +
        jsr KillPlayer
        lda #ST_DEATH                   ;collision between player and a creature has occurred
        sta _gamestatus
        stz .sprcolinfo
        lda #1
        sta .sprcol_disabled            ;sprite collisions need bo be disabled to prevent a new collision immediately after, not sure exactly why ...
        rts
+       cmp #$20
        bne +
        jsr KillCreature                ;collision between laserbeam and a creature has occurred
        stz .sprcolinfo
        bra ++
+       cmp #$40
        bne ++
        jsr TurnOffLight                ;collision between player and a lamp has occurred, turn off light and set dark time counter
        stz .sprcolinfo
++      jsr PlayerTick                  ;move hero and take actions depending on new position
        jsr CreaturesTick               ;calculate all sprite data - which are visible, their position in relation to player etc
        jsr TimeTick
        lda _levelcompleted
        beq +
        lda #ST_LEVELCOMPLETED
        sta _gamestatus
+       rts

.InitStartScreen:                       ;init start screen
	jsr ShowStartImage
	lda #ST_SHOWSTARTSCREEN
	sta _gamestatus
	rts

.ShowStartScreen:                       ;start screen is displayed, wait for player to press something
	lda _joy0
	cmp #JOY_NOTHING_PRESSED
	beq +
	lda #ST_INITMENU
	sta _gamestatus
+	rts

.InitMenu:
        jsr DisableLayer0
        jsr SetLayer0ToTileMode
	lda #0
        sta _level
        ;stz _level
	jsr InitLevel			;init level 0 which is a demo level used as a background for the menu
	lda #MENU_MAIN_POS              ;set camera position manually
	sta _xpos_lo
	stz _xpos_hi
	lda #120
	sta _ypos_lo
	stz _ypos_hi
	jsr InitCreatures
        jsr HidePlayer
        jsr EnableLayer0
        jsr ClearTextLayer
        jsr EnableLayer1
        lda #ST_SHOWMENU
        sta _gamestatus
        lda #M_SHOW_MENU_SCREEN
        sta _menumode
        rts

.ShowMenu:      
        jsr MenuHandler                 ;all routines for the menu is in menu.asm
        +CheckTimer2 .creaturedelay, 2  ;slow down creature movement
        beq +
        jsr CreaturesTick
+       rts

.creaturedelay  !byte 0

.InitGame:
        lda #LIFE_COUNT                 ;init game
        sta _lives
        lda _startlevel
        sta _level
        jsr InitTimer
        lda #ST_INITLEVEL
        sta _gamestatus
        rts

.InitLevel:
        jsr DisableLayer0
        jsr ClearTextLayer
        jsr InitLevel
        jsr InitPlayer
        jsr InitCreatures
        jsr UpdateStatusBar
        jsr UpdateView
        jsr ShowPlayer
        jsr TurnOnLight
        jsr EnableLayer0
        lda #ST_RUNNING
        sta _gamestatus
        rts

.RestartLevel:
        ;jsr RestartLevel
        ;jsr RestartCreatures
        jsr CreaturesTick       ;make sure to update creature data before updating view
        jsr PlayerTick
        jsr UpdateStatusBar
        jsr UpdateView
        jsr ShowPlayer
        lda #ST_RUNNING
        sta _gamestatus
        stz .sprcol_disabled
        rts       

.ResumeGame:
        jsr ShowPlayer
        lda _isflying
        beq +
        jsr PlayEngineSound
+       jsr UpdateView
        lda #ST_RUNNING
        sta _gamestatus
        rts

.CheckForPause:
        lda _joy0
        and #JOY_START
        beq +
        clc
        rts
+       jsr StopCarSounds
        jsr ShowPauseMenu    
        lda #ST_PAUSED
        sta _gamestatus
        sec
        rts
 
.HandlePause:                   ;pause is made by just cutting sound and stop movement
        jsr UpdatePauseMenu     ;OUT: .A = seleced menu item. -1 = nothing selected
        cmp #-1
        bne +
        rts
+       cmp #0
        beq +
        jsr HidePlayer
        jsr HideCreatures
        lda #ST_INITMENU
        sta _gamestatus         ;quit game
        rts
+       jsr ClearTextLayer
        jsr PlayEngineSound     ;start engine sounds again
        lda #ST_RUNNING         ;resume game excactly where we were (= do not initialize any variables)
        sta _gamestatus
        rts

.HandleDeath:                   ;collision between player and a creature has occurred
        jsr StopLaser
        jsr StopCarSounds
        jsr KillPlayer          ;returns true when totally dead...
        bne +
        rts
+       dec _lives
        bne +
        lda #ST_GAMEOVER
        sta _gamestatus
        rts
+       lda #ST_RESTARTLEVEL
        sta _gamestatus
        rts

.LevelCompleted:                         ;level and maybe game completed step 1
        lda _minutes
        sta _lastlevel_minutes
        lda _seconds
        sta _lastlevel_seconds          ;save game time at this moment, if player fails to complete next level this time is used for the high score table
        lda _level
        cmp #LEVEL_COUNT
        bne +
        ;game completed
        jsr PlayFinishedSound
        jsr PrintGameCompleted
        bra ++
        ;level completed
+       jsr PlayFinishedSound
        jsr PrintLevelFinished
++      lda #ST_LEVELCOMPLETED2
        sta _gamestatus
        rts

_lastlevel_minutes      !byte 0
_lastlevel_seconds      !byte 0

.LevelCompleted2:                       ;level and maybe game completed step 2
        +CheckTimer2 .levelcompleteddelay, LEVEL_COMPLETED_DELAY
        bne +
        rts

+       lda _level
        cmp #LEVEL_COUNT
        bne +
        ;game completed
        jsr .RestartGame
        rts
        ;level completed
+       inc _level
        lda #ST_INITLEVEL
        sta _gamestatus                 ;short delay before going to next level
        rts

LEVEL_COMPLETED_DELAY    = 180
.levelcompleteddelay     !byte 0

.GameOver:                              ;game over step 1
        jsr PlayFinishedSound
        jsr PrintGameOver
        lda #ST_GAMEOVER2
        sta _gamestatus
        rts

.GameOver2:                             ;game over step 2
        +CheckTimer2 .gameoverdelay, GAME_OVER_DELAY
        beq +
        jsr .RestartGame                ;short delay before going to menu
+       rts

GAME_OVER_DELAY = 180
.gameoverdelay  !byte 0

.RestartGame:                           ;help function
        jsr HidePlayer
        jsr HideCreatures
        stz .sprcolinfo
        jsr GetSavedMinersCount
        sta ZP0
        lda _lastlevel_minutes
        sta _minutes                    ;set back time to when last level was completed
        sta ZP1
        lda _lastlevel_seconds
        lda _seconds
        sta ZP2
        jsr GetHighScoreRank
        cmp #LB_ENTRIES_COUNT
        bcs +
        jsr InitHighScoreInput
        lda #ST_ENTERHIGHSCORE       ;player has a new high score!
        sta _gamestatus
        rts
+       lda #ST_INITMENU             ;go directly to menu if no high score
        sta _gamestatus
        rts

.EnterHighScore:
	jsr HighScoreInput
	bcs +
	rts
+       lda #ST_INITMENU
	sta _gamestatus
	rts

;*** Other source files ****************************************************************************

;*** library files *********************
!zone
!src "libs/mathlib.asm"
!src "libs/veralib.asm"
!src "libs/filelib.asm"
!src "libs/textlib.asm"
!src "libs/helperslib.asm"
!src "libs/joysticklib.asm"
!src "libs/timerlib.asm"
!src "libs/debug.asm"

;*** View *****************************
!zone
!src "view/view.asm"
!src "view/screen.asm"
!src "view/resources.asm"
!src "view/soundfx.asm"
!src "view/playersprites.asm"
!src "view/creaturesprites.asm"
!src "view/miscsprites.asm"

;*** Model *****************************
!src "model/level.asm"
!src "model/player.asm"
!src "model/creatures.asm"
!src "model/collision.asm"

;*** User interface *******************
!zone
!src "userinterface/menu.asm"
!zone
!src "userinterface/leaderboard.asm"
!zone
!src "userinterface/board.asm"

