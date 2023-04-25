;*** creatures.asm *********************************************************************************

;creature tiles that are replaced with sprites
TILE_SPACE              = 0     ;used for replacing sprite tiles and blasted walls
TILE_FIRST_CREATURE     = 13
TILE_SPIDER             = 13
TILE_CLAW               = 14
TILE_ALIEN              = 15
TILE_BAT                = 16
TILE_PLANT              = 17
TILE_LAMP               = 18
TILE_LAST_CREATURE      = 18

;addresses for sprite attributes of first creature that has sprite index 5
CREATURE_ADDR_L       = $FC28
CREATURE_MODE_ADDR_H  = $FC29
CREATURE_XPOS_L       = $FC2A
CREATURE_XPOS_H       = $FC2B
CREATURE_YPOS_L       = $FC2C
CREATURE_YPOS_H       = $FC2D
CREATURE_ATTR_0       = $FC2E
CREATURE_ATTR_1       = $FC2F

;addresses pointing to image data of each creature. shifted by 5 to match how VERAs registers work
SPIDER_ADDR = CREATURE_SPRITES_ADDR >> 5
CLAW_ADDR   = (CREATURE_SPRITES_ADDR + CREATURE_SPRITES_SIZE *  8) >> 5
ALIEN_ADDR  = (CREATURE_SPRITES_ADDR + CREATURE_SPRITES_SIZE * 16) >> 5
BAT_ADDR    = (CREATURE_SPRITES_ADDR + CREATURE_SPRITES_SIZE * 24) >> 5
PLANT_ADDR  = (CREATURE_SPRITES_ADDR + CREATURE_SPRITES_SIZE * 32) >> 5
LAMP_ADDR   = (CREATURE_SPRITES_ADDR + CREATURE_SPRITES_SIZE * 40) >> 5
DIE_ADDR    = (CREATURE_SPRITES_ADDR + CREATURE_SPRITES_SIZE * 52) >> 5 ;animation when creature dies

CREATURE_HEIGHT = 16
CREATURE_WIDTH = 16

Z_DEPTH = 8     ;place sprites between layers

;type of creatures
TYPE_SPIDER     = 0
TYPE_CLAW       = 1
TYPE_ALIEN      = 2
TYPE_BAT        = 3
TYPE_PLANT      = 4
TYPE_LAMP       = 5     ;lamps are represented by sprites to allow pixel perfect collisions with player

_creatureaddrtable      !word SPIDER_ADDR, CLAW_ADDR, ALIEN_ADDR, BAT_ADDR, PLANT_ADDR, LAMP_ADDR       ;used to translate type to address

MAX_SPRITE_COUNT = 64                           ;maximum number of creatures allowed in a tilemap
_creaturecount                  !byte 0         ;number of creatures/sprites in the tilemap

;tables with sprite information beside what VERAs sprite attribute registers can hold
_creaturetypetable              !fill MAX_SPRITE_COUNT,0        ;creature type, used to apply right movement pattern
_creatureypostable              !fill MAX_SPRITE_COUNT*2,0      ;world coordinates (16 bit) for each sprite
_creaturexpostable              !fill MAX_SPRITE_COUNT*2,0
_creaturelifetable              !fill MAX_SPRITE_COUNT,0        ;if creature is alive 0 = dead, 1 = alive, 2-5 = dying stages
_creatureframetable             !fill MAX_SPRITE_COUNT,0        ;which animation frame each sprite is represented by
_creatureoffsetindextable       !fill MAX_SPRITE_COUNT,0        ;each creatures index for movement table (only relevant for aliens and bats)

;**************************************************************************************************
;*** Routines for initializing creatures when new level is loaded                               ***
;**************************************************************************************************

;temp variables
map_row_l = ZP0        
map_row_h = ZP1
map_col_l = ZP2
map_col_h = ZP3
spr_def_addr_l = ZP4
spr_def_addr_h = ZP5
spr_coll_mask = ZP6
currentsprite_reg_l = ZP7  ;address of next sprite in VERA's sprite registers that is free to use
currentsprite_reg_h = ZP8   
currenttile_lo = ZP9       ;current tile read from tilemap. IIIIIIII - tile index (7:0)
currenttile_hi = ZPA       ;PPPPVHII - P = Palette offset, V = V-flip, H = h-flip, I = tile index bits 8-9 (We're just interested in h-flip)

HideCreatures:
        lda #MAX_SPRITE_COUNT
        sta ZP0      
        +VPokeSpritesI CREATURE_ATTR_0, ZP0, 0  ;disable all sprites by seting z-depth to 0
        rts

InitCreatures:                          ;traverse whole tilemap and build tables that tell where creature sprites are located, at the same time exchange them for an empty tile
        jsr HideCreatures               ;start by disabling all creatures to start from scratch, an earlier level had maybe more creatures than the current

        lda #<CREATURE_ADDR_L           ;init to first attribute of first creature sprite
        sta currentsprite_reg_l
        lda #>CREATURE_ADDR_L
        sta currentsprite_reg_h
        stz _creaturecount

        lda #<L0_MAP_ADDR               ;set read registers to first tile in tilemap
        sta VERA_ADDR_L
        lda #>L0_MAP_ADDR
        sta VERA_ADDR_M
        lda #$10                        ;auto increment by one
        sta VERA_ADDR_H

        ldy #0                          ;(it doesn't matter if height or width is 256)
--      ldx #0
-       lda VERA_DATA0                  ;read tile data (lower byte)
        sta currenttile_lo
        lda VERA_DATA0                  ;read tile data (upper byte)
        sta currenttile_hi

        lda currenttile_lo
        cmp #TILE_FIRST_CREATURE
        bcc +
        cmp #TILE_LAST_CREATURE + 1
        bcs +
        jsr .AddCreature
+       inx
        cpx _levelwidth
        bne -
        iny
        cpy _levelheight
        bne --
        rts      

.AddCreature:           ;add creature to current position in tilemap
        phy
                  
        ;1 - set world coordinates for sprite
        sty map_row_l                   ;store row and col in temporary place
        stz map_row_h
        stx map_col_l
        stz map_col_h
        +MultiplyBy16 map_row_l         ;multiply by 16 (tile size) and add 8 (half tile) to get world coordinates
        +MultiplyBy16 map_col_l
        +Add16I map_row_l, 8
        +Add16I map_col_l, 8

        lda _creaturecount              ;store world coordinates for each sprite in tables
        tay

        ;2 - mark creature as alive, set its type, and give it a random frame and a random movement index 
        lda #CREATURE_ALIVE
        sta _creaturelifetable,y
        jsr .SetCreatureType
        jsr GetRandomNumber
        and #MOVEMENT_COUNT-1                   ;sprites who move have 64 different offset positions
        sta _creatureoffsetindextable,y
        and #FRAME_COUNT-1                      ;every sprite has eight frames
        sta _creatureframetable,y

        ;3 - store world coordinates for each sprite in tables
        tya
        asl
        tay 
        lda map_row_l
        sta _creatureypostable,y
        lda map_row_h
        sta _creatureypostable+1,y
        lda map_col_l
        sta _creaturexpostable,y
        lda map_col_h
        sta _creaturexpostable+1,y

        ;4 - set address for sprite
        lda #1                          ;switch to data port 1 because port 0 is used to access tilemap
        sta VERA_CTRL
        lda currentsprite_reg_l
        sta VERA_ADDR_L
        lda currentsprite_reg_h
        sta VERA_ADDR_M
        lda #$11                        ;auto increment by one     
        sta VERA_ADDR_H
        lda spr_def_addr_l              ;set address for current creature type
        sta VERA_DATA1
        lda spr_def_addr_h
        sta VERA_DATA1
        
        ;5 - set screen coordinates for sprite
        stz VERA_DATA1                  ;for now set screen x pos to 512 = outside the visible area
        lda #2
        sta VERA_DATA1
        stz VERA_DATA1                  ;for now set screen y pos to 0
        stz VERA_DATA1

        ;6 - set attributes for sprit
        lda currenttile_hi                      ;read high byte of current tile
        and #4                                  ;move h-flip bit to bit 0 to suit sprite register
        lsr
        lsr
        clc
        ora #Z_DEPTH                            ;set Z-depth
        ora spr_coll_mask                       ;set collision mask
        sta VERA_DATA1                          ;set collision mask, z-depth and flips
        lda #%01010010                          ;height  and width = 16, palette offset = 2
        sta VERA_DATA1
        stz VERA_CTRL                           ;switch back to data port 0
        
        ;7 - point to next sprite
        +Add16I currentsprite_reg_l, 8
        inc _creaturecount

        ;8 - finally delete creature tile from tilemap
        +Dec24 VERA_ADDR_L
        +Dec24 VERA_ADDR_L
        lda #TILE_SPACE
        sta VERA_DATA0                  
        lda currenttile_hi
        and #%11110011                  ;clear v-flip and h-flip if set
        sta VERA_DATA0

        ply
        rts

.SetCreatureType:
        lda currenttile_lo

        cmp #TILE_SPIDER 
        bne +
        lda #TYPE_SPIDER
        sta _creaturetypetable,y
        lda #<SPIDER_ADDR
        sta spr_def_addr_l
        lda #>SPIDER_ADDR
        sta spr_def_addr_h
        lda #CREATURE_COLLISION_MASK
        sta spr_coll_mask
        rts
+       cmp #TILE_CLAW
        bne +
        lda #TYPE_CLAW
        sta _creaturetypetable,y
        lda #<CLAW_ADDR
        sta spr_def_addr_l
        lda #>CLAW_ADDR
        sta spr_def_addr_h
        lda #CREATURE_COLLISION_MASK
        sta spr_coll_mask
        rts
+       cmp #TILE_ALIEN
        bne +
        lda #TYPE_ALIEN
        sta _creaturetypetable,y
        lda #<ALIEN_ADDR
        sta spr_def_addr_l
        lda #>ALIEN_ADDR
        sta spr_def_addr_h
        lda #CREATURE_COLLISION_MASK
        sta spr_coll_mask
        rts
+       cmp #TILE_BAT
        bne +
        lda #TYPE_BAT
        sta _creaturetypetable,y
        lda #<BAT_ADDR
        sta spr_def_addr_l
        lda #>BAT_ADDR
        sta spr_def_addr_h
        lda #CREATURE_COLLISION_MASK
        sta spr_coll_mask
        rts
+       cmp #TILE_PLANT
        bne +
        lda #TYPE_PLANT
        sta _creaturetypetable,y
        lda #<PLANT_ADDR
        sta spr_def_addr_l
        lda #>PLANT_ADDR
        sta spr_def_addr_h
        lda #CREATURE_COLLISION_MASK
        sta spr_coll_mask
        rts
+       cmp #TILE_LAMP
        bne +
        lda #TYPE_LAMP
        sta _creaturetypetable,y        
        lda #<LAMP_ADDR
        sta spr_def_addr_l
        lda #>LAMP_ADDR
        sta spr_def_addr_h
        lda #LAMP_COLLISION_MASK
        sta spr_coll_mask
+       rts

;**************************************************************************************************
;*** Routines for updating creatures during gameplay                                            ***
;**************************************************************************************************

CREATURE_DEAD             = 0   ;creature health
CREATURE_ALIVE            = 1
CREATURE_DYING_START      = 2   ;dying is represented by four general explosion sprite frames
CREATURE_DYING_STOP       = 6   ;when reaching this stage, sprite is disabled

CREATURE_ANIMATION_DELAY        = 16    ;how manny jiffies to wait before next frame
FRAME_COUNT                     = 8     ;how many frames used for animating sprite
MOVEMENT_COUNT                  = 64    ;how many offset positions used for making sprite move in a certain pattern

;movement patterns, 16 bit because sprite postions are 16 bit (adding 8-bit negative numbers to 16-bit numbers do not work...)
;movement pattern for alien, circle counter clockwise
; .alienxmovementtable    !word   0,  2,  3,  5,  6,  8,  9, 10, 11, 12, 13, 14, 15, 15, 16, 16 ;sin angles 0-
; .alienymovementtable    !word  16, 16, 16, 15, 15, 14, 13, 12, 11, 10,  9,  8,  6,  5,  3,  2 ;sin angles 90-
;                         !word   0, -2, -3, -5, -6, -8, -9,-10,-11,-12,-13,-14,-15,-15,-16,-16 ;sin angles 180-
;                         !word -16,-16,-16,-15,-15,-14,-13,-12,-11,-10, -9, -8, -6, -5, -3, -2 ;sin angles 270-
;                         !word   0,  2,  3,  5,  6,  8,  9, 10, 11, 12, 13, 14, 15, 15, 16, 16 ;cos angles 270-

;movement pattern for alien, circle clockwise circle
.alienyoffsettable      !word -16,-16,-16,-15,-15,-14,-13,-12,-11,-10, -9, -8, -6, -5, -3, -2 ;sin angles 270-
.alienxoffsettable      !word   0,  2,  3,  5,  6,  8,  9, 10, 11, 12, 13, 14, 15, 15, 16, 16 ;sin angles 0-
                        !word  16, 16, 16, 15, 15, 14, 13, 12, 11, 10,  9,  8,  6,  5,  3,  2 ;sin angles 90-
                        !word   0, -2, -3, -5, -6, -8, -9,-10,-11,-12,-13,-14,-15,-15,-16,-16 ;sin angles 180-
                        !word -16,-16,-16,-15,-15,-14,-13,-12,-11,-10, -9, -8, -6, -5, -3, -2 ;sin angles 270-

;movement pattern for bat, move horizontally back and forth slightly slower when turning
.batxoffsettable        !word   2,  3,  4,  6,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30
                        !word  32, 34, 36, 38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 61
                        !word  62, 61, 60, 58, 56, 54, 52, 50, 48, 46, 44, 42, 40, 38, 36, 34
                        !word  32, 30, 28, 26, 24, 22, 20, 18, 16, 14, 12, 10,  8,  6,  4,  3

;temp variables
.pos_lo         = ZPA
.pos_hi         = ZPB
.addr_lo        = ZPC
.addr_hi        = ZPD
.nextframeflag  = ZPE
.creatureanimationdelay !byte   0

DisableCreatureSprite:                          ;IN: .Y = index of creature sprite to disable
        lda #<CREATURE_ATTR_0                   ;load base address = attribute 0 of first creature sprite
        sta ZP0
        lda #>CREATURE_ATTR_0
        sta ZP1
        tya                                     ;take index * 8
        asl
        asl
        asl
        +Add16 ZP0                              ;add result to base address to get attribute address for right sprite
        lda #0
        +VPokeIndirect ZP0                      ;disable sprite
        rts

DisarmCreatureSprite:                           ;IN: .Y = index of creature sprite to disarm = remove collision mask
        lda #<CREATURE_ATTR_0                   ;load base address = attribute 0 of first creature sprite
        sta ZP0
        lda #>CREATURE_ATTR_0
        sta ZP1
        tya                                     ;take index * 8
        asl
        asl
        asl
        +Add16 ZP0                              ;add result to base address to get attribute address for right sprite
        lda #Z_DEPTH
        +VPokeIndirect ZP0                      ;clear collision mask, keep Z-depth
        rts

.HandleDyingCreature:                           ;IN. .A = creature status, .Y = index of dying/dead creature
        
        ;creature dying process is finished - disable sprite
+       cmp #CREATURE_DYING_STOP
        bne +
        lda #CREATURE_DEAD
        sta _creaturelifetable,y
        +Add16I VERA_ADDR_L, 6                  ;add 6 to go to address for attribute 0
        lda #0                          
        sta VERA_DATA0                          ;disable sprite
        +Sub16I VERA_ADDR_L, 5                  ;sub 5 to go to back to x pos address
        rts

        ;creature is dying - display next dying frame
+       inc                                     
        sta _creaturelifetable,y                ;set next frame/step in dying process
        dec
        ldx #<DIE_ADDR
        stx .addr_lo
        ldx #>DIE_ADDR
        stx .addr_hi
        sec 
        sbc #CREATURE_DYING_START
        asl
        asl
        +Add16 .addr_lo
        lda .addr_lo
        sta VERA_DATA0
        lda .addr_hi
        sta VERA_DATA0
        rts

UpdateCreatures:                                ;called at VBLANK to update sprite positions and frames
        +CheckTimer .creatureanimationdelay, CREATURE_ANIMATION_DELAY    ;slow down creature movement
        sta .nextframeflag                      ;flag if time for next frame or not        

        lda #<CREATURE_ADDR_L                   ;start with first position attribute of first creature sprite
        sta VERA_ADDR_L
        lda #>CREATURE_ADDR_L
        sta VERA_ADDR_M
        lda #$11                                ;auto increment by one     
        sta VERA_ADDR_H
        ldy #0                                  ;.Y = creature index 

.CreatureLoop:                                  ;1 - check if creature is alive
        lda _creaturelifetable,y
        cmp #CREATURE_ALIVE
        beq .SetCreatureFrame
        cmp #CREATURE_DEAD
        beq .NextCreature
        phy
        jsr .HandleDyingCreature
        ply
        bra .SetCreaturePosition

.NextCreature:                                  ;creature is dead, skip to next
        +Add16I VERA_ADDR_L, 8       
        iny                                       
        cpy _creaturecount
        bne .CreatureLoop                                   
        rts

.SetCreatureFrame:                              ;2 - set sprite frame
        lda .nextframeflag
        bne +
        +Add16I VERA_ADDR_L,2
        bra .SetCreaturePosition
+       lda _creaturetypetable,y                ;read creature type
        asl
        tax
        lda _creatureaddrtable,x                ;read base address for this type of creature
        sta .addr_lo
        lda _creatureaddrtable+1,x
        sta .addr_hi        
        lda _creatureframetable,y               ;read current frame
        inc
        and #FRAME_COUNT-1
        sta _creatureframetable,y               ;step to next frame
        asl
        asl                                     ;multiply by 4 (sprite size = 128 and 128 >> 5 = 4)
        +Add16 .addr_lo                         ;add frame offset to base address
        lda .addr_lo                            ;set frame by writing to sprite registers
        sta VERA_DATA0
        lda .addr_hi
        sta VERA_DATA0        
       
.SetCreaturePosition:                           ;3- calculate and set sprite position
        tya
        asl
        tax
        phx

        lda _creaturexpostable,x
        sta .pos_lo
        lda _creaturexpostable+1,x
        sta .pos_hi
        jsr .GetHorizontalSpritePosition
        jsr .AddHorizontalOffset              
        lda ZP0
        sta VERA_DATA0
        lda ZP1
        sta VERA_DATA0

        plx
        lda _creatureypostable,x
        sta .pos_lo
        lda _creatureypostable+1,x
        sta .pos_hi
        jsr .GetVerticalSpritePosition
        jsr .AddVerticalOffset
        lda ZP0
        sta VERA_DATA0
        lda ZP1
        sta VERA_DATA0

        lda _creatureoffsetindextable,y         ;step to next entry in offset table
        inc
        and #MOVEMENT_COUNT-1
        sta _creatureoffsetindextable,y

        +Add16I VERA_ADDR_L, 2                  ;add 2 to get address for x pos of next sprite       
        iny
        cpy _creaturecount
        beq +
        jmp .CreatureLoop        
+       rts

.GetHorizontalSpritePosition:   ;OUT: ZP0,ZP1 = x pos. x pos = 512 if not visible
        +PositionSprite .pos_lo, .pos_hi, _camxpos_lo, _camxpos_hi, SCREENWIDTH/2, 16
        rts

.GetVerticalSpritePosition:     ;OUT: ZP0,ZP1 = y pos. y pos = 512 if not visible
        +PositionSprite .pos_lo, .pos_hi, _camypos_lo, _camypos_hi, SCREENHEIGHT/2, 16
        rts

.AddHorizontalOffset:           ;IN: ZP0,ZP1 = current position. OUT: ZP0,ZP1 = new position
        lda _creaturetypetable,y
        cmp #TYPE_ALIEN
        bne +
        lda _creatureoffsetindextable,y
        asl
        tax
        lda .alienxoffsettable,x
        sta ZP2
        lda .alienxoffsettable+1,x
        sta ZP3
        +Add16 ZP0, ZP2
        rts
+       cmp #TYPE_BAT
        bne +
        lda _creatureoffsetindextable,y
        asl
        tax
        lda .batxoffsettable,x
        sta ZP2
        lda .batxoffsettable+1,x
        sta ZP3
        +Add16 ZP0, ZP2
+       rts

.AddVerticalOffset:             ;IN: ZP0,ZP1 = current position. OUT: ZP0,ZP1 = new position
        lda _creaturetypetable,y
        cmp #TYPE_ALIEN
        beq +
        rts
+       lda _creatureoffsetindextable,y
        asl
        tax
        lda .alienyoffsettable,x
        sta ZP2
        lda .alienyoffsettable+1,x
        sta ZP3
        +Add16 ZP0, ZP2
        rts