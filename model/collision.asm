;*** collision.asm *********************************************************************************

PLAYER_COLLISION_MASK   = %01010000
CREATURE_COLLISION_MASK = %00110000    ;Creatures can either collide with the player or the shots from the player.
LAMP_COLLISION_MASK     = %01000000
LASER_COLLISION_MASK    = %00100000    ;laser should collide with creatures but not with player

.spritexpos = ZP2
.spriteypos = ZP4
.refxpos   = ZP6        ;reference point, can be player or laserbeam
.refypos   = ZP8

DISTANCE_LIMIT = 20
DEAD_DELAY = 120

DARK_TIME = 300

UpdateLight:            ;if dark light up after a certain amount of time
        lda _darkmode
        beq +
        +Countdown16bit _darktimecount_lo
        beq TurnOnLight
+       rts

TurnOnLight: 
        +CopyPalettesToVRAM _graphicspalettes, 1, 3
        stz _darkmode
        rts

TurnOffLight:
        lda #<GRAPHICS_PALETTES
        sta VERA_ADDR_L
        lda #>GRAPHICS_PALETTES           
        sta VERA_ADDR_M
        lda #$11                
        sta VERA_ADDR_H

        ldy #0           
-       lda _graphicspalettes,y
        sta ZP0         ;temp save .A
        lsr             ;make color darker by dividing color value by four
        lsr
        and #$f0        ;keep high nybble 
        sta ZP1         ;temp save high nybble
        lda ZP0         ;restore original value
        and #$0f        ;keep low nybble
        lsr             ;make color darker by dividing color value by four
        lsr
        ora ZP1         ;combine high and low nybble
        sta VERA_DATA0     
        iny
        cpy #96         ;3 palettes * 16 colors * 2 bytes             
        bne -
        lda #<DARK_TIME
        sta _darktimecount_lo
        lda #>DARK_TIME
        sta _darktimecount_hi
        lda #1
        sta _darkmode
        rts

KillPlayer:
        lda #SCREENWIDTH/2
        sta .refxpos
        stz .refxpos+1
        lda #SCREENHEIGHT/2
        sta .refypos
        stz .refypos+1
        jsr .GetCreatureIndex
        lda _spriteindextable,y         ;read which index sprite has in global creature list
        tax
        lda #CREATURE_DEAD              ;kill creature instantly (no dying animation)             
        sta _creaturekilledtable,x      ;flag creature as dead
        jsr ShowDeadPlayer
        +CheckTimer .deaddelay, DEAD_DELAY      ;returns .A = true if timer ready      
        rts

.deaddelay      !byte 0

KillCreature:
        ;1 - set reference point, i e the middle of the laser beam
        lda _ismovingleft
        beq +
        lda #SCREENWIDTH/2-LASER_XOFFSET           
        bra ++
+       lda #SCREENWIDTH/2+LASER_XOFFSET           
++      sta .refxpos
        stz .refxpos+1       
        lda #SCREENHEIGHT/2-LASER_YOFFSET
        sta .refypos
        stz .refypos+1
        jsr .GetCreatureIndex
        lda _spriteindextable,y         ;read which index sprite has in global creature list
        tax
        lda #CREATURE_DYING             
        sta _creaturekilledtable,x      ;flag creature as dying (dying animation will begin)
        rts

.GetCreatureIndex:      ;IN: refxpos, refypos (16 bit) - position of player or laserbeam. OUT: .Y = sprite index 

        ldy #0 ;loop through all visible creatures, find the one close to the laser beam and kill it

        ;2 - get position for current creature      
-       tya
        asl
        tay
        lda _spritexpositiontable,y
        sta .spritexpos
        lda _spritexpositiontable+1,y
        sta .spritexpos+1
        lda _spriteypositiontable,y
        sta .spriteypos
        lda _spriteypositiontable+1,y
        sta .spriteypos+1
        tya
        lsr
        tay

        ;3 - calculate horizontal distance between laserbeam and creature
        +Sub16 .spritexpos, .refxpos
        +Abs16 .spritexpos
        +Cmp16I .spritexpos, DISTANCE_LIMIT
        bcs +                           ;if too far away skip to next

        ;4 - calculate vertical distance between laserbeam and creature
        +Sub16 .spriteypos, .refypos
        +Abs16 .spriteypos
        +Cmp16I .spriteypos, DISTANCE_LIMIT
        bcs +                           ;if too far away skip to next  

        rts

+       iny
        cpy _spritecount
        beq ++
        jmp -
++      rts
