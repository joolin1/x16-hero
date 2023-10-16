;*** player.asm ************************************************************************************

LIFE_COUNT    = 5   ;number of lives for player

MIN_FLYINGSPEED   = 1
MAX_FLYINGSPEED   = 2
FLYINGTIME        = 45
FLYINGSPEED_DELAY = 45
TAKEOFF_DELAY     = 0;10

MIN_WALKINGSPEED  = 1
MAX_WALKINGSPEED  = 2
WALKINGSPEED_DELAY = 45 

MIN_FALLINGSPEED   = 1
MAX_FALLINGSPEED   = 16
FALLINGSPEED_DELAY = 8
GRAVITY            = 1

;player properties
_flyingspeed    !word 0         ;16 bit value for easier math
_flyingtime     !byte 0         ;how long player will continue to fly without boosting
_walkingspeed   !word 0         ;16 bit value for easier math
_fallingspeed   !word 0         ;16 bit value for easier math
_isfalling      !byte 0         ;boolean, whether player is falling or not
_istakingoff    !byte 0         ;boolean, whether player is taking off (= not yet flying)
_isflying       !byte 0         ;boolean, whether player is flying or walking
_ismoving       !byte 0         ;boolean, whether player is moving or standing still
_ismovingleft   !byte 0         ;boolean, whether player is pointing left or right

_lives          !byte 0  

_xpos_lo        !byte 0         ;current position in game world 
_xpos_hi        !byte 0
_ypos_lo        !byte 0
_ypos_hi        !byte 0
_last_xpos_lo   !byte 0         ;former position in game world (used for moving player back after collision with lethal tile)
_last_xpos_hi   !byte 0
_last_ypos_lo   !byte 0
_last_ypos_hi   !byte 0


_currenttilebelow       !byte 0
_lasttilebelow          !byte 0

_laserpossible          !byte 0 ;0 = tile is blocking laser, 1 = laser can fire one tile, 2 = laser can fire two tiles

;definition of collision box (for example: add Q1_X and Q1_Y to player's position to get top right corner of box)
COLLBOX_Q1_X =  5;6
COLLBOX_Q2_X =  -6;-7
COLLBOX_Q3_X =  -6;-7
COLLBOX_Q4_X =  5;6

COLLBOX_Q1_Y = -13
COLLBOX_Q2_Y = -13
COLLBOX_Q3_Y =  9
COLLBOX_Q4_Y =  9

TILE_GROUND_LEVEL = 5;6   ;adjustment of where to place player vertically when landing

;collision box
_collboxq1_x    !word 0
_collboxq1_y    !word 0
_collboxq2_x    !word 0
_collboxq2_y    !word 0
_collboxq3_x    !word 0
_collboxq3_y    !word 0
_collboxq4_x    !word 0
_collboxq4_y    !word 0

InitPlayer:
        ;set start position
        lda _level
        dec
        asl
        tay
        lda _levelstarttable,y
        sta _ypos_lo
        stz _ypos_hi
        iny
        lda _levelstarttable,y
        sta _xpos_lo
        stz _xpos_hi
        +MultiplyBy16 _ypos_lo
        +MultiplyBy16 _xpos_lo
        +Add16I _ypos_lo,8
        +Add16I _xpos_lo,8
        lda #-1
        sta _lasttilebelow

        ;set various properties
        lda #FLYINGTIME
        sta _flyingtime
        lda #MIN_FLYINGSPEED
        sta _flyingspeed
        lda #MIN_WALKINGSPEED
        sta _walkingspeed
        lda #MIN_FALLINGSPEED
        sta _fallingspeed
        lda #1                  ;start position is flying turning right
        sta _isflying
        stz _ismovingleft
        rts           

MovePlayerBack:
        ;move player back after being killed by lava contact to avoid being killed immediately again
        lda _last_xpos_lo       
        sta _xpos_lo
        lda _last_xpos_hi
        sta _xpos_hi
        lda _last_ypos_lo
        sta _ypos_lo
        lda _last_ypos_hi
        sta _ypos_hi

        lda _isfalling
        bne +
        lda _isflying
        bne +
        rts             

        ;if player has come from above by falling or flying down on the lava, then let him fly above the lava to avoid being killed immediately again
+       stz _isfalling
        lda #1                          ;make him fly 
        sta _isflying                
        lda #120                        ;give him longer time before he starts to fall
        sta _flyingtime
        lda #MIN_FLYINGSPEED
        sta _flyingspeed
        lda #MIN_WALKINGSPEED
        sta _walkingspeed
        lda #MIN_FALLINGSPEED
        sta _fallingspeed

        +Sub16I _ypos_lo, 1     ;player needs to be moved up an extra pixel when coming from above
        rts

PlayerTick:                     ;advance one frame
        lda _xpos_lo            ;save current position, soon to be former position
        sta _last_xpos_lo
        lda _xpos_hi
        sta _last_xpos_hi
        lda _ypos_lo
        sta _last_ypos_lo
        lda _ypos_hi
        sta _last_ypos_hi

        jsr .SetCollisionBox
        jsr .UpdatePlayerPosition
        jsr CheckLaserPossible
        jsr .UpdateLaserAndExplosives
        jsr CheckLandingAndFalling
        lda _currenttilebelow
        sta _lasttilebelow
        jsr UpdateExplosive
        rts

.SetCollisionBox:
        lda #<COLLBOX_Q1_X
        sta _collboxq1_x
        lda #>COLLBOX_Q1_X
        sta _collboxq1_x+1
        lda #<COLLBOX_Q1_Y
        sta _collboxq1_y
        lda #>COLLBOX_Q1_Y
        sta _collboxq1_y+1

        lda #<COLLBOX_Q2_X
        sta _collboxq2_x
        lda #>COLLBOX_Q2_X
        sta _collboxq2_x+1
        lda #<COLLBOX_Q2_Y
        sta _collboxq2_y
        lda #>COLLBOX_Q2_Y
        sta _collboxq2_y+1

        lda #<COLLBOX_Q3_X
        sta _collboxq3_x
        lda #>COLLBOX_Q3_X
        sta _collboxq3_x+1
        lda #<COLLBOX_Q3_Y
        sta _collboxq3_y
        lda #>COLLBOX_Q3_Y
        sta _collboxq3_y+1

        lda #<COLLBOX_Q4_X
        sta _collboxq4_x
        lda #>COLLBOX_Q4_X
        sta _collboxq4_x+1
        lda #<COLLBOX_Q4_Y
        sta _collboxq4_y
        lda #>COLLBOX_Q4_Y
        sta _collboxq4_y+1

        +Add16 _collboxq1_x, _xpos_lo
        +Add16 _collboxq1_y, _ypos_lo
        +Add16 _collboxq2_x, _xpos_lo
        +Add16 _collboxq2_y, _ypos_lo
        +Add16 _collboxq3_x, _xpos_lo
        +Add16 _collboxq3_y, _ypos_lo
        +Add16 _collboxq4_x, _xpos_lo
        +Add16 _collboxq4_y, _ypos_lo        
        rts

.UpdatePlayerPosition:
        jsr .FallDown                   ;fall down if falling
        jsr .CountDownFlyingTime        ;player will start to lose height a short time after boosting by pressing up

        lda #1
        sta _ismoving           ;assume that player is moving, if not this will be false at the end of the routine

        lda _joy0        
        bit #JOY_UP             ;UP?
        bne +
        jsr .MoveUp
        jsr .IncreaseFlyingSpeed
        lda #FLYINGTIME
        sta _flyingtime          ;maximize remaining flying time when boosting up
        rts

+       stz _istakingoff        ;interrupt take off if player is not pressing up
        lda _joy0        
        bit #JOY_DOWN           ;DOWN?
        bne +
        jsr .MoveDown
        rts

+       lda _joy0
        and #JOY_LEFT+JOY_RIGHT
        beq .SetNotMoving       ;Pressing both left and right will be ignored

+       lda _joy0
        bit #JOY_LEFT           ;LEFT?
        bne +
        jsr .MoveLeft
        jsr .IncreaseFlyingSpeed
        jsr .IncreaseWalkingSpeed
        rts

+       lda _joy0        
        bit #JOY_RIGHT          ;RIGHT?
        bne .SetNotMoving
        jsr .MoveRight
        jsr .IncreaseFlyingSpeed
        jsr .IncreaseWalkingSpeed
        rts

.UpdateLaserAndExplosives:
        lda _joy0
        bit #JOY_BUTTON_A
        bne +
        jsr FireLaser
        bra ++
+       jsr ReloadLaser      
++      lda _joy0
        bit #JOY_BUTTON_B
        bne +
        lda _explosivemode
        bne +
        lda _isflying
        bne +
        lda _isfalling
        bne +
        lda #EXPLOSIVE_PLACE
        sta _explosivemode
+       rts 

.SetNotMoving:
        lda #MIN_FLYINGSPEED
        sta _flyingspeed
        stz .flyingspeeddelay
        lda #MIN_WALKINGSPEED
        sta _walkingspeed
        stz .walkingspeeddelay
        stz _ismoving
        rts

KillPlayerLava:
        jsr ShowDeadPlayer
        jsr StopPlayerSounds
        jsr PlayPlayerKilledSound
        jsr AbortExplosion 
        lda #ST_DEATH_LAVA
        sta _gamestatus
        rts

!macro BreakIfTileIsBlocking {
        jsr CheckTileStatus
        cmp #TILECAT_DEATH
        bne +
        jsr KillPlayerLava
        rts
+       cmp #TILECAT_BLOCK
        bne +
        rts
+       cmp #TILECAT_WALL
        bne +
        rts      
+
}

.MoveUp:
        stz _ismoving
        lda _isflying
        bne ++                          ;if flying, just continue to fly
        lda _istakingoff                ;if taking off, continue to take off
        bne +
        lda #1                          ;if on ground, start take off
        sta _istakingoff
        stz .takeoffdelay
+       lda .takeoffdelay               ;take off is in reality a delay before flying
        cmp #TAKEOFF_DELAY
        beq +
        inc .takeoffdelay
        rts
+       lda #1                          ;start flying
        sta _isflying
        stz _istakingoff

++      stz _isfalling

        ;check top left corner of collision box
        +Copy16 _collboxq2_y, ZP4
        +Copy16 _collboxq2_x, ZP6
        jsr GetCurrentSpeed  ;returns speed in .A     
        +Sub16 ZP4           ;ZP4-.A          
        ;+BreakIfTileIsBlocking
        jsr CheckTileStatus
        sta .upperleftstatus
        cmp #TILECAT_DEATH
        bne +
        jsr KillPlayerLava
        rts

        ;check top right corner of collision box
+       +Copy16 _collboxq1_y, ZP4
        +Copy16 _collboxq1_x, ZP6
        jsr GetCurrentSpeed  ;returns speed in .A     
        +Sub16 ZP4           ;ZP4-.A          
        ;+BreakIfTileIsBlocking
        jsr CheckTileStatus
        sta .upperrightstatus
        cmp #TILECAT_DEATH
        bne +
        jsr KillPlayerLava
        rts

+       +Cmp16I _ypos_lo, 16            ;block player from flying too far up
        bcs +
        rts

        ;decide what to do depending on status of upper corners
+       lda .upperleftstatus
        cmp #TILECAT_SPACE
        bne +
        lda .upperrightstatus
        cmp #TILECAT_SPACE
        bne ++
        +Sub16 _ypos_lo, _flyingspeed   ;both corners are open, move up
        rts                             
+       lda .upperrightstatus           ;left is blocked, what about right?
        cmp #TILECAT_SPACE
        bne +
        +Add16I _xpos_lo, 1             ;left is blocked, right open, move player closer to the opening to the right
+       rts
++      +Sub16I _xpos_lo, 1             ;left is open, right is blocked, move player closer to the opening to the left
        rts

.takeoffdelay   !byte 0
.upperleftstatus  !byte 0
.upperrightstatus  !byte 0

.MoveDown:
        lda _isflying
        bne +
        stz _ismoving   ;moving down is only possible if flying
        rts

        ;check bottom left corner of collision box
+       +Copy16 _collboxq3_y, ZP4
        +Copy16 _collboxq3_x, ZP6
        +Add16 ZP4, _flyingspeed          
        +BreakIfTileIsBlocking

        ;check bottom right corner of collision box
        +Copy16 _collboxq4_y, ZP4
        +Copy16 _collboxq4_x, ZP6
        +Add16 ZP4, _flyingspeed          
        +BreakIfTileIsBlocking
+       +Add16 _ypos_lo, _flyingspeed
        rts

.MoveLeft:
        lda #1
        sta _ismovingleft
        stz _ismoving

        ;check top left corner of collision box
        +Copy16 _collboxq2_y, ZP4
        +Copy16 _collboxq2_x, ZP6
        jsr GetCurrentSpeed  ;returns speed in .A     
        +Sub16 ZP6           ;ZP6-.A          
        +BreakIfTileIsBlocking

        ;check middle left side of collision box
        +Copy16 _ypos_lo    , ZP4
        +Copy16 _collboxq3_x, ZP6
        jsr GetCurrentSpeed  ;returns speed in .A     
        +Sub16 ZP6           ;ZP6-.A          
        +BreakIfTileIsBlocking

        ;check bottom left corner of collision box
        +Copy16 _collboxq3_y, ZP4
        +Copy16 _collboxq3_x, ZP6
        jsr GetCurrentSpeed  ;returns speed in .A     
        +Sub16 ZP6           ;ZP6-.A          
        +BreakIfTileIsBlocking

        ;no problem, move player
+       jsr GetCurrentSpeed
        +Sub16 _xpos_lo
        lda #1 
        sta _ismoving
        rts

.MoveRight:
        stz _ismovingleft
        stz _ismoving
        
        ;check top right corner of collision box
        +Copy16 _collboxq1_y, ZP4
        +Copy16 _collboxq1_x, ZP6
        jsr GetCurrentSpeed  ;speed -> .A     
        +Add16 ZP6           ;ZP6-.A          
        +BreakIfTileIsBlocking

        ;check middle right side of collision box
        +Copy16 _ypos_lo    , ZP4
        +Copy16 _collboxq3_x, ZP6
        jsr GetCurrentSpeed  ;returns speed in .A     
        +Add16 ZP6           ;ZP6-.A          
        +BreakIfTileIsBlocking

        ;check bottom right corner of collision box
        +Copy16 _collboxq4_y, ZP4
        +Copy16 _collboxq4_x, ZP6
        jsr GetCurrentSpeed  ;speed -> .A     
        +Add16 ZP6           ;ZP6-.A          
        +BreakIfTileIsBlocking

        ;no problem, move player
+       jsr GetCurrentSpeed
        +Add16 _xpos_lo
        lda #1
        sta _ismoving 
        rts

.FallDown:
        lda _isfalling
        beq +
        jsr .IncreaseFallingSpeed
        +Add16 _ypos_lo, _fallingspeed
+       rts

CheckTileStatus:                        ;IN: ZP4, ZP5 = y coordinate, ZP6, ZP7 = x coordinate
        +DivideBy16 ZP4
        +DivideBy16 ZP6
        lda #<L0_MAP_ADDR
        sta ZP2
        lda #>L0_MAP_ADDR
        sta ZP3
        +GetElementIn16BitArray ZP2, .levelpow2width, ZP4, ZP6  ;parameters: addr of array, width in 2^x notification, row and col
        +VPeek ZP0                      ;if carry is set, read from bank 1
        tay
        lda _tilecategorytable,y        ;read tile category
        rts                             ;OUT: .A = tile

CheckLaserPossible:
        lda _ismovingleft
        bne +
        lda #16
        sta .tileoffset
        stz .tileoffset+1
        bra ++
+       lda #-16
        sta .tileoffset
        lda #-1
        sta .tileoffset+1

        ;check tile beside player
++      +Copy16 _ypos_lo, ZP4
        +Copy16 _xpos_lo, ZP6
        +Sub16I ZP4, 8                 
        +Add16 ZP6, .tileoffset
        jsr CheckTileStatus             
        cmp #TILECAT_BLOCK
        beq +
        cmp #TILECAT_WALL
        beq +
        cmp #TILECAT_DEATH
        beq +
        lda #1
        sta _laserpossible
        bra ++
+       stz _laserpossible
        rts

        ;check the tile after that beside player
++      +Copy16 _ypos_lo, ZP4
        +Copy16 _xpos_lo, ZP6
        +Sub16I ZP4, 8
        +Add16 ZP6, .tileoffset
        +Add16 ZP6, .tileoffset
        jsr CheckTileStatus
        cmp #TILECAT_BLOCK
        beq +
        cmp #TILECAT_WALL
        beq +
        cmp #TILECAT_DEATH
        beq +
        inc _laserpossible
+       rts

.tileoffset     !word 0

CheckLandingAndFalling:
        +Copy16 _ypos_lo, ZP4
        +Copy16 _xpos_lo, ZP6
        +Add16I ZP4, 16 - 4 - 1  ;tile height - padding - 1 to see if player 1 above ground or more                
        jsr CheckTileStatus
        sta _currenttilebelow     

        ;handle if tile below is lava
        cmp #TILECAT_DEATH
        bne +
        jsr KillPlayerLava
        rts

        ;handle if tile below is space
+       cmp #TILECAT_SPACE
        beq +
        cmp #TILECAT_MINER
        beq +
        bra ++
+       jsr KeepClearOfWalls
        lda _isflying
        bne +                   ;if space below and flying, do nothing
        lda #1
        sta _isfalling          ;if space below and walking, start falling
+       rts

        ;handle if tile below is a block
++      cmp #TILECAT_BLOCK
        beq +
        cmp #TILECAT_WALL
        beq +
        rts
+       lda _isflying
        bne +
        lda _isfalling
        bne +
        rts                     ;if block below and walking, do nothing        
+       lda _lasttilebelow
        cmp #TILECAT_SPACE
        beq +                   ;if block below but player not coming from above, do nothing
        rts

        ;land player if flying or falling, coming from above and tile below is block
+       lda _ypos_lo
        and #$f0
        ora #TILE_GROUND_LEVEL    ;position player att ground level
        sta _ypos_lo
        lda #MIN_FLYINGSPEED
        sta _flyingspeed
        lda #MIN_FALLINGSPEED
        sta _fallingspeed
        lda #MIN_WALKINGSPEED
        sta _walkingspeed
        stz _isfalling
        stz _isflying
        stz _ismoving
        rts

KeepClearOfWalls:                       ;when falling keep clear of walls to the left and right
        ;check bottom left corner of collision box
+       +Copy16 _collboxq3_y, ZP4
        +Copy16 _collboxq3_x, ZP6
        ;+Add16I ZP4, 16-4          
        jsr CheckTileStatus
        cmp #TILECAT_BLOCK
        bne +   
        +Inc16 _xpos_lo                  ;if left bottom corner of collision box is blocked move player right
        rts
+       cmp #TILECAT_DEATH
        bne +
        ;+Add16I _last_xpos_lo,8            ;move back a bit extra to not die immediately again
        jsr KillPlayerLava
        rts
        ;check bottom right corner of collision box
+       +Copy16 _collboxq4_y, ZP4
        +Copy16 _collboxq4_x, ZP6
        jsr CheckTileStatus
        cmp #TILECAT_BLOCK              ;if right bottom corner of collision box is blocked move player left
        bne +
        +Dec16 _xpos_lo
        rts
+       cmp #TILECAT_DEATH
        bne +
        ;+Sub16I _last_xpos_lo,8            ;move back a bit extra to not die immediately again
        jsr KillPlayerLava                
+       rts

.IncreaseFlyingSpeed:
        lda _isflying
        beq +
        +CheckTimer .flyingspeeddelay, FLYINGSPEED_DELAY
        beq +
        +IncToLimit _flyingspeed, MAX_FLYINGSPEED
+       rts

.flyingspeeddelay       !byte 0

.CountDownFlyingTime:
        lda _isflying
        beq +      
        +DecToZero _flyingtime
        bne +
        lda #MIN_FLYINGSPEED
        sta _flyingspeed
        +Add16 _ypos_lo, _flyingspeed
+       rts

GetCurrentSpeed:               ;OUT: .A = current speed
        lda _isflying
        bne +
        lda _walkingspeed
        rts
+       lda _flyingspeed
        rts

.IncreaseWalkingSpeed:
        +CheckTimer .walkingspeeddelay, WALKINGSPEED_DELAY
        beq +
        +IncToLimit _walkingspeed, MAX_WALKINGSPEED
+       rts

.walkingspeeddelay     !byte 0

.IncreaseFallingSpeed:
        +CheckTimer .fallingspeeddelay, FALLINGSPEED_DELAY
        beq +
        +IncToLimit _fallingspeed, MAX_FALLINGSPEED
+       rts

.fallingspeeddelay     !byte 0