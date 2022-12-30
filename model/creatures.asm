;*** creatures.asm *********************************************************************************

_creatureypositiontable !fill 256,0     ;allow for 128 creatures, position is 16 bit
_creaturexpositiontable !fill 256,0
_creaturetypetable      !fill 128,0
_creaturefliptable      !fill 128,0
_creaturekilledtable    !fill 128,0
_creaturecount          !byte 0

.currenttile_lo         !byte 0 ;tile index 7:0
.currenttile_hi         !byte 0 ;tile info, we're interested in h-flip = bit 2

InitCreatures:                  ;Called when new level is set up. Tilemap is analyzed and tables with sprite information are built
        jsr .InitCreatureTables
        jsr CreaturesTick      
        rts

RestartCreatures:
        jsr .ResurrectCreatures        ;current choice is to not ressurect any creatures when level i restarted
        jsr CreaturesTick
        rts

.InitCreatureTables:            ;traverse whole tilemap and build tables that tell where creature sprites are located, at the same time exchange them for an empty tile
        stz _creaturecount

        lda #<L0_MAP_ADDR       ;set read registers to first tile
        sta VERA_ADDR_L
        lda #>L0_MAP_ADDR
        sta VERA_ADDR_M
        lda #$10                ;auto increment by one
        sta VERA_ADDR_H

        ldy #0                  ;(it doesn't matter if height or width is 256)
--      ldx #0
-       lda VERA_DATA0          ;read tile data (lower byte)
        sta .currenttile_lo
        lda VERA_DATA0          ;read tile data (upper byte)
        sta .currenttile_hi
        phy
        lda .currenttile_lo
        tay
        lda _tilecategorytable,y  ;load category for this tile
        ply
        cmp #TILECAT_SPIDER 
        bne +
        jsr .AddCreature
        bra ++
+       cmp #TILECAT_CLAW
        bne +
        jsr .AddCreature
        bra ++
+       cmp #TILECAT_ALIEN
        bne +
        jsr .AddCreature
        bra ++
+       cmp #TILECAT_BAT
        bne +
        jsr .AddCreature
        bra ++
+       cmp #TILECAT_LAMP          ;the lamp is a special case, it is represented by a sprite to allow pixelperfect collisions with player, killed means in this case that the lamp goes dark
        bne ++
        jsr .AddCreature
++      inx
        cpx _levelwidth
        bne -
        iny
        cpy _levelheight
        bne --
        rts      

.AddCreature:           ;add creature to current position
        phy

        sty ZP0         ;store row and col
        stz ZP1
        stx ZP2
        stz ZP3

        ;save creature type and mark it as alive
        ldy _creaturecount
        sta _creaturetypetable,y
        lda .currenttile_hi
        and #4                          ;filter out h-flip (bit 2)
        lsr                             ;move it to bit 0 because h-flip is bit 0 in sprite register
        lsr                             
        sta _creaturefliptable,y
        lda #0
        sta _creaturekilledtable,y

        ;convert from tilemap coordinates to world coordinates by multiplying with 16 (tile size) and adding 8 (half tile size)
        lda ZP0
        +MultiplyBy16 ZP0               
        +Add16I ZP0, 8
        lda ZP2
        +MultiplyBy16 ZP2               
        +Add16I ZP2, 8

        ;save creature position in world coordinates
        lda _creaturecount
        asl                             ;multiply by two because positions are 16 bit      
        tay
        lda ZP0
        sta _creatureypositiontable,y
        lda ZP1
        sta _creatureypositiontable+1,y
        lda ZP2
        sta _creaturexpositiontable,y
        lda ZP3
        sta _creaturexpositiontable+1,y
        
        inc _creaturecount
        +Dec24 VERA_ADDR_L
        +Dec24 VERA_ADDR_L
        lda #TILE_SPACE
        sta VERA_DATA0                  ;delete creature from tilemap
        lda .currenttile_hi
        and #%11110011                  ;clear v-flip and h-flip if set
        sta VERA_DATA0
        ply
        rts

.ResurrectCreatures:
        lda #0
        ldy _creaturecount
-       dey
        sta _creaturekilledtable,y
        bne -
        rts