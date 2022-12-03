;*** board.asm - board displayed when race is finished *********************************************

BOARD_COLORS            = $91     ;bg color = grey, fg color = white 
BOARD_SELECTED          = $91     ;bg color = grey, fg color = white           
BOARD_UNSELECTED        = $9b     ;bg color = grey, fg color = black

;Special characters used for board shadow effect
BOTTOM_RIGHT_BORDER = 27
BOTTOM_LEFT_BORDER  = 28
TOP_RIGHT_BORDER    = 29
RIGHT_BORDER        = 31
BOTTOM_BORDER       = 36

;*** marcros for printing board ********************************************************************

!macro PrintBoardShadow .width, .height, .startrow, .startcol {
        ;print bottom shadow
        lda #$0b                ;bg = transparent, fg = black
        sta _color

        lda #.startrow + .height
        sta _row
        lda #.startcol
        sta _col
        lda #BOTTOM_LEFT_BORDER
        jsr VPrintChar
        ldx #.width - 1
-       lda #BOTTOM_BORDER
        phx
        jsr VPrintChar
        plx
        dex
        bne -
        lda #BOTTOM_RIGHT_BORDER
        jsr VPrintChar

        ;print right shadow
        lda #.startrow
        sta _row
        lda #.startcol + .width
        sta _col
        lda #TOP_RIGHT_BORDER
        jsr VPrintChar
        dec _col
        inc _row
        ldy #.height-1
-       lda #RIGHT_BORDER
        phy
        jsr VPrintChar
        ply
        dec _col
        inc _row
        dey
        bne -
}

!macro PrintBoard .width, .height, .startrow, .startcol, .text {
        +PrintBoardShadow .width, .height, .startrow, .startcol
        lda #BOARD_COLORS
        sta _color
        lda #<.text
        sta ZP0
        lda #>.text
        sta ZP1
        lda #.startrow
        sta _row
        ldy #.height
-       lda #.startcol
        sta _col
        phy
        jsr VPrintString
        ply
        dey
        bne -              
}

!macro PrintBoardString .row, .col, .text {
        lda #.row
        sta _row
        lda #.col
        sta _col
        lda #<.text
        sta ZP0
        lda #>.text
        sta ZP1
        jsr VPrintString
}

!macro InitBoardInput .row, .col {
        lda #.row
        sta _row
        lda #.col
        sta _col
        lda #LB_NAME_LENGTH
        jsr InitInputString
        lda #1
        sta _boardinputflag
}

;*** Pause menu ************************************************************************************

PAUSEMENU_ITEMCOUNT = 2         ;(has to be 2, 4, 8...)

.pausemenu        !scr "             ",0
.pausemenuitems   !scr " resume game ",0
                  !scr " quit        ",0
                  !scr "             ",0
.selecteditem     !byte 0
.inputwait        !byte 0

ShowPauseMenu:
        stz .selecteditem
        lda #1
        sta .inputwait
        jsr .PrintPauseMenu
        rts

UpdatePauseMenu:     
        lda _joy0
        and _joy1
        cmp #JOY_NOTHING_PRESSED        ;before accepting new input all buttons must be released
        bne +
        stz .inputwait
        lda #-1
        rts

+       lda .inputwait
	beq +
	lda #-1
        rts

+       lda _joy0
        and _joy1
        bit #JOY_BUTTON_A
        bne +
        lda .selecteditem
        rts

+       bit #JOY_UP
        bne +
        lda .selecteditem
        dec                             ;change to menu item above
        and #PAUSEMENU_ITEMCOUNT-1
        sta .selecteditem
        bra ++

+       bit #JOY_DOWN
        bne ++
        lda .selecteditem               ;change to menu item below
        inc
        and #PAUSEMENU_ITEMCOUNT-1
        sta .selecteditem

++      jsr .PrintPauseMenu
        lda #1
        sta .inputwait
        lda #-1
        rts

.PrintPauseMenu:
        +PrintBoard 13,4,12,13,.pausemenu       ;start with printing the whole menu with white text
        lda #13
        sta _row
        lda #0      
-       cmp .selecteditem                       ;loop through all menu items, printing all unselected items in black
        bne +        
        ldx #BOARD_SELECTED
        bra ++
+       ldx #BOARD_UNSELECTED
++      stx _color
        ldx #13
        stx _col
        ldx #<.pausemenuitems
        stx ZP0
        ldx #>.pausemenuitems
        stx ZP1
        pha
        jsr GetStringInArray         
        jsr VPrintString
        pla
        inc
        cmp #PAUSEMENU_ITEMCOUNT
        bne -        
        rts

;*** Boards ***************************************************************************************

PrintLevelCompletedBoard:
        +PrintBoard 24, 4, 9, 8, .board_levelcompleted
        rts

PrintGameCompletedBoard:
        +PrintBoard 24, 4, 9, 8, .board_gamecompleted
        rts

PrintGameOverBoard:
        +PrintBoard 23, 3, 9, 8, .board_gameover
        rts

.board_levelcompleted   !scr "                        ",0
                        !scr "    level completed     ",0 
                        !scr "  you saved the miner!  ",0
                        !scr "                        ",0

.board_gamecompleted    !scr "                        ",0
                        !scr "  all miners are saved  ",0 
                        !scr "  you are a true hero!  ",0
                        !scr "                        ",0

.board_gameover         !scr "                       ",0
                        !scr "       game over       ",0
                        !scr "                       ",0
