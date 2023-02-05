;*** collision.asm *********************************************************************************

PLAYER_COLLISION_MASK   = %01010000
CREATURE_COLLISION_MASK = %00110000    ;Creatures can either collide with the player or the shots from the player.
LAMP_COLLISION_MASK     = %01000000
LASER_COLLISION_MASK    = %00100000    ;laser should collide with creatures but not with player

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

KillPlayer:                             ;OUT: .Y = index of creature that player collided with
        jsr ShowDeadPlayer
        jsr StopCarSounds
        jsr StopLaser
        jsr .GetPlayerPosition
        jsr .GetClosestCreature
        lda #CREATURE_DEAD              ;this status will instantly kill the creature = its sprite will be disabled right away 
        sta _creaturelifetable,y                      
        rts

KillCreature:
        jsr .GetLaserPosition
        jsr .GetClosestCreature
        lda #CREATURE_DYING_START
        sta _creaturelifetable,y                ;this status will start dying animation and when over completely kill the creature = disable sprite
        jsr DisarmCreatureSprite
        rts

DISTANCE_X_LIMIT = 32  
DISTANCE_Y_LIMIT = 32

.spritexpos     = ZP2   ;position of centre of creature
.spriteypos     = ZP4
.refxpos        = ZP6   ;reference point, can be player or laserbeam
.refypos        = ZP8
.closestdist    = ZPA
.closestindex   = ZPC   ;index of the closest creature

.GetPlayerPosition:                     ;OUT: .refxpos,  .refypos = player sprite position        
        lda #<PLAYER_XPOS_L
        sta VERA_ADDR_L
        lda #>PLAYER_XPOS_L
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H
        lda VERA_DATA0
        sta .refxpos
        lda VERA_DATA0
        sta .refxpos+1
        lda VERA_DATA0
        sta .refypos
        lda VERA_DATA0
        sta .refypos+1
        +Add16I .refxpos, PLAYERWIDTH/2         ;add half width and height to get middle of player
        +Add16I .refypos, PLAYERHEIGHT/2
        rts

.GetLaserPosition:              ;OUT: .refxpos,  .refypos = second laser sprite position = middle of laser beam        
        lda #<LASER1_XPOS_L
        sta VERA_ADDR_L
        lda #>LASER1_XPOS_L
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H
        lda VERA_DATA0
        sta .refxpos
        lda VERA_DATA0
        sta .refxpos+1
        lda VERA_DATA0
        sta .refypos
        lda VERA_DATA0
        sta .refypos+1         
        rts

.GetClosestCreature:            ;IN: refxpos, refypos (16 bit) - ref position of player or laserbeam
                                ;OUT: .Y = index of creature that are closest to ref position

        ;1 - init
        ldy #0                  ;creature index
        lda #<CREATURE_XPOS_L   ;set read position for first creature
        sta VERA_ADDR_L
        lda #>CREATURE_XPOS_H
        sta VERA_ADDR_M
        lda #$11
        sta VERA_ADDR_H
        lda #DISTANCE_X_LIMIT   ;init distance to compare with
        sta .closestdist
        stz .closestdist+1
        lda #-1
        sta .closestindex

        ;2 - check if creature is alive      
.ClosestCreatureLoop:
        lda _creaturelifetable,y
        cmp #CREATURE_ALIVE
        beq +
        +Add16I VERA_ADDR_L, 8          ;if dead skip to next                           
        jmp .NextClosestCreature

        ;3 - get position for creature sprite
+       lda VERA_DATA0
        sta .spritexpos
        lda VERA_DATA0
        sta .spritexpos+1
        lda VERA_DATA0
        sta .spriteypos
        lda VERA_DATA0
        sta .spriteypos+1

        +Add16I VERA_ADDR_L, 4                  ;add 4 to be ready to read position of next sprite

        lda .spritexpos+1
        cmp #2
        bne +
        jmp .NextClosestCreature                ;if sprite not visible position will be 512, if that is the case skip to next creature
+       lda .spriteypos+1
        cmp #2
        bne +
        jmp .NextClosestCreature

+       +Add16I .spritexpos, CREATURE_HEIGHT/2  ;get position for centre of creature
        +Add16I .spriteypos, CREATURE_WIDTH/2
 
        ;4 - calculate horizontal distance between reference position and creature
        +Sub16 .spritexpos, .refxpos
        +Abs16 .spritexpos                      ;spritexpos now = abs x dist
        lda .spritexpos+1
        bne .NextClosestCreature                ;if abs x dist > 255 skip to next creatur

        ;5 - calculate vertical distance between reference position and creature
        +Sub16 .spriteypos, .refypos
        +Abs16 .spriteypos                      ;spriteypos now = abs y dist
        lda .spriteypos+1
        bne .NextClosestCreature                ;if abs y dist > 255 skip to next creature

        ;6 - compare distance with the currently shortest
        +Add16 .spritexpos, .spriteypos         ;add x and y dist to get a measure of total distance (we skip the pythagorean theorem ...)
        +Cmp16 .spritexpos, .closestdist
        bcs .NextClosestCreature                ;skip to next if distance not shorter than currently shortest

        lda .spritexpos                         ;we have a new candidate for shortest distance
        sta .closestdist
        lda .spritexpos+1
        sta .closestdist+1      
        sty .closestindex

.NextClosestCreature:
        iny
        cpy _creaturecount
        beq + 
        jmp .ClosestCreatureLoop
+       ldy .closestindex
        rts


