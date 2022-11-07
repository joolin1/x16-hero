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
ST_MENU           = 0   ;show start screen or menu
ST_INITLEVEL      = 1   ;init level and player
ST_RESUMEGAME     = 2   ;resume game 
ST_RUNNING        = 3   ;normal gameplay
ST_PAUSED         = 4   ;game paused
ST_KILL           = 5   ;player has killed a creature
ST_DEATH          = 6   ;player has been killed
ST_RESTARTLEVEL   = 7   ;restart level if lives left
ST_LEVELFINISHED  = 8   ;level finished
ST_ENDGAME        = 9   ;no more lives, end game
ST_GAMEOVER       = 10  ;wait for player to continue
ST_GAMECOMPLETED  = 11  ;all levels are completed!
ST_QUITGAME       = 12  ;quit game

LIFE_COUNT        = 2   ;number of lives for player
LEVEL_COUNT       = 2   ;number of levels in game

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
_lifecount              !byte 0     
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
        ;sta VERA_ISR
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
+       cmp #ST_LEVELFINISHED
        bne +
        jmp .LevelFinished
+       cmp #ST_ENDGAME
        bne +
        jmp .EndGame
+       cmp #ST_GAMEOVER                ;wait for input from player
        bne +
        jmp .GameOver
+       cmp #ST_GAMECOMPLETED
        bne +
        jmp .GameCompleted
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
        lda #ST_DEATH                   ;collision between player and a creature has occurred
        sta _gamestatus
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
++      jsr CreaturesTick               ;calculate all sprite data - which are visible, their position etc
        jsr PlayerTick                  ;move hero and take actions depending on new position
        lda _levelcompleted
        beq +
        lda #ST_LEVELFINISHED
        sta _gamestatus
+       rts

.ShowMenu:
        jsr DisableLayer0
        jsr EnableLayer1
        jsr MenuHandler

        lda #LIFE_COUNT                 ;init game
        sta _lifecount
        lda #1
        sta _level
        rts

.InitLevel:
        jsr InitLevel
        jsr InitCreatures
        jsr UpdateView
        jsr ShowPlayer
        jsr EnableLayer0
        lda #ST_RUNNING
        sta _gamestatus
        rts

.RestartLevel:
        jsr RestartLevel
        ;jsr RestartCreatures
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
+       dec _lifecount
        bne +
        lda #ST_ENDGAME
        sta _gamestatus
        rts
+       lda #ST_RESTARTLEVEL
        sta _gamestatus
        rts

.LevelFinished:
        inc .levelfinisheddelay
        lda .levelfinisheddelay
        cmp #LEVEL_FINISHED_DELAY
        beq +
        rts
+       stz .levelfinisheddelay
        lda _level
        cmp #LEVEL_COUNT
        beq +
        inc _level
        lda #ST_INITLEVEL
        sta _gamestatus
        rts
+       lda #ST_GAMECOMPLETED
        sta _gamestatus
        rts

LEVEL_FINISHED_DELAY    = 60
.levelfinisheddelay     !byte 0

.EndGame:            
        ;jsr CheckForRecord
        jsr PrintBoard
        jsr PlayFinishedSound
        lda #ST_GAMEOVER
        sta _gamestatus
        rts

.GameOver:
        lda _boardinputflag     ;check if we should wait for player to enter name because of new record
        beq +
        jsr .WaitForPlayerName
        rts
+       lda _joy0
        and #JOY_BUTTON_A
        beq +
        rts
+       jsr HidePlayer
        jsr HideCreatures
        jsr DisableLayer0       ;temporary disable layer 0 while preparing main menu
        lda #ST_MENU
        sta _gamestatus
        stz .sprcoltrigger
        rts

.WaitForPlayerName:
        jsr InputString         ;receive input and blink cursor
        bcs +                   
        rts
+       stz _boardinputflag
        lda _level
        jsr SetLeaderboardName
        jsr SaveLeaderboard
        jsr HidePlayer
        jsr HideCreatures
        lda #ST_MENU
        sta _gamestatus
        stz .sprcoltrigger
        rts

.GameCompleted:
        !byte $db
        ;TODO...
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

