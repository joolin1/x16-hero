;*** miscsprites.asm *******************************************************************************

!addr LASER0_ADDR_L       = $FC10       ;laser beam is sprite 2 and 3
!addr LASER0_MODE_ADDR_H  = $FC11
!addr LASER0_XPOS_L       = $FC12
!addr LASER0_XPOS_H       = $FC13
!addr LASER0_YPOS_L       = $FC14
!addr LASER0_YPOS_H       = $FC15
!addr LASER0_ATTR_0       = $FC16
!addr LASER0_ATTR_1       = $FC17

!addr EXPLOSIVES_ADDR_L       = $FC20   ;explosives are sprite 4
!addr EXPLOSIVES_MODE_ADDR_H  = $FC21
!addr EXPLOSIVES_XPOS_L       = $FC22
!addr EXPLOSIVES_XPOS_H       = $FC23
!addr EXPLOSIVES_YPOS_L       = $FC24
!addr EXPLOSIVES_YPOS_H       = $FC25
!addr EXPLOSIVES_ATTR_0       = $FC26
!addr EXPLOSIVES_ATTR_1       = $FC27

;sprite start offsets for explosives and laserbeam
EXPLOSIVE_START = 48
EXPLOSIVE_STOP  = 51
LASER_START     = 56
LASER_STOP      = 63

LASER_FIRE_TIME         = 30
LASER_YOFFSET           = 7     ;laserbeam will radiate from players eyes, this many pixels up from the middle of the player sprite
LASER_XOFFSET           = 22    ;middle of laserbeam will be 22 pixels left or right of the player
LASER_YPOS              = SCREENHEIGHT/2-LASER_YOFFSET

_laser_xpos         !byte 0 ;current horizontal position in pixels
.laserframe         !byte 0 ;current laserbeam frame
.lasertime          !byte 0 ;how long the laser has been firing or reloading
.laserenabled       !byte 0

EXPLOSIVE_STUBTHREAD_TIME = 60
EXPLOSIVE_FRAMEDELAY = 4
EXPLOSIVE_YOFFSET         = 4   ;explosives are placed at player's feet
EXPLOSIVE_XOFFSET         = 4
EXPLOSIVE_SAFE_DISTANCE   = 32  ;player must be 3 tiles away to not be killed...

EXPLOSIVE_PLACE          = 1     ;explosion mode, enumerable
EXPLOSIVE_BURN           = 2
EXPLOSIVE_START_DETONATE = 3
EXPLOSIVE_DETONATE       = 4
_explosivemode          !byte 0 ;explosive lit or detonating?

_expl_xpos_lo           !byte 0 ;explosive's position in world
_expl_xpos_hi           !byte 0
_expl_ypos_lo           !byte 0
_expl_ypos_hi           !byte 0

_explosiveframe         !byte 0 ;current explosive frame
_stubthreadtime         !byte 0 ;how long the stub thread has been lit
_explosiveframedelay    !byte 0 ;speed of animation of burning stub thread

UpdateExplosive:
        lda _explosivemode
        bne +
        rts
+       cmp #EXPLOSIVE_PLACE
        bne +
        jsr PlaceExplosive
        rts
+       cmp #EXPLOSIVE_BURN
        bne +
        jsr BurnExplosive
        rts
+       cmp #EXPLOSIVE_START_DETONATE
        bne +
        jsr PlayExplosionSound
        jsr CheckIfPlayerBlasted
        jsr RemoveWall
        lda #EXPLOSIVE_DETONATE
        sta _explosivemode
        rts
+       cmp #EXPLOSIVE_DETONATE
        bne +
        jsr DetonateExplosive
+       rts

PlaceExplosive:
        stz _explosiveframe

        lda #<EXPLOSIVES_ADDR_L
        sta VERA_ADDR_L
        lda #>EXPLOSIVES_ADDR_L
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H

        ;set sprite address for explosives
        lda #<((CREATURE_SPRITES_ADDR + EXPLOSIVE_START * 128)>>5)
        sta VERA_DATA0
        lda #>((CREATURE_SPRITES_ADDR + EXPLOSIVE_START * 128)>>5)
        sta VERA_DATA0

        ;place explosive at player's feet
        +Copy16 _xpos_lo, _expl_xpos_lo
        +Copy16 _ypos_lo, _expl_ypos_lo
        +Add16I _expl_ypos_lo, EXPLOSIVE_YOFFSET
        lda _ismovingleft
        beq +
        +Sub16I _expl_xpos_lo, EXPLOSIVE_XOFFSET
        bra ++
+       +Add16I _expl_xpos_lo, EXPLOSIVE_XOFFSET      
++      jsr SetExplosiveSpritePosition

        ;set attributes
        lda #8
        sta VERA_DATA0              ;ignore collision mask, enable sprite
        lda #%01010010                  
        sta VERA_DATA0              ;set 16x16 and palette 2

        lda #EXPLOSIVE_BURN
        sta _explosivemode
        rts

BurnExplosive:
        lda #<EXPLOSIVES_ADDR_L
        sta VERA_ADDR_L
        lda #>EXPLOSIVES_ADDR_L
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H

        ;update sprite address for animation
        lda #<((CREATURE_SPRITES_ADDR + EXPLOSIVE_START * 128)>>5)
        sta ZP0
        lda #>((CREATURE_SPRITES_ADDR + EXPLOSIVE_START * 128)>>5)
        sta ZP1
        lda _explosiveframe
        asl
        asl
        +Add16 ZP0     ;add frame * 4 because sprite size >> 5 = 4
        lda ZP0
        sta VERA_DATA0
        lda ZP1
        sta VERA_DATA0

        ;update sprite position
        jsr SetExplosiveSpritePosition

        +CheckTimer _explosiveframedelay, EXPLOSIVE_FRAMEDELAY
        beq +
        inc _explosiveframe
        lda _explosiveframe
        cmp #EXPLOSIVE_STOP-EXPLOSIVE_START+1
        bne +
        stz _explosiveframe

+       +CheckTimer _stubthreadtime, EXPLOSIVE_STUBTHREAD_TIME
        beq +
        +VPokeI EXPLOSIVES_ATTR_0,0    ;disable sprite
        lda #EXPLOSIVE_START_DETONATE
        sta _explosivemode
+       rts

DetonateExplosive:                      ;change background color fast according to a color table
        lda _explosioncolorindex
        cmp #EXPLOSIONCOLORCOUNT
        bne ++       
        stz _explosioncolorindex
        lda _playerblasted
        beq +
        lda #ST_DEATH
        sta _gamestatus
+       stz _explosivemode
        rts
++      asl
        tay
        lda _explosioncolors,y
        sta _backgroundcolor_lo         ;set new background color (will be updated at vblank)
        lda _explosioncolors+1,y
        sta _backgroundcolor_hi
        inc _explosioncolorindex
        rts

_explosioncolorindex    !byte 0
_explosioncolors        !word $0aa0, $0aa8, $0ff0, $0ffa, $0fff, $0ff0, $0aa8, $0aa0, $0000
                        !word $0aa0, $0aa8, $0ff0, $0ffa, $0fff, $0ff0, $0aa8, $0aa0, $0000
EXPLOSIONCOLORCOUNT = 18

RemoveWall:             ;check if there are any wall tiles in the vicinity of the explosive and remove them
        +Copy16 _expl_ypos_lo, ZP4
        +Copy16 _expl_xpos_lo, ZP6
        +DivideBy16 ZP4 ;get tile y pos for explosive, result is an 8-bit value
        +DivideBy16 ZP6 ;get tile x pos, result is an 8-bit value
        lda ZP4
        sec
        sbc #2          ;start checking two rows up
        sta ZP4
        dec ZP6         ;start checking one col left
        lda #3          ;check a square of 3x3 tiles
        sta .tileycount
        sta .tilexcount
        
-       lda #<L0_MAP_ADDR
        sta ZP2
        lda #>L0_MAP_ADDR
        sta ZP3
        +GetElementIn16BitArray ZP2, .levelpow2width, ZP4, ZP6  ;parameters: addr of array, width in 2^x notification, row and col
        +VPeek ZP0                      ;if carry is set, read from bank 1
        tay
        lda _tilecategorytable,y        ;read tile category
        cmp #TILECAT_WALL
        bne +
        lda ZP0
        sta VERA_ADDR_L
        lda ZP1
        sta VERA_ADDR_M
        stz VERA_ADDR_H
        lda #TILE_SPACE
        sta VERA_DATA0
+       inc ZP6
        dec .tilexcount
        bne -
        lda ZP6
        sec 
        sbc #3          ;move back three columns
        sta ZP6 
        inc ZP4         ;move to next row
        lda #3
        sta .tilexcount
        dec .tileycount
        bne -
        rts

.tileycount     !byte 0
.tilexcount     !byte 0

CheckIfPlayerBlasted:
        +Copy16 _xpos_lo, ZP0
        +Sub16 ZP0, _expl_xpos_lo
        +Abs16 ZP0
        +Cmp16I ZP0, EXPLOSIVE_SAFE_DISTANCE
        bcc +
        stz _playerblasted
        rts
+       +Copy16 _ypos_lo, ZP0
        +Sub16 ZP0, _expl_ypos_lo
        +Abs16 ZP0
        +Cmp16I ZP0, EXPLOSIVE_SAFE_DISTANCE
        bcc +
        stz _playerblasted
        rts
+       lda #1
        sta _playerblasted
        jsr ShowDeadPlayer
        rts

_playerblasted  !byte 0

SetExplosiveSpritePosition:
        +PositionSprite _expl_xpos_lo, _expl_xpos_hi, _xpos_lo, _xpos_hi, SCREENWIDTH/2, 16
        lda ZP0
        sta VERA_DATA0
        lda ZP1
        sta VERA_DATA0
        +PositionSprite _expl_ypos_lo, _expl_ypos_hi, _ypos_lo, _ypos_hi, SCREENHEIGHT/2, 16
        lda ZP0
        sta VERA_DATA0
        lda ZP1
        sta VERA_DATA0
        rts

FireLaser:
        lda .laserenabled
        bne +
        rts

+       inc .laserframe
        lda .laserframe
        cmp #LASER_STOP-LASER_START+1
        bne +
        stz .laserframe

+       lda #<LASER0_ADDR_L
        sta VERA_ADDR_L
        lda #>LASER0_ADDR_L
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H

        ;set sprite address for laser shot sprites
        ldx #0
-       lda #<((CREATURE_SPRITES_ADDR + LASER_START * 128)>>5)
        sta ZP0
        lda #>((CREATURE_SPRITES_ADDR + LASER_START * 128)>>5)
        sta ZP1
        lda .laserframe
        asl
        asl
        +Add16 ZP0     ;add frame * 4 because sprite size >> 5 = 4
        lda ZP0
        sta VERA_DATA0
        lda ZP1
        sta VERA_DATA0

        ;set position
        txa
        asl
        clc
        adc _ismovingleft
        tay
        lda .laseroffsettable,y     ;read horizontal position which depends on direction and if it is first or second laserbeam sprite
        sta _laser_xpos
        sta VERA_DATA0
        stz VERA_DATA0
        lda #LASER_YPOS        
        sta VERA_DATA0              ;vertical position is same as player 
        stz VERA_DATA0

        ;set attributes
        lda #LASER_COLLISION_MASK+8
        clc
        adc _ismovingleft
        sta VERA_DATA0              ;set collision mask, enable sprite and flip laser horizontally if player is facing left
        lda #%01010010                  
        sta VERA_DATA0              ;set 16x16 and palette 2

        inx
        cpx #2
        bne -

        inc .lasertime            
        lda .lasertime
        cmp #LASER_FIRE_TIME
        bne +
        jsr StopLaser
+       rts

; horizontal offset for laserbeam sprites, first sprite facing right, first sprite facing left, second sprite facing right, second sprite facing left
.laseroffsettable:  !byte  SCREENWIDTH/2+6, SCREENWIDTH/2-6-32, SCREENWIDTH/2+6+16, SCREENWIDTH/2-6-16 

ReloadLaser:
        lda #1
        sta .laserenabled
        lda #2
        sta ZP0
        +VPokeSpritesI LASER0_ATTR_0, ZP0, 0    ;disable sprites  
        rts

StopLaser:
        stz .lasertime
        stz .laserenabled
        lda #2
        sta ZP0
        +VPokeSpritesI LASER0_ATTR_0, ZP0, 0    ;disable sprites       
        rts