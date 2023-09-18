;*** level.asm  ***********************************************************************************

;tile categories
TILECAT_SPACE   = 0
TILECAT_BLOCK   = 1     
TILECAT_WALL    = 2     ;tiles that can be blasted
TILECAT_DEATH   = 3     ;tiles that kills the player
TILECAT_MINER   = 4

;table for mapping tile and category (tiles for creatures will be replaced with a tile of category SPACE)
_tilecategorytable      !byte 1,1,1,1 ; 0- 3 (creatures = block, but unimportant because it is exchanged)
                        !byte 1,1,4,0 ; 4- 7 
                        !byte 0,0,0,0 ; 8-11
                        !byte 0,0,0,0 ;12-15
                        !byte 0,1,1,1 ;16-19
                        !byte 1,1,1,1 ;20-23
                        !byte 1,1,1,1 ;24-27
                        !byte 1,1,1,1 ;28-31
                        !byte 1,1,1,1 ;32-35
                        !byte 3,3,2,2 ;36-39
                        !byte 2,1,1,1 ;40-43
                        !byte 1,1,1,3 ;44-47
                        !byte 0,0,0,0 ;48-51
                        !byte 1,1,3,0 ;52-55
                        !byte 0,1,1,1 ;56-59
                        !byte 1,0,0,0 ;60-63
                        !byte 0,0,0,1 ;64-67
                        !byte 1,1,1,3 ;68-71
                        !byte 0,0,0,0 ;72-75
                        !byte 0,0     ;76-77

LEVEL_COUNT       = 2   ;number of levels in game

_levelstarttable        !byte 2,3        ;start row and col for level 1
                        !byte 3,3        ;level 2

;table for size of levels (0 = 32 tiles, 1 = 64, 2 = 128 and 3 = 256)
_levelsizetable         !byte 0,1       ;level 0 is only used as background when displaying menu, high score table and credits
                        !byte 0,0       ;height and width in VERA tilemap notation 
                        !byte 0,0

_startlevel             !byte 1         ;which level game starts on, default is 1
_level                  !byte 0         ;current level (zero-indexed)
_levelcompleted         !byte 0         ;flag

_levelconvtable         !word 32,64,128,256
_levelheight            !word 0         ;height and width in tiles
_levelwidth             !word 0
_levelxmaxpos           !word 0         ;max x pos for camera
_levelymaxpos           !word 0         ;max y pos for camera
.levelpow2width         !byte 0         ;level width where 2^_levelwidth = width in tiles (used when finding certain tile)

InitLevel:
        stz _levelcompleted
        jsr LoadLevel
        jsr .SetLevelProperties
        rts

GetSavedMinersCount:            ;OUT: .A = number of saved miners (example: game ends on level 5 (not completed), start level is 1 -> 5 - 1 + 0 = 4)
        lda _level              
        sec
        sbc _startlevel
        clc
        adc _levelcompleted
        rts

.SetLevelProperties:
        ;get size of current level
        lda _level
        asl
        tay                     
        lda _levelsizetable,y   ;get rows
        sta ZP0
        lda _levelsizetable+1,y ;get cols
        sta ZP1

        ;set size of current level in tiles
        lda ZP0
        asl                     ;every entry takes 2 bytes
        tay
        lda _levelconvtable,y
        sta _levelheight
        lda _levelconvtable+1,y
        sta _levelheight+1
        lda ZP1
        asl
        tay
        lda _levelconvtable,y
        sta _levelwidth
        lda _levelconvtable+1
        sta _levelwidth+1

        ;set width of current level where 2^x = width of tilemap
        lda ZP1
        clc
        adc #5                  ;convert from VERA notification
        sta .levelpow2width 

        ;set tilemap size (passed in ZP0 and ZP1)
        jsr SetLayer0Size

        ;set limit for camera
        lda _levelheight
        sta ZP0
        lda _levelheight+1
        sta ZP1
        +MultiplyBy16 ZP0
        +Sub16I ZP0, SCREENHEIGHT/2
        lda ZP0
        sta _levelymaxpos
        lda ZP1
        sta _levelymaxpos+1

        lda _levelwidth
        sta ZP0
        lda _levelwidth+1
        sta ZP1
        +MultiplyBy16 ZP0
        +Sub16I ZP0, SCREENWIDTH/2
        lda ZP0
        sta _levelxmaxpos
        lda ZP1
        sta _levelxmaxpos+1
        rts