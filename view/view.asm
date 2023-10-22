;*** view.asm - updates screen att vblank **********************************************************

_darkmode               !byte 0 ;boolean, if dark mode is set
_darktimecount_lo       !byte 0 
_darktimecount_hi       !byte 0
_backgroundcolor_lo     !byte 0
_backgroundcolor_hi     !byte 0

.deathcolorvalue        !byte 0
DEATH_COLOR = 15
DEATH_COLOR_ADDR = TILES_PALETTES_ADDR + DEATH_COLOR * 2

_camxpos_lo     !byte 0         ;current camera position. Camera will follow player as long as the tilemap will allow it. E g x pos cannot be less than 160
_camxpos_hi     !byte 0
_camypos_lo     !byte 0
_camypos_hi     !byte 0

UpdateView:    ;Called at vertical blank to update level, text and sprites.
        jsr UpdateTilemap
        ; jsr UpdateCreatures      
        ; jsr UpdatePlayerSprite 
        ; jsr UpdateLight
        ; jsr UpdateStatusTime
        ; jsr UpdateExplosion
        rts

UpdateTilemap:                  ;subtract half screen width an height from player pos to get tilemap position for topleft corner of screen

        sec                             
        lda _camxpos_lo
        sbc #SCREENWIDTH/2
        sta L0_HSCROLL_L
        lda _camxpos_hi
        sbc #0
        sta L0_HSCROLL_H

        sec
        lda _camypos_lo
        sbc #SCREENHEIGHT/2
        sta L0_VSCROLL_L
        lda _camypos_hi
        sbc #0
        sta L0_VSCROLL_H
        rts

UpdateCameraPosition:           ;camera will centre on player as long as possible, but will stop before tilemap/level wraps around

        ;set horizontal position
        +Cmp16I _xpos_lo, SCREENWIDTH/2
        bcs +                   
        lda #<SCREENWIDTH/2     ;player is left of camera limit, stop camera at left limit
        sta _camxpos_lo
        lda #>SCREENWIDTH/2
        sta _camxpos_hi
        bra ++

+       +Cmp16 _xpos_lo, _levelxmaxpos
        bcc +
        lda _levelxmaxpos       ;player is right of camera limit, stop camera at right limit
        sta _camxpos_lo
        lda _levelxmaxpos+1
        sta _camxpos_hi
        bra ++

+       lda _xpos_lo            ;player is within limits, center camera on player
        sta _camxpos_lo
        lda _xpos_hi
        sta _camxpos_hi
++
        ;set vertical position
++      +Cmp16I _ypos_lo, SCREENHEIGHT/2
        bcs +                   
        lda #<SCREENHEIGHT/2     ;player is above camera limit, stop camera at top limit
        sta _camypos_lo
        lda #>SCREENHEIGHT/2
        sta _camypos_hi
        rts

+       +Cmp16 _ypos_lo, _levelymaxpos
        bcc +
        lda _levelymaxpos       ;player is below camera limit, stop camera at bottom limit
        sta _camypos_lo
        lda _levelymaxpos+1
        sta _camypos_hi
        rts

+       lda _ypos_lo            ;player is within limits, center camera on player
        sta _camypos_lo
        lda _ypos_hi
        sta _camypos_hi
        rts

UpdateTileColors:
        +CheckTimer .reddelay, DEATHCOLOR_DELAY
        bne +
        rts
+
-       ldy .redindex
        lda .redvalues,y
        bne +
        stz .redindex
        bra -
+       ldx _darkmode
        beq +
        ;lda .darkredvalues,y
+       +VPoke DEATH_COLOR_ADDR+1       ;set next value of color
        inc .redindex
        rts

DEATHCOLOR_DELAY = 6
.reddelay       !byte 0
.redindex       !byte 0
.redvalues      !byte 7,7,7,8,8,9,10,10,11,11,11,10,10,9,8,8,0     ;0-terminated table
.darkredvalues  !byte 1,1,1,2,2,3, 4, 4, 5, 5, 5, 4, 4,3,2,2,0     ;color when light is turned off

UpdateExplosion:                ;change background color during an explosion
        lda _explosivemode
        cmp #EXPLOSIVE_DETONATE
        bne +
        lda #<TILES_PALETTES_ADDR+2
        sta VERA_ADDR_L
        lda #>TILES_PALETTES_ADDR+2
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H
        lda _backgroundcolor_lo
        sta VERA_DATA0
        lda _backgroundcolor_hi
        sta VERA_DATA0
        lda _backgroundcolor_lo
        sta VERA_DATA0
        lda _backgroundcolor_hi
        sta VERA_DATA0
+       rts

UpdateStatusBar:
        ;print text
        +SetPrintParams 28,0,$01
        lda #<.statusbar
        sta ZP0
        lda #>.statusbar
        sta ZP1
        jsr VPrintString

        ;print current level
        +SetPrintParams 28,7
        lda _level
        jsr VPrintShortNumber

        ;print time
        jsr UpdateStatusTime:

        ;print number of lives left
        +SetPrintParams 28,37
        lda _lives              
        jsr VPrintShortNumber
        rts

UpdateStatusTime:
        +SetPrintParams 28,17
        lda _minutes
        sta ZP0
        lda _seconds
        sta ZP1
        jsr VPrintTime
        rts

.statusbar      !scr " level                         lives   ",0
