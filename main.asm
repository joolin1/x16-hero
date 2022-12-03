;*** main.asm - Entry point for game, setup and main game loop *************************************

!cpu 65c02
!to "hero.prg", cbm
!sl "hero.sym"
!src "includes/x16.asm"

;*** Basic program ("10 SYS 2064") *****************************************************************

*=$0801
	!byte $0E,$08,$0A,$00,$9E,$20,$32,$30,$36,$34,$00,$00,$00,$00,$00
*=$0810

;*** Game globals **********************************************************************************

;Status for game
ST_MENU            = 0   ;show start screen or menu
ST_INITGAME        = 1   ;init new game
ST_INITLEVEL       = 2   ;init level and player
ST_RESUMEGAME      = 3   ;resume game 
ST_RUNNING         = 4   ;normal gameplay
ST_PAUSED          = 5   ;game paused
ST_KILL            = 6   ;player has killed a creature
ST_DEATH           = 7   ;player has been killed
ST_RESTARTLEVEL    = 8   ;restart level if lives left
ST_LEVELCOMPLETED  = 9   ;level/game completed
ST_LEVELCOMPLETED2 = 10  ;level/game completed step 2
ST_GAMEOVER        = 11  ;game over, no lives left
ST_GAMEOVER2       = 12  ;game over step 2
ST_QUITGAME        = 13  ;quit game

;*** Main program **********************************************************************************

.StartGame:
        ;init everything
        jsr LoadLeaderboard             ;load leaderboard, if not successful a new file will be created       
        jsr LoadGraphics                ;load tiles and sprites from disk to VRAM
        bcc +
        rts                             ;exit if some resource failed to load
+       lda #ST_MENU
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
.sprcoltrigger          !byte 0

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
        ldx .sprcoltrigger
        bne +
        and #%11110000                  ;keep only collision info
        sta .sprcoltrigger              ;save info about collision
        jmp (.defaulthandler_lo)
+       bit #1                          ;vertical blank interrupt?
        beq +
        sta .vsynctrigger
        sta VERA_ISR
        lda _gamestatus
        cmp #ST_RUNNING
        bne +
        jsr UpdateView
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
+       cmp #ST_MENU                    ;show start screen and menu
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
+       rts

.LevelTick:
+       jsr .CheckForPause              ;check for pause before starting to change the model for next frame
        bcc +
        rts
+       lda .sprcoltrigger
        beq ++
        and #$f0
        cmp #$10
        bne +
        jsr KillPlayer
        lda #ST_DEATH                   ;collision between player and a creature has occurred
        sta _gamestatus
        stz .sprcoltrigger
        rts
+       cmp #$20
        bne +
        jsr KillCreature                ;collision between laserbeam and a creature has occurred
        stz .sprcoltrigger
        bra ++
+       cmp #$40
        bne ++
        jsr TurnOffLight                ;collision between player and a lamp has occurred, turn off light and set dark time counter
        stz .sprcoltrigger
++      jsr PlayerTick                  ;move hero and take actions depending on new position
        jsr CreaturesTick               ;calculate all sprite data - which are visible, their position in relation to player etc
        jsr TimeTick
        lda _levelcompleted
        beq +
        lda #ST_LEVELCOMPLETED
        sta _gamestatus
+       rts

.ShowMenu:
        jsr MenuHandler
        rts

.InitGame:
        lda #LIFE_COUNT                 ;init game
        sta _lives
        lda _startlevel
        sta _level
        jsr InitTimer
        jsr SetLayer0ToTileMode
        jsr EnableLayer1
        lda #ST_INITLEVEL
        sta _gamestatus
        rts

.InitLevel:
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
        jsr CreaturesTick
        jsr UpdateStatusBar
        jsr UpdateView
        jsr ShowPlayer
        lda #ST_RUNNING
        sta _gamestatus
        stz .sprcoltrigger
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
        lda #ST_MENU
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
        stz .sprcoltrigger
        rts

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

.LevelCompleted:                         ;level and maybe game completed step 1
        lda _level
        cmp #LEVEL_COUNT
        bne +
        ;game completed
        jsr PlayFinishedSound
        jsr PrintGameCompletedBoard
        bra ++
        ;level completed
+       jsr PlayFinishedSound
        jsr PrintLevelCompletedBoard        
++      lda #ST_LEVELCOMPLETED2
        sta _gamestatus
        rts

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
        jsr PrintGameOverBoard
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
        stz .sprcoltrigger
        jsr GetSavedMinersCount
        sta ZP0
        lda _minutes
        sta ZP1
        lda _seconds
        sta ZP2
        jsr GetHighScoreRank
        cmp #LB_ENTRIES_COUNT
        bcs +
        lda #M_ENTER_NEW_HIGH_SCORE     ;player has a new high score!
        sta _menumode
+       lda #ST_MENU
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
!src "view/textsprites.asm"
!src "view/badgesprites.asm"

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

