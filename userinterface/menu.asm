;*** Menu.asm - Start screen, menu, credits ********************************************************

;Menu status
M_INIT_START_SCREEN   	= 0
M_SHOW_START_SCREEN     = 1
M_SHOW_MENU_SCREEN  	= 2
M_SHOW_CREDIT_SCREEN	= 3
M_HANDLE_INPUT 			= 4

;Menu item mapping
START_GAME		= 0
SET_START_LEVEL = 1
RESET_BEST  	= 2
QUIT_GAME		= 3

MENU_ITEMS_COUNT = 4

;Colors
MENU_WHITE = $01
MENU_BLACK = $0c

INACTIVITY_DELAY = 7

;*** Public methods ********************************************************************************

MenuHandler:
	lda .menumode

	;show start image
	cmp #M_INIT_START_SCREEN	;load and display start screen
	bne +
	jsr .ShowStartScreen
	lda #M_SHOW_START_SCREEN
	sta .menumode
	rts

+	cmp #M_SHOW_START_SCREEN	;just wait for player to press something
	bne +
	lda _joy0
	cmp #JOY_NOTHING_PRESSED
	beq +
	lda #M_SHOW_MENU_SCREEN
	sta .menumode
	rts

	;show menu
+   cmp #M_SHOW_MENU_SCREEN
	bne +
	jsr .ShowMenuScreen
	lda #M_HANDLE_INPUT				;next go to input menu mode
	sta .menumode
	lda #1
	sta .inputwait					;wait for controller to be released before accepting input again
	stz .inactivitytimer_lo			;reset timer that takes user back to start screen after 30 secs inactivity
	stz .inactivitytimer_hi
	rts

    ;show credit screen
+   cmp #M_SHOW_CREDIT_SCREEN
	bne ++
	jsr .ShowCreditScreen
	lda .inactivitytimer_hi
	cmp #INACTIVITY_DELAY
	bne +
	lda #M_SHOW_MENU_SCREEN
	sta .menumode
	rts
+	lda _joy0
	cmp #JOY_NOTHING_PRESSED
	beq +
	lda #M_SHOW_MENU_SCREEN
	sta .menumode
	rts
+	+Inc16 .inactivitytimer_lo
	rts

	;handle user input
++	cmp #M_HANDLE_INPUT
	beq +
	rts

+   lda .inactivitytimer_hi
	cmp #INACTIVITY_DELAY
	beq +
	jsr .HandleUserInput
	rts

+	lda #M_SHOW_CREDIT_SCREEN
	sta .menumode
	stz .inactivitytimer_lo
	stz .inactivitytimer_hi
	rts

.menumode				!byte 0
.inactivitytimer_lo		!byte 0		;timer to measure user inactivity
.inactivitytimer_hi		!byte 0

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
	lda .resetconfirmationflag
	bne +
	lda .quitconfirmationflag
	bne +
	jsr .UpdateMainMenu
+	rts

.HandleUpDown:					;up down moves hand up and down
	lda _joy0
	bit #JOY_UP					;up?
	bne +
	jsr .DecreaseHandrow
	stz .resetconfirmationflag	;cancel possibel confirmation questions if user moves away from question
	stz .quitconfirmationflag
	rts
+	bit #JOY_DOWN				;down?
	bne +
	jsr .IncreaseHandrow
	stz .resetconfirmationflag	;cancel possibel confirmation questions if user moves away from question
	stz .quitconfirmationflag
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
	bne +
	lda .quitconfirmationflag
	bne +
	rts
+   lda _joy0
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
	jsr .HandleSetStartLevel
	rts

+	cmp #RESET_BEST
	bne +
	jsr .HandleResetLeaderboard

+	cmp #QUIT_GAME
	bne +
	jsr .HandleQuitGame
+	rts

.CloseMainMenu:
	lda #M_INIT_START_SCREEN
	sta .menumode			;prepare for the next time the menu handler will be called, then we skip start screen and go directly to the main menu
	lda #ST_INITGAME
	sta _gamestatus         ;update game status to start game, the menu handler will no longer be called
	rts

.HandleSetStartLevel:
	rts

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
	jsr PrintLeaderboard
	lda #M_HANDLE_INPUT
	sta .menumode
	jsr SaveLeaderboard
	rts
+	lda #M_HANDLE_INPUT
	sta .menumode
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
	lda #M_SHOW_START_SCREEN
	sta .menumode					;set menu mode to start screen in case user starts game again
	lda #ST_QUITGAME
	sta _gamestatus					;set game status to break main loop, clean up and exit
	rts
+	lda #M_HANDLE_INPUT
	sta .menumode
	rts

.quitconfirmationflag	!byte 0		;flag that confirmation question is waiting for an answer

.PrintConfirmationQuestion:		;IN: .A = row to print question
	stz .answer					;default answer is "no"
	ldy .handrow
	lda .menuitems,y
	sta _row
	lda #10
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
YES_POSITION = 25
NO_POSITION  = 27

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
+	lda #4				;print hand from col 4 to 6
	sta _col
	ldy .handrow
	lda .menuitems,y
	sta _row
	tay
	lda .menurows,y
	sta _color
	jsr VPrintString
	rts

;*** Draw start screen and menu ********************************************************************

.ShowStartScreen:
	jsr ShowStartImage	;show image
	rts

.ShowMenuScreen:						;print complete menu including setting layers, clear layers and print all text
	jsr DisableLayer0
	jsr ClearTextLayer
	jsr EnableLayer1
	stz .handrow					;put selection hand on first row
	jsr PrintLeaderboard
	jsr .UpdateMainMenu
	rts

.UpdateMainMenu:
	;print menu items
	lda #<.menutext
	sta ZP0
	lda #>.menutext
	sta ZP1
	stz _row
	lda #10
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
	
	jsr .PrintHand
	rts

.ShowCreditScreen:
	jsr DisableLayer0
	jsr ClearTextLayer
	jsr EnableLayer1
	+SetPrintParams 3,0,$01
	lda #<.creditscreentext
	sta ZP0
	lda #>.creditscreentext
	sta ZP1
	lda #CREDITSCREEN_ROW_COUNT
-	pha
	jsr VPrintString
	inc _row
	pla
	dec
	bne -
	rts

;*** Start screen and menu data ************************************************

.creditscreentext:
!scr "              h.e.r.o. 2021",0
!scr 0
!scr "     a tribute to the original game",0
!scr "       for atari and commodore 64",0
!scr "             by john rizen",0
!scr 0
!scr "             copyright 2021",0
!scr "          by johan k;rlin and",0
!scr "        clergy games productions",0
!scr "          all rights reserved",0
!scr 0
!scr "              version 0.1",0

CREDITSCREEN_ROW_COUNT = 12

.menutext
!scr 0
!scr "start the game",0
!scr 0
!scr "set start level     ",0
!scr 0
!scr "reset high scores   ",0	;add extra spaces to overwrite confirmation question if user says no
!scr 0
!scr "quit game           ",0	;add extra spaces to overwrite confirmation question if user says no
!scr 0

.confirmation_question	!scr "are you sure? (y/n)?",0

.handtext		!scr "<=>",0 ;char 60-62 = characters that form a hand
.clearhandtext	!scr "   ",0

.menuitems 		!byte 1,3,5,7		;which menu rows that represent menu items

.menurows	 						;menu rows table that holds information about both color and selection.
				!byte MENU_BLACK
.startrace		!byte MENU_WHITE
				!byte MENU_BLACK
.setlevel		!byte MENU_WHITE
				!byte MENU_BLACK
.resetbest		!byte MENU_WHITE
				!byte MENU_BLACK
quitgame		!byte MENU_WHITE
				!byte MENU_BLACK

MENU_ROW_COUNT = 9