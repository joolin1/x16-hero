;*** Menu.asm - Start screen, menu, credits ********************************************************

;Menu status
M_SHOW_MENU_SCREEN  	 = 0
M_SHOW_HIGHSCORE_SCREEN  = 1
M_ENTER_NEW_HIGH_SCORE   = 2
M_ENTER_NEW_HIGH_SCORE_2 = 3
M_SHOW_CREDIT_SCREEN	 = 4
M_HANDLE_INPUT 			 = 5

INACTIVITY_DELAY = 3

;*** Public methods ********************************************************************************

MenuHandler:
	lda _menumode

	;show menu
    cmp #M_SHOW_MENU_SCREEN
	bne +
	jsr .ShowMenuScreen
	lda #M_HANDLE_INPUT				;next go to input menu mode
	sta _menumode
	lda #1
	sta .inputwait					;wait for controller to be released before accepting input again
	stz .inactivitytimer_lo			;reset timer that takes user back to start screen after 30 secs inactivity
	stz .inactivitytimer_hi
	rts

    ;show highscore screen
+   cmp #M_SHOW_HIGHSCORE_SCREEN
	bne ++
	lda .inactivitytimer_hi
	cmp #INACTIVITY_DELAY
	bne +
	lda #M_SHOW_CREDIT_SCREEN		;show credit screen after a certain delay
	sta _menumode
	jsr .ShowCreditScreen
    stz .inactivitytimer_lo
	stz .inactivitytimer_hi
	rts
+	+GetJoy0_NoRepeat .highscorewait
	cmp #JOY_NOTHING_PRESSED
	bne +
	+Inc16 .inactivitytimer_lo
	rts
+	bit #JOY_RIGHT
	bne +
	lda #M_SHOW_CREDIT_SCREEN		;show credit screeen if user presses right
	sta _menumode
	jsr .ShowCreditScreen
    stz .inactivitytimer_lo
	stz .inactivitytimer_hi
	lda #1
	sta .creditwait					
	rts
+   lda #M_SHOW_MENU_SCREEN
	sta _menumode					;show menu if user presses anything else
	rts

    ;show credit screen
++  cmp #M_SHOW_CREDIT_SCREEN
	bne ++
	lda .inactivitytimer_hi
	cmp #INACTIVITY_DELAY
	bne +
	lda #M_SHOW_MENU_SCREEN			;show menu screen after a certain delay
	sta _menumode
	rts
+	+GetJoy0_NoRepeat .creditwait
	cmp #JOY_NOTHING_PRESSED
	bne +
	+Inc16 .inactivitytimer_lo
	rts
+	bit #JOY_LEFT
	bne +
	lda #M_SHOW_HIGHSCORE_SCREEN
	sta _menumode
	jsr .ShowHighScoreScreen
	stz .inactivitytimer_lo
	stz .inactivitytimer_hi
	lda #1
	sta .highscorewait
	rts
+	lda #M_SHOW_MENU_SCREEN			;show menu directly if user presses anything
	sta _menumode
	rts

	;handle user input
++	cmp #M_HANDLE_INPUT
	beq +
	rts

+   lda .inactivitytimer_hi
	cmp #INACTIVITY_DELAY

	bne +
	lda #M_SHOW_HIGHSCORE_SCREEN
	sta _menumode
	jsr .ShowHighScoreScreen
	stz .inactivitytimer_lo
	stz .inactivitytimer_hi
	rts

+	jsr .HandleUserInput
	rts

+	
_menumode				!byte 0
.inactivitytimer_lo		!byte 0		;timer to measure user inactivity
.inactivitytimer_hi		!byte 0
.highscorewait			!byte 0
.creditwait				!byte 0

;*** Private methods *******************************************************************************

.HandleUserInput:
	lda _joy0
	cmp #JOY_NOTHING_PRESSED	;prevent repeating
	bne ++
	stz .inputwait				;nothing pressed - ready for input again
	inc .inactivitytimer_lo		;increase timer for user's inactivity
	bne +
	inc .inactivitytimer_hi
+	rts

++  lda .inputwait				;if true skip reading controller
	beq +
	rts

+	lda #1
	sta .inputwait				;flag that something has been pressed so we can wait until controller released before accepting new input
	stz .inactivitytimer_lo		;reset timer user's inactivity
	stz .inactivitytimer_hi

	jsr .HandleUpDown
	jsr .HandleLeftRight
	jsr .HandleButton
	lda .levelconfirmationflag
	bne +
	lda .resetconfirmationflag
	bne +
	lda .quitconfirmationflag
	bne +
	lda _menumode
	cmp #M_HANDLE_INPUT
	bne +
	jsr .UpdateMainMenu
+	rts

.HandleUpDown:					;up down moves hand up and down
	lda _joy0
	bit #JOY_UP					;up?
	bne +
	jsr .DecreaseHandrow
	stz .resetconfirmationflag	;cancel possible confirmation questions if user moves away from question
	stz .quitconfirmationflag
	stz .levelconfirmationflag
	rts
+	bit #JOY_DOWN				;down?
	bne +
	jsr .IncreaseHandrow
	stz .resetconfirmationflag	;cancel possible confirmation questions if user moves away from question
	stz .quitconfirmationflag
	stz .levelconfirmationflag
+	rts

.IncreaseHandrow:
	jsr .ClearHand
	inc .handrow
	lda .handrow
	cmp #MENU_ITEMS_COUNT
	bne +
	stz .handrow
+	rts

.DecreaseHandrow:
	jsr .ClearHand
	dec .handrow
	bpl +
	lda #MENU_ITEMS_COUNT-1
	sta .handrow
+	rts

.handrow	!byte 0

.HandleLeftRight:				;left right toggles true/false for confirmation questions.
	lda .resetconfirmationflag
	bne .HandleConfirmationLeftRight
	lda .quitconfirmationflag
	bne .HandleConfirmationLeftRight
	lda .levelconfirmationflag
	bne .HandleSetValueLeftRight
	lda _joy0
	bit #JOY_LEFT
	bne +
	lda #M_SHOW_CREDIT_SCREEN		;show credit screeen if user presses left
	sta _menumode
	jsr .ShowCreditScreen
    stz .inactivitytimer_lo
	stz .inactivitytimer_hi
	lda #1
	sta .creditwait
	rts	
+	bit #JOY_RIGHT
	bne +
	lda #M_SHOW_HIGHSCORE_SCREEN	;show high score screen if user presses right
	sta _menumode
	jsr .ShowHighScoreScreen
	stz .inactivitytimer_lo
	stz .inactivitytimer_hi
	lda #1
	sta .highscorewait
+	rts

.HandleSetValueLeftRight:
	lda _joy0
	bit #JOY_LEFT
	bne ++
	dec _startlevel
	bne +
	inc _startlevel
+	jsr .PrintCurrentStartLevel
	rts
++	lda _joy0
	bit #JOY_RIGHT
	beq +
	rts
+	inc _startlevel
	lda _startlevel
	cmp _leaderboard_start_high
	bcc +
	lda _leaderboard_start_high
	sta _startlevel
+	jsr .PrintCurrentStartLevel		
 	rts

.HandleConfirmationLeftRight:
    lda _joy0
 	bit #JOY_LEFT				;left?
	bne +
	lda .answer					
	bne +
	lda #1
	sta .answer					;set answer to true if false
	jsr .PrintCurrentAnswer
	rts
+	lda _joy0
	bit #JOY_RIGHT				;right?
	bne +
	lda .answer
	beq +
	stz .answer					;set answer to false if true
	jsr .PrintCurrentAnswer
+	rts

.inputwait	!byte 0				;boolean, when true wait for user to release controller

.HandleButton:
	;button a pressed?
	lda _joy0
	bit #JOY_BUTTON_A
	beq +
	rts

	;take action depending on current menu item
+	lda .handrow
	cmp #START_GAME
	bne +
	jsr .CloseMainMenu
	rts

+   cmp #SET_START_LEVEL
	bne +
	lda .levelconfirmationflag
	bne +
	jsr .HandleSetStartLevel
	rts

+	cmp #RESET_BEST
	bne +
	jsr .HandleResetLeaderboard
	rts

+	cmp #QUIT_GAME
	bne +
	jsr .HandleQuitGame
+	rts

.CloseMainMenu:
	lda #M_SHOW_MENU_SCREEN
	sta _menumode			;prepare for the next time the menu handler will be called, then we skip start screen and go directly to the main menu
	lda #ST_INITGAME
	sta _gamestatus         ;update game status to start game, the menu handler will no longer be called
	rts

.HandleSetStartLevel:
	lda .levelconfirmationflag
	bne +
	jsr .PrintSetStartLevel
	lda #1
	sta .levelconfirmationflag
	rts
+	stz .levelconfirmationflag
	lda .answer
	beq +
	sta _startlevel
+	lda #M_HANDLE_INPUT
	sta _menumode
	rts

.levelconfirmationflag !byte 0	;flag that start level is waiting to be set

.HandleResetLeaderboard:
	lda .resetconfirmationflag
	bne +
	jsr .PrintConfirmationQuestion
	lda #1
	sta .resetconfirmationflag
	rts
+	stz .resetconfirmationflag
	lda .answer
	beq +
	jsr ResetLeaderboard
	jsr SaveLeaderboard
	jsr .ShowHighScoreScreen
	lda #1
	sta .resetconfirmationflag
	sta .highscorewait	;wait for player to release everything to prevent immediate shift from high score table to menu 
	lda #M_SHOW_HIGHSCORE_SCREEN
	sta _menumode
    stz .inactivitytimer_lo
	stz .inactivitytimer_hi
	rts
+	lda #M_HANDLE_INPUT
	sta _menumode
	rts

.resetconfirmationflag	!byte 0		;flag that confirmation question is waiting for an answer

.HandleQuitGame:
	lda .quitconfirmationflag
	bne +
	jsr .PrintConfirmationQuestion
	lda #1
	sta .quitconfirmationflag
	rts
+	stz .quitconfirmationflag	
	lda .answer
	beq +
	lda #ST_QUITGAME
	sta _gamestatus					;set game status to break main loop, clean up and exit
	rts
+	lda #M_HANDLE_INPUT
	sta _menumode
	rts

.quitconfirmationflag	!byte 0		;flag that confirmation question is waiting for an answer

.PrintSetStartLevel:
	+SetPrintParams LEVEL_ROW, MENU_COL, MENU_BLACK
	lda #<.setleveltext
	sta ZP0
	lda #>.setleveltext
	sta ZP1
	jsr VPrintString
	+SetPrintParams LEVEL_ROW, ARROW_POSITIONS, MENU_WHITE
	lda #<.levelsetters
	sta ZP0
	lda #>.levelsetters
	sta ZP1
	jsr VPrintString
	jsr .PrintCurrentStartLevel
	rts

.PrintCurrentStartLevel:
	+SetPrintParams LEVEL_ROW, ARROW_POSITIONS+1, MENU_WHITE
	lda _startlevel
	jsr VPrintShortNumber
	rts

.PrintConfirmationQuestion:
	stz .answer					;default answer is "no"
	ldy .handrow
	lda .menuitems,y
	sta _row
	lda #MENU_COL
	sta _col
	lda #MENU_BLACK
	sta _color
	lda #<.confirmation_question
	sta ZP0
	lda #>.confirmation_question
	sta ZP1
	jsr VPrintString
	jsr .PrintCurrentAnswer
	jsr .PrintHand
	rts

.PrintCurrentAnswer:
	ldy .handrow
	lda .menuitems,y
	sta _row				;IN: .A = row to print answer (a colored "Y/N")
	lda .answer
	bne +
	ldx #MENU_WHITE			;answer is no
	ldy #MENU_BLACK 
	bra ++
+	ldx #MENU_BLACK			;answer is yes
	ldy #MENU_WHITE
++	lda #YES_POSITION		;print "Y" in right color
	sta _col
	sty _color
	lda #S_Y
	phx
	jsr VPrintChar
	plx
	lda #NO_POSITION		;print "N" in right color
	sta _col
	stx _color
	lda #S_N
	jsr VPrintChar
	rts

.answer		!byte 0				;boolean, "yes" = true, "no" = false
YES_POSITION = 24
NO_POSITION  = 26

.ClearHand:
	lda #<.clearhandtext
	sta ZP0
	lda #>.clearhandtext
	sta ZP1	
	bra +
.PrintHand:
	lda #<.handtext
	sta ZP0
	lda #>.handtext
	sta ZP1
+	lda #6				;print hand from col 6 to 8
	sta _col
	ldy .handrow
	lda .menuitems,y
	sta _row
	tay
	lda .menurows,y
	sta _color
	jsr VPrintString
	rts

;*** Print menu, high score, and credits ********************************************************************

.ShowMenuScreen:					;print complete menu including setting layers, clear layers and print all text
	lda #MENU_MAIN_POS              ;set camera position  to first demo background
	sta _camxpos_lo
	stz _camxpos_hi
	jsr UpdateTilemap
	jsr ClearTextLayer
	stz .handrow					;put selection hand on first row
	jsr .UpdateMainMenu
	rts

.UpdateMainMenu:			;print menu items
	;print menu items
	lda #<.menutext
	sta ZP0
	lda #>.menutext
	sta ZP1
	stz _row
	lda #MENU_COL
	sta _col
	ldx #0
-	phx
	lda .menurows,x
	sta _color
	jsr VPrintString
	plx
	inx
	cpx #MENU_ROW_COUNT
	bne -
	jsr .PrintCurrentStartLevel
	jsr .PrintHand
	rts

.ShowHighScoreScreen:
	lda #<MENU_HIGH_POS		;set camera position to second demo background
	sta _camxpos_lo
	lda #>MENU_HIGH_POS
	sta _camxpos_hi
	jsr UpdateTilemap
	jsr ClearTextLayer
	jsr PrintLeaderboard
	rts

.ShowCreditScreen:
	lda #<MENU_CREDIT_POS		;set camera position to second demo background
	sta _camxpos_lo
	lda #>MENU_CREDIT_POS
	sta _camxpos_hi
	jsr UpdateTilemap
	jsr ClearTextLayer
	+SetPrintParams CREDITSCREEN_START_ROW,0,MENU_CREDITS_COLOR
	lda #<.creditscreentext
	sta ZP0
	lda #>.creditscreentext
	sta ZP1
	jsr VPrintString	;Print two title rows
	jsr VPrintString
	lda #MENU_WHITE
	sta _color
	lda #CREDITSCREEN_ROW_COUNT-2
-	pha
	jsr VPrintString
	pla
	dec
	bne -
	rts

;*** Start screen and menu data ************************************************

.creditscreentext:
!scr "         "
	; M        I      N        E           R        E      S        C      U        E
!byte 112,113, 96,97, 116,117, 80,81, 168, 132,133, 80,81, 136,137, 72,73, 144,145, 80,81, 0
!scr "         "
!byte 114,115, 98,99, 118,119, 82,83, 168, 134,135, 82,83, 138,139, 74,75, 146,147, 82,83, 0
!scr 0
!scr 0
!scr "          by johan k;rlin and",0
!scr 0
!scr "        clergy games productions",0
!scr 0
!scr 0
!scr "         inspired by h.e.r.o.",0
!scr 0
!scr "       for atari and commodore 64",0
!scr 0
!scr 0
!scr "    zsound is used for sound effects",0
!scr 0
!scr 0
!scr "              version: 0.9",0

CREDITSCREEN_ROW_COUNT = 19
CREDITSCREEN_START_ROW = 5

.menutext
!scr 0,0,0,0,0
	; M        I      N        E           R        E      S        C      U        E
!byte 112,113, 96,97, 116,117, 80,81, 168, 132,133, 80,81, 136,137, 72,73, 144,145, 80,81, 0
!byte 114,115, 98,99, 118,119, 82,83, 168, 134,135, 82,83, 138,139, 74,75, 146,147, 82,83, 0
!scr 0
!scr 0
!scr "start the game",0
!scr 0
!scr "set start level (  )",0
!scr 0
!scr "reset high scores   ",0	;add extra spaces to overwrite confirmation question if user says no
!scr 0
!scr "quit game           ",0	;add extra spaces to overwrite confirmation question if user says no
!scr 0
!scr 0
!scr "       ",212,213,214,215,216,217,218,219,0	;"<-switch screen->" in small font
!scr 0

MENU_COL = 9	;which column menu should be printed at

.confirmation_question	!scr "are you sure? (y/n)?",0
.setleveltext			!scr "set start level     ",0

.handtext		!scr " >",0
.clearhandtext	!scr "  ",0

LEVEL_ROW = 11
ARROW_POSITIONS = 25
.levelsetters	!scr "<  >",0

.menuitems 		!byte 9,11,13,15	;which menu rows that represent menu items
MENU_ITEMS_COUNT = 4

.menurows	 						;menu rows table that holds information about both color and selection.
				!byte MENU_BLACK
				!byte MENU_BLACK
				!byte MENU_BLACK
				!byte MENU_BLACK
				!byte MENU_BLACK
				!byte MENU_TITLE_COLOR
				!byte MENU_TITLE_COLOR
				!byte MENU_BLACK
				!byte MENU_BLACK
.startrace		!byte MENU_WHITE
				!byte MENU_BLACK
.setlevel		!byte MENU_WHITE
				!byte MENU_BLACK
.resetbest		!byte MENU_WHITE
				!byte MENU_BLACK
quitgame		!byte MENU_WHITE
				!byte MENU_BLACK
				!byte MENU_BLACK
				!byte MENU_BLACK

MENU_ROW_COUNT = 19

;Menu item mapping
START_GAME		= 0
SET_START_LEVEL = 1
RESET_BEST  	= 2
QUIT_GAME		= 3

;Colors
MENU_WHITE = $01
MENU_BLACK = $0c
MENU_TITLE_COLOR = $07
MENU_CREDITS_COLOR = $07

;Level 0 (demo level) horizontal positions
MENU_MAIN_POS = 160
MENU_HIGH_POS = 480
MENU_CREDIT_POS = 800
