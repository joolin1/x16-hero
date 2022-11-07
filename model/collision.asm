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
        lsr             ;.A/8
        lsr
        lsr
        and #$f0        ;keep high nybble 
        sta ZP1         ;temp save high nybble
        lda ZP0         ;restore original value
        and #$0f        ;keep low nybble
        lsr             ;.A/8
        lsr
        lsr
        ora ZP1         ;combine high and low nybble
        sta VERA_DATA0     
        iny
        cpy #96         ;3 palettes * 16 colors * 2 bytes             
        bne -
        lda #<1200
        sta _darktimecount_lo
        lda #>1200
        sta _darktimecount_hi
        lda #1
        sta _darkmode
        rts

KillPlayer:
        ; lda #SCREENWIDTH/2                    ;for now don't kill creature that player might have collided with, lever restarts when player dies
        ; sta .refxpos
        ; stz .refxpos+1
        ; lda #SCREENHEIGHT/2
        ; sta .refypos
        ; stz .refypos+1
        ; jsr .MarkCreatureAsDead
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

.MarkCreatureAsDead:
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

        ;5 - kill creature
        lda _spriteindextable,y         ;read which index sprite has in global creature list
        tax
        lda #1
        sta _creaturekilledtable,x      ;flag creature as dead
        rts

+       iny
        cpy _spritecount
        beq ++
        jmp -
++      rts
