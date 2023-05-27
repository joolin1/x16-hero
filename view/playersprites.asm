;*** playersprites.asm ********************************************************************************

;player sprite frames
PLAYER_FLYING_START  = 0
PLAYER_FLYING_STOP   = 5
PLAYER_WALKING_START = 6
PLAYER_WALKING_STOP  = 11
PLAYER_DEAD          = 12

;player sprite
PLAYER_INDEX = 1        ;player is sprite 1
PLAYERWIDTH  = 16
PLAYERHEIGHT = 32
WALKING_DELAY = 6

;addresses for sprite attributes of first creature that has sprite index 5
PLAYER_ADDR_L       = $FC08
PLAYER_MODE_ADDR_H  = $FC09
PLAYER_XPOS_L       = $FC0A
PLAYER_XPOS_H       = $FC0B
PLAYER_YPOS_L       = $FC0C
PLAYER_YPOS_H       = $FC0D
PLAYER_ATTR_0       = $FC0E
PLAYER_ATTR_1       = $FC0F

!macro SetSprite .index, .frame, .flip, .collision_mask {        ;IN: index of sprite to change, index of frame, whether to flip sprit horzontally
        lda .frame
        sta ZP0
        stz ZP1
        +MultiplyBy8 ZP0                        ;sprites are 256 bytes and 256/32 = 8
        lda ZP0
        +VPoke SPR0_ADDR_L+.index*8      
        lda ZP1
        clc
        adc #>PLAYER_SPRITES_ADDR>>5                   ;add base address of sprites
        +VPoke SPR0_MODE_ADDR_H+.index*8

        ;flip sprite if necessary
        lda .flip
        ora #.collision_mask+8                   ;don't forget to set bit 2 to keep a z depth of 1 (= behind layers)
        +VPoke SPR0_ATTR_0+.index*8
}

!macro SetSprite .index, .frame {               ;IN: index of sprite to change, index of frame
        lda .frame
        sta ZP0
        stz ZP1
        +MultiplyBy8 ZP0                        ;sprites are 256 bytes and 256/32 = 8
        lda ZP0
        +VPoke SPR0_ADDR_L+.index*8      
        lda ZP1
        clc
        adc #>PLAYER_SPRITES_ADDR>>5                   ;add base address of sprites
        +VPoke SPR0_MODE_ADDR_H+.index*8
}

ShowPlayer:
        +VPokeI SPR1_ATTR_0, PLAYER_COLLISION_MASK+8    ;enable sprite and set collision mask
        +VPokeI SPR1_ATTR_1, %10010001                  ;set palette 1
        +VPokeI SPR1_XPOS_L, SCREENWIDTH/2-PLAYERWIDTH/2
        +VPokeI SPR1_XPOS_H, 0
        +VPokeI SPR1_YPOS_L, SCREENHEIGHT/2-PLAYERHEIGHT/2
        +VPokeI SPR1_YPOS_H, 0
        lda #PLAYER_FLYING_START
        sta .frame       
        +SetSprite PLAYER_INDEX, .frame
        rts

ShowDeadPlayer:
        lda #PLAYER_DEAD
        sta .frame
        +SetSprite PLAYER_INDEX, .frame
        jsr StopLaser
        rts

HidePlayer:
        +VPokeI SPR1_ATTR_0,0    ;disable sprite 1
        rts

SetPlayerSpritePos:
        lda #<SPR1_XPOS_L
        sta VERA_ADDR_L
        lda #>SPR1_XPOS_L
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H
        +PositionSprite _xpos_lo, _xpos_hi, _camxpos_lo, _camxpos_hi, SCREENWIDTH/2, 16
        lda ZP0
        ;sta _spr_xpos_lo
        sta VERA_DATA0
        lda ZP1
        ;sta _spr_xpos_lo+1
        sta VERA_DATA0
        +PositionSprite _ypos_lo, _ypos_hi, _camypos_lo, _camypos_hi, SCREENHEIGHT/2, 32
        lda ZP0        
        sta VERA_DATA0
        lda ZP1
        sta VERA_DATA0
        rts

;_spr_xpos_lo    !byte 0,0      ;debug info

UpdatePlayerSprite:
        jsr PlaySoundIfFlying
        jsr SetPlayerSpritePos     
        lda _isflying
        beq +
        jsr .GetFlyingFrame
        bra ++
+       jsr .GetWalkingFrame
++      +SetSprite PLAYER_INDEX, .frame, _ismovingleft, PLAYER_COLLISION_MASK
        lda _isflying
        sta .wasflying          ;save flying status for use next time
        rts

PlaySoundIfFlying:
        lda _istakingoff
        bne +
        lda _isflying
        bne +
        jsr StopEngineSound
        rts
+       jsr PlayEngineSound
        rts

.GetFlyingFrame:
        lda .wasflying
        bne +
        lda #PLAYER_FLYING_START        ;player has just taken off - set first flying sprite
        sta .frame
        rts
+       inc .frame                      ;player is flying - set next flying sprite
        lda .frame
        cmp #PLAYER_FLYING_STOP+1
        beq +
        rts
+       lda #PLAYER_FLYING_START        ;flying animation has reached end - set first flying sprite again
        sta .frame
        rts

.GetWalkingFrame:
        lda .wasflying         
        beq +
        lda #PLAYER_WALKING_START       ;player has just landed - set first walking sprite
        sta .frame
        stz .animationdelay
        rts
+       lda _ismoving
        bne +
        lda #PLAYER_WALKING_START       ;player is not moving - set first walking sprite
        sta .frame
        rts
+       +CheckTimer .animationdelay, WALKING_DELAY
        bne +
        rts
+       inc .frame                      ;player is walking - set next walking sprite
        lda .frame
        cmp #PLAYER_WALKING_STOP+1
        beq +
        rts
+       lda #PLAYER_WALKING_START       ;walking animation has reached end - set first walking sprite again
        sta .frame
        rts

.wasflying      !byte 0         ;whether player has just landed
.frame          !byte 0         ;current sprite frame
.animationdelay !byte 0         ;delay counter to slow down animation 

