;*** collision.asm *********************************************************************************

PLAYER_COLLISION_MASK   = %11010000     ;player can collide with miner, lamps and creatures
CREATURE_COLLISION_MASK = %00110000     ;creatures can collide with the player or shots from the player.
LAMP_COLLISION_MASK     = %01000000
LASER_COLLISION_MASK    = %00100000     ;laser can collide with creatures but not with player
MINER_COLLISION_MASK    = %10000000     ;miner can collide with player, when this happens the miner is rescued!

SwapLight:
        jsr .KillLamp                   ;disable collisions with this lamp, it won't affect anything in the future
        lda _darkmode                   ;switch between light and darkness
        bne +
        jsr TurnOffLight
        rts
+       jsr TurnOnLight
        rts

TurnOnLight:
        lda _darkmode
        bne +
        rts
+       +CopyPalettesToVRAM _graphicpalettes, 1, 4      ;Restore 5 palettes (player, creatures, black tiles, tiles)
        stz _darkmode
        rts
 
TurnOffLight:
        lda #<GRAPHICS_PALETTES_ADDR
        sta VERA_ADDR_L
        lda #>GRAPHICS_PALETTES_ADDR           
        sta VERA_ADDR_M
        lda #$11                
        sta VERA_ADDR_H

        ldy #0           
-       lda _graphicpalettes,y
        sta ZP0         ;temp save .A
        lsr             ;transfer high nybble to lower bits
        lsr
        lsr
        lsr
        lsr             ;divide low nybble by 2
        +Countdown      ;subtract 1 if > 0
        asl             ;transfer back low nybble to high
        asl
        asl
        asl 
        sta ZP1         ;temp save high nybble
        lda ZP0         ;restore original value
        and #$0f        ;keep low nybble
        lsr             ;make color darker by dividing color value by 2
        +Countdown      ;subtract 1 if > 0
        ora ZP1         ;combine high and low nybble
        sta VERA_DATA0     
        iny
        cpy #127        ;4 palettes * 16 colors * 2 bytes and finally - 1 to not change lava color = 127             
        bne -
        lda #1
        sta _darkmode
        rts

DISTANCE_X_LIMIT = 32  
DISTANCE_Y_LIMIT = 32

PLAYER_COLLISION = 0
LASER_COLLISION  = 1
LAMP_COLLISION   = 2

.spritexpos     = ZP2   ;position of centre of creature
.spriteypos     = ZP4
.refxpos        = ZP6   ;reference point, can be player or laserbeam
.refypos        = ZP8
.closestdist    = ZPA
.closestindex   = ZPC   ;index of the closest creature
.colltype       = ZPD   ;player or laser colliding

KillPlayerAndCreature:                  ;OUT: .Y = index of creature that player collided with
        jsr AbortExplosion
        jsr .GetPlayerPosition
        lda #PLAYER_COLLISION
        sta .colltype
        jsr .GetClosestCreature
        lda #CREATURE_DEAD              ;this status will instantly kill the creature = its sprite will be disabled right away 
        sta _creaturelifetable,y  
        rts

KillCreature:
        jsr PlayCreatureKilledSound
        jsr .GetLaserPosition
        lda #LASER_COLLISION
        sta .colltype
        jsr .GetClosestCreature
        lda #CREATURE_DYING_START
        sta _creaturelifetable,y        ;this status will start dying animation and when over completely kill the creature = disable sprite
        jsr DisarmCreatureSprite
        rts

.KillLamp:                              ;lamps are treated as creatures, they die/goes dark when player hits them
        jsr .GetPlayerPosition
        lda #LAMP_COLLISION
        sta .colltype
        jsr .GetClosestCreature
        jsr DisarmCreatureSprite        ;set collision mask to 0, this lamp won't affect anything anymore
        rts

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

+       jsr .DecideIfSkipCreature
        beq +                           
        ; lda _creaturetypetable,y
        ; cmp #TYPE_LAMP
        ; bne +
        +Add16I VERA_ADDR_L, 8          ;skip if .A = 1                           
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
        
        lda .colltype
        cmp #PLAYER_COLLISION
        beq +
        cmp #LAMP_COLLISION
        beq +
        lda .spriteypos                         
        cmp #9                                  ;if laser - creature collision, allow max 9 pixels vertical distance
        bcs .NextClosestCreature

        ;6 - compare distance with the currently shortest
+       +Add16 .spritexpos, .spriteypos         ;add x and y dist to get a measure of total distance (we skip the pythagorean theorem ...)
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

.DecideIfSkipCreature:
        lda _creaturetypetable,y
        cmp #TYPE_LAMP
        bne ++
        lda .colltype
        cmp #LAMP_COLLISION
        bne +
        lda #0                  ;type lamp and we are looking for lamps, do not skip
        rts
+       lda #1                  ;type lamp but we are looking for creatures, skip
        rts
++      lda .colltype
        cmp #LAMP_COLLISION
        bne +
        lda #1                  ;type creature but we are looking for lamps, skip
        rts
+       lda #0                  ;type creature and we are looking for creatures,do not skip
        rts