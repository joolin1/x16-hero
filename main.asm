;*** main.asm - Entry point for game, setup and main game loop *************************************

!cpu 65c02
!to "hero.prg", cbm
;!sl "hero.sym"
!src "includes/x16.asm"
!src "includes/zsound.asm"

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

;*** Basic program ("1 SYS2061") *****************************************************************

*=$0801
; 	!byte $0E,$08,$0A,$00,$9E,$20,$32,$30,$36,$34,$00,$00,$00,$00,$00
; *=$0810

BASIC:	!BYTE $0B,$08,$01,$00,$9E,$32,$30,$36,$31,$00,$00,$00   ;Adds BASIC line:  1 SYS 2061

        jmp .StartGame

;It is required that zsound load in at $0810, because it is
;a pre-built binary compiled from C.  So, the binary is
;placed here in the source code, and as you can see there
;is a JMP command right before it to bypass it.  

!BINARY "ZSOUND.BIN"		;ZSsound program binary.

;pad 47 bytes for zsound variable space.
!BYTE	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
!BYTE	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

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
ST_DEATH_CREATURE  = 10  ;player has been killed by creature
ST_DEATH_EXPLOSION = 11  ;player has been killed by being to close to an explosion
ST_DEATH_LAVA      = 12  ;player has been killed by touching lava
ST_RESTARTLEVEL    = 13  ;restart level if lives left
ST_LEVELCOMPLETED  = 14  ;level/game completed
ST_LEVELCOMPLETED2 = 15  ;level/game completed step 2
ST_GAMEOVER        = 16  ;game over, no lives left
ST_GAMEOVER2       = 17  ;game over step 2
ST_ENTERHIGHSCORE  = 18  ;let player enter name for new high score
ST_QUITGAME        = 19  ;quit game

;*** Main program **********************************************************************************

.StartGame:
        ;init everything
        jsr LoadLeaderboard             ;load leaderboard, if not successful a new file will be created       
        jsr LoadResources               ;load all resources (graphics, music ...)
        bcc +
        rts                             ;exit if some resource failed to load
+       lda #ST_INITSTARTSCREEN
        sta _gamestatus
        jsr InitScreenAndSprites
        jsr InitJoysticks               ;check which type of joysticks (game controllers) are being used 
        jsr Z_init_player
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
.defaulthandler_lo 	!byte 0
.defaulthandler_hi	!byte 0
.vsynctrigger           !byte 0
.sprcolinfo             !byte 0

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
        ldx .sprcolinfo
        bne +
        sta .sprcolinfo
+       bit #1                          ;vertical blank interrupt?
        beq +
        sta .vsynctrigger
        sta VERA_ISR
        lda _gamestatus
        cmp #ST_RUNNING
        bne +
        jsr UpdateView                  ;update screen when game is running
+       jmp (.defaulthandler_lo)     

.QuitGame:                       
 	sei                             ;restore default irq handler
	lda .defaulthandler_lo
	sta IRQ_HANDLER_L
	lda .defaulthandler_hi
	sta IRQ_HANDLER_H
	cli
        jsr RestoreScreenAndSprites
        jsr Z_stopmusic
        rts

.GameTick:                              ;this subroutine is called every jiffy and advances the game one frame
        jsr GetJoys                     ;read game controllers and store for all routines to use           

        lda _gamestatus                 ;first of all check if game paused, then everything including sound effects should be freezed
        cmp #ST_PAUSED                  
        bne +
        jmp .HandlePause

+       jsr SfxTick                     ;update all sound effects that are currently playing
        jsr Z_playmusic                 ;continue to play music if something is currently playing

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
+       cmp #ST_DEATH_CREATURE          ;player has been killed
        bne +
        jmp .PlayerKilled
+       cmp #ST_DEATH_EXPLOSION
        bne +
        jmp .PlayerKilled
+       cmp #ST_DEATH_LAVA
        bne +
        jmp .PlayerKilled
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
        jsr .CheckForPause              ;check for pause before starting to change the model for next frame
        bcc +
        rts
+       jsr UpdateCreatures      
        jsr UpdatePlayerSprite 
        jsr UpdateLight
        jsr UpdateStatusTime
        jsr UpdateExplosion
        ;jsr DebugPrintInfo      ;TEMP
        
        lda .sprcolinfo
        beq ++
        and #$f0                        ;only keep collision info

        ;collision creature - creature
        cmp #$30
        bne +
        stz .sprcolinfo
        bra ++

        ;collision player - creature        
+       cmp #$10
        bne +
        jsr ShowDeadPlayer
        jsr StopPlayerSounds
        jsr PlayPlayerKilledSound 

        ; jsr KillPlayerAndCreature       ;OUT: .Y = creature index
        ; sty .creatureindex
        lda #ST_DEATH_CREATURE
        sta _gamestatus
        rts

        ;collision laserbeam - creature
+       cmp #$20
        bne +
        jsr KillCreature
        stz .sprcolinfo
        bra ++

        ;collision player - lamp
+       cmp #$40
        bne ++
        jsr TurnOffLight                ;collision between player and a lamp has occurred, turn off light and set dark time counter
        stz .sprcolinfo

++      jsr PlayerTick                  ;move hero and take actions depending on new position
        jsr UpdateCameraPosition        ;set camera in relation to where hero is
        jsr TimeTick
        lda _levelcompleted
        beq +
        lda #ST_LEVELCOMPLETED
        sta _gamestatus
        rts
+       ;lda _playerdead
        ;beq +
        ;lda #ST_DEATH
        ;sta _gamestatus
+       rts

.InitStartScreen:                       ;init start screen
        lda #ZSM_TITLE_BANK
        jsr StartMusic
	jsr ShowStartImage
	lda #ST_SHOWSTARTSCREEN
	sta _gamestatus
        lda #1
        sta .fromstartscreenflag
	rts

.fromstartscreenflag    !byte 0

.ShowStartScreen:                       ;start screen is displayed, wait for player to press something
	lda _joy0
	cmp #JOY_NOTHING_PRESSED
	beq +
	lda #ST_INITMENU
	sta _gamestatus
+	rts

.InitMenu:
        lda .fromstartscreenflag
        bne +
        jsr Z_stopmusic
        lda #ZSM_TITLE_BANK
        jsr StartMusic
        stz .fromstartscreenflag
+       jsr .InitMenuBackground
        jsr ClearTextLayer
        jsr EnableLayer1
        lda #ST_SHOWMENU
        sta _gamestatus
        lda #M_SHOW_MENU_SCREEN
        sta _menumode
        rts

.InitMenuBackground:
        jsr DisableLayer0
        jsr SetLayer0ToTileMode
	lda #0
        sta _level
	jsr InitLevel			;init level 0 which is a demo level used as a background for the menu
	lda #MENU_MAIN_POS              ;set camera position manually to show menu background
        sta _camxpos_lo
        stz _camxpos_hi
        lda #120
        sta _camypos_lo
        stz _camypos_hi
        jsr UpdateTilemap
	jsr InitCreatures
        jsr HidePlayer
        jsr TurnOnLight
        jsr EnableLayer0
        rts

.InitHighScoreBackground:
        jsr DisableLayer0
        jsr SetLayer0ToTileMode
	lda #0
        sta _level
	jsr InitLevel			;init level 0 which is a demo level used as a background for the menu
	lda #<MENU_HIGH_POS             ;set camera position manually to show high score background
	sta _camxpos_lo
	lda #>MENU_HIGH_POS
        sta _camxpos_hi
	lda #120
	sta _camypos_lo
	stz _camypos_hi
        jsr UpdateTilemap
	jsr InitCreatures
        jsr HidePlayer
        jsr TurnOnLight
        jsr EnableLayer0
        rts

.EnterHighScore:
	jsr HighScoreInput
	bcs +
	rts
+       lda #ST_SHOWMENU
	sta _gamestatus
        lda #M_SHOW_MENU_SCREEN
        sta _menumode
       	lda #MENU_MAIN_POS              ;set camera position manually to show menu background
	sta _camxpos_lo
	stz _camxpos_hi
	lda #120
	sta _camypos_lo
	stz _camypos_hi
        jsr UpdateTilemap
        jsr Z_stopmusic
        lda #ZSM_TITLE_BANK
        jsr StartMusic
	rts

.ShowMenu:      
        jsr MenuHandler                 ;all routines for the menu is in menu.asm
        jsr UpdateCreatures
        rts

.InitGame:
        jsr Z_stopmusic
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
        jsr ShowPlayer
        jsr TurnOnLight
        jsr EnableLayer0
        lda #ST_RUNNING
        sta _gamestatus
        rts

.RestartLevel:
        jsr UpdateStatusBar
        jsr ShowPlayer
        lda #ST_RUNNING
        sta _gamestatus
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
+       jsr StopPlayerSounds
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
        jsr UpdateStatusBar
        jsr PlayEngineSound     ;start engine sounds again
        lda #ST_RUNNING         ;resume game excactly where we were (= do not initialize any variables)
        sta _gamestatus
        rts

.PlayerKilled:                  ;player killed by a creature, a too close explosion or touching lava
        +CheckTimer2 .deaddelay, DEAD_DELAY     ;returns .A = true if timer ready  
        bne +
        rts 
+       lda _gamestatus
        cmp #ST_DEATH_CREATURE
        bne +
        jsr KillPlayerAndCreature               ;OUT: .Y = creature index
        jsr DisableCreatureSprite               ;player looses a life but at least the creature is killed/removed too ...
        stz .sprcolinfo                         ;allow new collisions
+       cmp #ST_DEATH_LAVA
        bne +
        jsr MovePlayerBack                      ;move player to former position to avoid dying over and over again ...
+       dec _lives
        bne +
        lda #ST_GAMEOVER
        sta _gamestatus
        rts
+       lda #ST_RESTARTLEVEL
        sta _gamestatus
        rts

DEAD_DELAY = 120
.deaddelay      !byte 0

.LevelCompleted:                         ;level and maybe game completed step 1
        jsr StopPlayerSounds
        jsr StopLaser
        jsr PlayFinishedSound
        lda _minutes
        sta _lastlevel_minutes
        lda _seconds
        sta _lastlevel_seconds          ;save game time at this moment, if player fails to complete next level this time is used for the high score table
        lda _level
        cmp #LEVEL_COUNT
        bne +
        jsr PrintGameCompleted  ;game completed
        bra ++
+       jsr PrintLevelFinished  ;level completed
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

LEVEL_COMPLETED_DELAY    = 240
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
        lda _lastlevel_minutes
        sta _minutes                    ;set back time to when last level was completed
        lda _lastlevel_seconds
        sta _seconds
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
        lda _minutes                    ;set back time to when last level was completed
        sta ZP1
        lda _seconds
        sta ZP2
        jsr GetHighScoreRank
        cmp #LB_ENTRIES_COUNT
        bcs +
        lda #ZSM_HIGHSCORE_BANK
        jsr StartMusic
        jsr InitHighScoreInput
        lda _level
        pha
        jsr .InitHighScoreBackground
        pla
        sta _level
        lda #ST_ENTERHIGHSCORE       ;player has a new high score!
        sta _gamestatus
        rts
+       lda #ST_INITMENU             ;go directly to menu if no high score
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

