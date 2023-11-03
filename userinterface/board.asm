;*** board.asm - **********************************************************************************

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

; !macro InitBoardInput .row, .col {
;         lda #.row
;         sta _row
;         lda #.col
;         sta _col
;         lda #LB_NAME_LENGTH
;         jsr InitInputString
;         lda #1
;         sta _boardinputflag
; }

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
+       bit #JOY_START
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

BOARD_HEADING_COLOR = $07
BOARD_TEXT_COLOR    = $01

PrintLevelFinished:
        +SetPrintParams 12,9,BOARD_HEADING_COLOR
        +SetParamsI <.board_levelfinished, >.board_levelfinished
        jsr VPrintString
        jsr VPrintString
        rts

PrintGameOver:
        +SetPrintParams 12,11,BOARD_HEADING_COLOR
        +SetParamsI <.board_gameover, >.board_gameover
        jsr VPrintString
        jsr VPrintString
        rts

PrintGameCompleted:
        +SetPrintParams 9,4,BOARD_HEADING_COLOR
        +SetParamsI <.board_completedheading, >.board_completedheading
        jsr VPrintString
        jsr VPrintString
        +SetPrintParams 12,7,BOARD_TEXT_COLOR
        jsr VPrintString
        jsr VPrintString
        jsr VPrintString
        jsr VPrintString
        jsr VPrintString
        jsr VPrintString
        jsr VPrintString
        jsr VPrintString
        jsr VPrintString
        rts

                        ;     M        I      N        E      R            S        A      V        E      D      !
.board_levelfinished:   !byte 112,113, 96,97, 116,117, 80,81, 132,133, 32, 136,137, 64,65, 148,149, 80,81, 76,77, 170, 0
                        !byte 114,115, 98,99, 118,119, 82,83, 134,135, 32, 138,139, 66,67, 150,151, 82,83, 78,79, 171, 0

                        ;     G      A      M        E          O        V        E      R        !
.board_gameover         !byte 88,89, 64,65, 112,113, 80,81, 32, 120,121, 148,149, 80,81, 132,133, 170, 0
                        !byte 90,91, 66,67, 114,115, 82,83, 32, 122,123, 150,151, 82,83, 134,135, 171, 0

                        ;     M        I      S        S        I      O        N            C       O        M        P        L        E      T        E     !       
.board_completedheading !byte 112,113, 96,97, 136,137, 136,137, 96,97, 120,121, 116,117, 32, 72,73, 120,121, 112,113, 124,125, 108,109, 80,81, 140,141, 80,81, 170, 0
                        !byte 114,115, 98,99, 138,139, 138,139, 98,99, 122,123, 118,119, 32, 74,75, 122,123, 114,115, 126,127, 110,111, 82,83, 142,143, 82,83, 171, 0
.board_completedtext    !scr "   you are a true hero!",0,0
                        !scr " the international rescue",0,0
                        !scr "service for trapped miners",0,0
                        !scr "   will honor you with",0,0
                        !scr "   a medal of bravery!",0
                        