;*** Menu.asm - Start screen, menu, annoncements *******************************

;Menu status
M_SHOW_START_SCREEN 	= 0
M_UPDATE_START_SCREEN	= 1
M_SHOW_MAIN_MENU 		= 2
M_HANDLE_INPUT 			= 3

;Menu item mapping
START_RACE		= 0
ONE_PLAYER 		= 1
TWO_PLAYERS 	= 2
TRACK_1			= 3
TRACK_2			= 4
TRACK_3			= 5
TRACK_4			= 6
TRACK_5			= 7
LOW_SPEED   	= 8
NORMAL_SPEED 	= 9
HIGH_SPEED	 	= 10
RESET_BEST  	= 11
QUIT_GAME		= 12

MENU_ITEMS_COUNT = 13

;Special characters used in menu
END_LINE_DIV	= 34 	;"
BLOCK			= 35	;#
MIDDLE_LINE_DIV	= 37 	;%
FIRST_LINE_DIV 	= 38	;&

;Colors
MENU_WHITE = $01
MENU_BLACK = $0b

;*** Public methods ********************************************************************************

MenuHandler:
	lda .menumode

	;show start screen
	cmp #M_SHOW_START_SCREEN
	bne +
	jsr .ShowStartScreen
	inc .menumode					;go to next mode - update start screen (change bg colors)
	rts

	;update start screen
+	cmp #M_UPDATE_START_SCREEN
	bne ++
	lda _joy0
	cmp #$ff
	beq +
	inc .menumode           		;if anything at all is pressed, go to next mode - show menu
+   rts

	;show menu
++  cmp #M_SHOW_MAIN_MENU
	bne +
	jsr .ShowMainMenu
	lda #M_HANDLE_INPUT				;next go to input menu mode
	sta .menumode
	lda #1
	sta .inputwait					;wait for controller to be released before accepting input again
	stz .inactivitytimer_lo			;reset timer that takes user back to start screen after 30 secs inactivity
	stz .inactivitytimer_hi
	rts

	;handle user input
++	cmp #M_HANDLE_INPUT
	beq +
	rts

+   lda .inactivitytimer_hi
	cmp #7
	beq +
	jsr .HandleUserInput
	rts

+	lda #M_SHOW_START_SCREEN
	sta .menumode
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
	lda _gamestatus
	cmp #ST_INITLEVEL
	beq +
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
	cmp #START_RACE
	bne +
	jsr .CloseMainMenu
	rts

+	cmp #ONE_PLAYER
	bne +
	lda #1
	sta .oneplayer
	lda #$0b
	sta .twoplayers
	lda #1
	sta _noofplayers
	rts

+	cmp #TWO_PLAYERS
	bne +
	lda #1
	sta .twoplayers
	lda #$0b
	sta .oneplayer
	lda #2
	sta _noofplayers
	rts

+	cmp #RESET_BEST
	bne +
	jsr .HandleResetLeaderboard

+	cmp #QUIT_GAME
	bne +
	jsr .HandleQuitGame
+	rts

.CloseMainMenu:
	lda #M_SHOW_MAIN_MENU
	sta .menumode			;prepare for the next time the menu handler will be called, then we skip start screen and go directly to the main menu
	lda #ST_INITGAME
	sta _gamestatus         ;update game status to start game, the menu handler will no longer be called
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
	jsr ClearTextLayer
	+SetPrintParams 3,0,$01
	lda #<.startscreentext
	sta ZP0
	lda #>.startscreentext
	sta ZP1
	lda #STARTSCREEN_ROW_COUNT
-	pha
	jsr VPrintString
	inc _row
	pla
	dec
	bne -
	rts

.ShowMainMenu:						;print complete menu including setting layers, clear layers and print all text
	jsr ClearTextLayer
	lda #<.menubgblocks			;set block table pointer as in parameter
	sta .blocktable_lo
	lda #>.menubgblocks
	sta .blocktable_hi
	stz .handrow					;put selection hand on first row
	jsr PrintLeaderboard

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

;*** Methods on layer 0 ********************************************************

.blocktable_lo	!byte 0
.blocktable_hi	!byte 0

;*** Start screen and menu data ************************************************

.startscreentext:
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

STARTSCREEN_ROW_COUNT = 12

.menubgblocks
!byte 2,3,6,4,2,2,10,0				;table for how many rows each block is, zero terminated

.menutext
!scr 0
!scr "start the race",0
!scr 0
!scr "one player",0
!scr "two players",0
!scr 0
!scr 0	;(track names)
!scr 0
!scr 0
!scr 0
!scr 0
!scr 0
!scr "low speed",0
!scr "normal speed",0
!scr "high speed",0
!scr 0
!scr "reset leaderboard   ",0	;add extra spaces to overwrite confirmation question if user says no
!scr 0
!scr "quit game           ",0	;add extra spaces to overwrite confirmation question if user says no
!scr 0

.confirmation_question	!scr "are you sure? (y/n)?",0

.handtext		!scr "<=>",0 ;char 60-62 = characters that form a hand
.clearhandtext	!scr "   ",0

.menuitems 		!byte 1,3,4,6,7,8,9,10,12,13,14,16,18	;which menu rows that represent menu items

.menurows	 						;menu rows table that holds information about both color and selection.
				!byte $b			; 1 = white color = selected (when relevant)
.startrace		!byte 1  			;$b = nontransparent black = not selected
				!byte $b
.oneplayer		!byte 1
.twoplayers		!byte $b
				!byte $b
.track1			!byte 1
.track2			!byte $b
.track3			!byte $b
.track4			!byte $b
.track5			!byte $b
				!byte $b
.lowspeed		!byte $b
.normalspeed	!byte 1
.highspeed		!byte $b
				!byte $b
.resetbest		!byte 1
				!byte $b
.quitgame		!byte 1
				!byte $b

MENU_ROW_COUNT = 20