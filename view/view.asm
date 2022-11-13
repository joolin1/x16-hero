;*** view.asm - updates screen att vblank **********************************************************

_darkmode               !byte 0 ;boolean, if dark mode is set
_darktimecount_lo       !byte 0 
_darktimecount_hi       !byte 0
_backgroundcolor_lo     !byte 0
_backgroundcolor_hi     !byte 0

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