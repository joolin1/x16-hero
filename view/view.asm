;*** view.asm - updates screen att vblank **********************************************************

_darkmode               !byte 0 ;boolean, if dark mode is set
_darktimecount_lo       !byte 0 
_darktimecount_hi       !byte 0
_backgroundcolor_lo     !byte 0
_backgroundcolor_hi     !byte 0

UpdateDemoView:
;         lda _menumode
;         cmp #M_HANDLE_INPUT
;         beq +
;         cmp #M_SHOW_CREDIT_SCREEN
;         beq +
;         cmp #M_SHOW_HIGHSCORE_SCREEN
;         beq +
;         rts
; +       jsr UpdateView
        rts

UpdateView:    ;Called at vertical blank to update level, text and sprites.

        ;subtract half screen width an height from player pos to get tilemap position for topleft corner of screen
        sec                             
        lda _xpos_lo
        sbc #SCREENWIDTH/2
        sta L0_HSCROLL_L
        lda _xpos_hi
        sbc #0
        sta L0_HSCROLL_H

        sec
        lda _ypos_lo
        sbc #SCREENHEIGHT/2
        sta L0_VSCROLL_L
        lda _ypos_hi
        sbc #0
        sta L0_VSCROLL_H

        jsr UpdatePlayerSprite 
        jsr UpdateCreatureSprites
        jsr UpdateLight
        jsr UpdateStatusTime

        ;change background color during an explosion
        lda _explosivemode
        beq +
        lda #<TILES_PALETTE+2
        sta VERA_ADDR_L
        lda #>TILES_PALETTE+2
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H
        lda _backgroundcolor_lo
        sta VERA_DATA0
        lda _backgroundcolor_hi
        sta VERA_DATA0
+       rts

UpdateStatusBar:
        lda #4                ;set scroll offset to print status bar with four pixels margin
        sta L1_HSCROLL_L
        lda #3
        sta L1_VSCROLL_L
        stz L1_HSCROLL_H
        stz L1_VSCROLL_H

        ;print text
        +SetPrintParams 29,0,$01
        lda #<.statusbar
        sta ZP0
        lda #>.statusbar
        sta ZP1
        jsr VPrintString

        ;print current level
        +SetPrintParams 29,7
        lda _level
        jsr VPrintShortNumber

        ;print time
        jsr UpdateStatusTime:

        ;print number of lives left
        +SetPrintParams 29,38
        lda _lives              
        jsr VPrintShortNumber
        rts

UpdateStatusTime:
        +SetPrintParams 29,17
        lda _minutes
        sta ZP0
        lda _seconds
        sta ZP1
        jsr VPrintTime
        rts

.statusbar      !scr " level                          lives   ",0

; PrintDebugInformation:             ;DEBUG     
;         +SetPrintParams 2,0,$01
;         lda _joy0
;         jsr VPrintNumber

;         +SetPrintParams 7,0,$01
;         +VPrintHex16Number _xpos_lo
;         +SetPrintParams 8,0,$01
;         +VPrintHex16Number _ypos_lo         
;         rts
