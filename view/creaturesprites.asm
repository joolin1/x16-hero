;*** creaturesprites.asm ***************************************************************************

CREATURE_ADDR_L       = $FC28   ;First creature is sprite 5
CREATURE_MODE_ADDR_H  = $FC29
CREATURE_XPOS_L       = $FC2A
CREATURE_XPOS_H       = $FC2B
CREATURE_YPOS_L       = $FC2C
CREATURE_YPOS_H       = $FC2D
CREATURE_ATTR_0       = $FC2E
CREATURE_ATTR_1       = $FC2F

MAX_SPRITE_COUNT      = 16

;sprite start offsets for creature sprites
SPIDER_START     = 0
CLAW_START       = 4
ALIEN_START      = 8
BAT_START        = 12
LAMP_START       = 16

;table for which sprite frame each creature starts with
.frametable             !byte SPIDER_START, CLAW_START, ALIEN_START, BAT_START, LAMP_START
.frameoffset            !byte 0 ;animation offset for creature sprites
.creatureanimationdelay !byte 0
CREATURE_ANIMATION_COUNT = 4    ;how many animation frames there are for each creature
CREATURE_ANIMATION_DELAY = 12   ;how manny jiffies to wait before next frame

;movement pattern for alien sprite
.alienxmovementtable    !word   0,  2,  3,  5,  6,  8,  9, 10, 11, 12, 13, 14, 15, 15, 16, 16 ;sin angles 0-
.alienymovementtable    !word  16, 16, 16, 15, 15, 14, 13, 12, 11, 10,  9,  8,  6,  5,  3,  2 ;sin angles 90-
                        !word   0, -2, -3, -5, -6, -8, -9,-10,-11,-12,-13,-14,-15,-15,-16,-16 ;sin angles 180-
                        !word -16,-16,-16,-15,-15,-14,-13,-12,-11,-10, -9, -8, -6, -5, -3, -2 ;sin angles 270-
                        !word   0,  2,  3,  5,  6,  8,  9, 10, 11, 12, 13, 14, 15, 15, 16, 16 ;cos angles 270-
.batxmovementtable      !word   0,  2,  4,  6,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30 ;just move to the right and left
                        !word  32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62
                        !word  64, 62, 60, 58, 56, 54, 52, 50, 48, 46, 44, 42, 40, 38, 36, 34
                        !word  32, 30, 28, 26, 24, 22, 20, 18, 16, 14, 12, 10,  8,  6,  4,  2

.movementindex          !byte   0
MOVEMENT_COUNT = 64

_spriteypositiontable   !fill MAX_SPRITE_COUNT*2,0      ;reserve space for 16 visible sprites at the same time, positions are 16 bit
_spritexpositiontable   !fill MAX_SPRITE_COUNT*2,0
_spritetypetable        !fill MAX_SPRITE_COUNT,0        ;type of sprite, same as tile category
_spriteframetable       !fill MAX_SPRITE_COUNT,0        ;which sprite frame each creature is represented by
_spriteindextable       !fill MAX_SPRITE_COUNT          ;which index creature has in global table of creatures
_spritecount            !byte 0                         ;number of visible creature sprites

.ypos_lo     = ZP2
.ypos_hi     = ZP3
.xpos_lo     = ZP4
.xpos_hi     = ZP5
.xpos_offset = ZP6
.ypos_offset = ZP8

HideCreatures:
        lda #MAX_SPRITE_COUNT
        sta ZP0      
        +VPokeSpritesI CREATURE_ATTR_0, ZP0, 0
        rts

UpdateCreatureSprites:          ;This is called at VBLANK to update screen with already prepared data
        jsr HideCreatures       ;start with disabling all sprites to avoid remnants if less number of sprites are visible this time compared to last time
        lda _spritecount
        bne +
        rts

+       jsr .UpdateFrameOffset

        lda #<CREATURE_ADDR_L       
        sta VERA_ADDR_L
        lda #>CREATURE_ADDR_L
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H
        ldy #0
       
        ;1 - set sprite address (frame)
--      lda #<CREATURE_SPRITES_ADDR>>5
        sta ZP0
        lda #>CREATURE_SPRITES_ADDR>>5
        sta ZP1
        lda _spriteframetable,y
        clc
        adc .frameoffset                        ;add offset to animate sprite    
        tax
        beq+
-       +Add16I ZP0, 4                          ;add frame index * 4 (size of a sprite >> 5) 
        dex
        bne -
+       lda ZP0
        sta VERA_DATA0
        lda ZP1
        sta VERA_DATA0

        ;2 - set sprite position
        tya
        asl
        tay
        lda _spritexpositiontable,y
        sta VERA_DATA0
        lda _spritexpositiontable+1,y
        sta VERA_DATA0 
        lda _spriteypositiontable,y
        sta VERA_DATA0
        lda _spriteypositiontable+1,y
        sta VERA_DATA0
        tya
        lsr
        tay

        ;3 - set sprite attributes
        lda _spritetypetable,y
        cmp #TILECAT_LAMP
        bne +
        lda #LAMP_COLLISION_MASK + 8
        bra ++
+       lda #CREATURE_COLLISION_MASK + 8        
++      sta VERA_DATA0                          ;set collision mask and enable sprite between layers
        lda #%01010010                          ;heigh/width = 16, palette offset = 2
        sta VERA_DATA0

        iny
        cpy _spritecount
        bne --
        rts

.UpdateFrameOffset:             ;set animation frame for creature sprites
        +CheckTimer .creatureanimationdelay, CREATURE_ANIMATION_DELAY
        beq +
        inc .frameoffset
        lda .frameoffset
        cmp #CREATURE_ANIMATION_COUNT
        bne +
        stz .frameoffset      
+       rts

CreaturesTick:          ;Called every jiffy to prepare data for next frame

        ;init loop and pointers
        ldy #0                  ;creature index
        ldx #0                  ;visible sprite index

        ;check if creature is alive
-       lda _creaturekilledtable,y
        bne ++

        ;get sprite world position
        tya
        asl
        tay        
        lda _creatureypositiontable,y
        sta .ypos_lo
        lda _creatureypositiontable+1,y
        sta .ypos_hi
        lda _creaturexpositiontable,y
        sta .xpos_lo
        lda _creaturexpositiontable+1,y
        sta .xpos_hi
        tya
        lsr
        tay

        ;calculate vertical screen position
        jsr .GetVerticalSpritePosition
        lda ZP1
        cmp #2                  ;if returned position is 512, it means sprite is not visible
        beq ++

        ;save screen position, sprite is in what we count as the visible area
        lda ZP0                 
        sta .ypos_lo
        lda ZP1
        sta .ypos_hi

        ;calculate horizontal screen position
        jsr .GetHorizontalSpritePosition
        lda ZP1
        cmp #2
        beq ++

        ;save screen position, sprite is in what we count as the visible area
        lda ZP0                 
        sta .xpos_lo
        lda ZP1
        sta .xpos_hi

        ;save sprite properties     
        phy
        tya 
        sta _spriteindextable,x         ;save creature index (first creature in global list has index 0 and so on)
        lda _creaturetypetable,y
        sta _spritetypetable,x          ;save sprite type
        sec
        sbc #TILECAT_FIRST_CREATURE     ;subtract with first creature's tile category to obtain a zero index
        tay
        lda .frametable,y   
        sta _spriteframetable,x         ;save sprite frame to start with

        jsr .AddSpriteMovement          ;add movement if sprite is alien or bat
        ply

        ;save sprite position in sprite position table
        txa 
        asl
        tax        
        lda .ypos_lo
        sta _spriteypositiontable,x
        lda .ypos_hi
        sta _spriteypositiontable+1,x
        lda .xpos_lo
        sta _spritexpositiontable,x
        lda .xpos_hi
        sta _spritexpositiontable+1,x
        txa
        lsr
        tax

        inx     ;increment sprite table pointer
++      iny     ;increment creature table pointer    
        cpy _creaturecount
        beq +
        jmp -

+       stx _spritecount       
        inc .movementindex              ;increase movement index for aliens
        lda .movementindex
        cmp #MOVEMENT_COUNT
        bne +
        stz .movementindex

        ;DEBUG
        ; lda #<_spriteypositiontable
        ; sta ZP0
        ; lda #>_spriteypositiontable
        ; sta ZP1
        ; lda #<_spritexpositiontable
        ; sta ZP2
        ; lda #>_spritexpositiontable
        ; sta ZP3
        ; lda #<_spritetypetable
        ; sta ZP4
        ; lda #>_spritetypetable
        ; sta ZP5
        ; lda #<_spriteframetable
        ; sta ZP6
        ; lda #>_spriteframetable
        ; sta ZP7        
        ;!byte $db
        ;END DEBUG
        rts

.AddSpriteMovement:                     ;add movement offset according to movement table if sprite is an alien
        lda _spritetypetable,x
        cmp #TILECAT_ALIEN
        bne +
        lda .movementindex
        asl
        tay
        lda .alienxmovementtable,y
        sta .xpos_offset
        lda .alienxmovementtable+1,y
        sta .xpos_offset+1
        lda .alienymovementtable,y
        sta .ypos_offset
        lda .alienymovementtable+1,y
        sta .ypos_offset+1
        +Add16 .xpos_lo, .xpos_offset
        +Add16 .ypos_lo, .ypos_offset
+       cmp #TILECAT_BAT
        bne +
        lda .movementindex
        asl
        tay
        lda .batxmovementtable,y
        sta .xpos_offset
        lda .batxmovementtable+1,y
        sta .xpos_offset+1
        +Add16 .xpos_lo, .xpos_offset
+       rts

.GetVerticalSpritePosition:
        +PositionSprite .ypos_lo, .ypos_hi, _ypos_lo, _ypos_hi, SCREENHEIGHT/2, 16
        rts

.GetHorizontalSpritePosition:
        +PositionSprite .xpos_lo, .xpos_hi, _xpos_lo, _xpos_hi, SCREENWIDTH/2, 16
        rts