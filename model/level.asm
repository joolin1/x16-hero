;*** level.asm  ***********************************************************************************

;tile categories
TILECAT_SPACE   = 0
TILECAT_BLOCK   = 1     
TILECAT_WALL    = 2     ;tiles that can be blasted
TILECAT_DEATH   = 3     ;tiles that kills the player
TILECAT_MINER   = 4

;table for mapping tile (max 128!) and category (tiles for creatures will be replaced with a tile of category SPACE)
_tilecategorytable      !byte 1,1,1,1 ; 0- 3 (creatures = block, but unimportant because it is exchanged)
                        !byte 1,1,1,4 ; 4- 7 
                        !byte 0,0,0,0 ; 8-11
                        !byte 0,0,0,0 ;12-15
                        !byte 0,0,1,1 ;16-19
                        !byte 1,1,1,1 ;20-23
                        !byte 1,1,1,1 ;24-27
                        !byte 1,1,1,1 ;28-31
                        !byte 1,1,1,1 ;32-35
                        !byte 1,3,3,2 ;36-39
                        !byte 2,2,1,1 ;40-43
                        !byte 1,1,1,1 ;44-47
                        !byte 1,1,1,1 ;48-51
                        !byte 1,1,3,0 ;52-55
                        !byte 0,0,0,2 ;56-59
                        !byte 2,3,0,0 ;60-63
                        !byte 1,1,1,1 ;64-67
                        !byte 0,0,0,0 ;68-71
                        !byte 0,0,1,1 ;72-75
                        !byte 1,1,3,0 ;76-79
                        !byte 0,0,0,0 ;80-83
                        !byte 0,1,1,1 ;84-87
                        !byte 1       ;88

;*** LEVEL DATA - CHANGE WHEN LEVELS CHANGE! ******************************************************

LEVEL_COUNT             = 10            ;number of levels in game
_startlevel             !byte 1         ;which level game starts on, default is 1       

;is set when level has been loaded and tilemap is iterated to find creatures, miner and player
_levelstartrow          !byte 0         ;where player starts
_levelstartcol          !byte 0         ;where player starts
_levelstartdirection    !byte 0         ;which direction player has, 0 = right, anything else = left

;table for size of levels (0 = 32 tiles, 1 = 64, 2 = 128 and 3 = 256)
_levelsizetable         !byte 0,1       ;level 0 is only used as background when displaying menu, high score table and credits
                        !byte 0,0       ;height and width in VERA tilemap notation 
                        !byte 0,0       ;2
                        !byte 0,0       ;3
                        !byte 0,0       ;4
                        !byte 0,0       ;5
                        !byte 0,0       ;6
                        !byte 0,0       ;7
                        !byte 0,0       ;8
                        !byte 0,0       ;9
                        !byte 0,0       ;10                       

;table deciding if a level should be dark from the beginning
_leveldarktable         !byte 0                         ;level 0 consists of title screens, not dark of course
                        !byte 0                         ;1
                        !byte 0                         ;2
                        !byte 0                         ;3
                        !byte 0                         ;4
                        !byte 0                         ;5
                        !byte 0                         ;6
                        !byte 0                         ;7
                        !byte LEVEL_REALLY_DARK         ;8
                        !byte 0                         ;9
                        !byte LEVEL_REALLY_DARK         ;10

;**************************************************************************************************

LEVEL_LIMITED_DARK  = 1 ;current floor light, floors below dark         
LEVEL_MODERATE_DARK = 2 ;light around player quite far
LEVEL_REALLY_DARK   = 3 ;light around player just the closes vicinity

LEVEL_LIMITED_DARK_COLS  = 32   ;how far the light will reach
LEVEL_LIMITED_DARK_ROWs  = 7
LEVEL_MODERATE_DARK_DIST = 9
LEVEL_REALLY_DARK_DIST   = 7;5

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
        jsr .BlackOutLevel
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

        ;set how dark level will be
        ldy _level
        lda _leveldarktable,y
        cmp #LEVEL_LIMITED_DARK
        bne +
        lda #LEVEL_LIMITED_DARK_COLS
        sta .light_cols_length
        lda #LEVEL_LIMITED_DARK_ROWs
        sta .light_rows_length
        rts
+       cmp #LEVEL_MODERATE_DARK
        bne +
        lda #LEVEL_MODERATE_DARK_DIST
        sta .light_cols_length
        sta .light_rows_length
        rts
+       cmp #LEVEL_REALLY_DARK
        bne +
        lda #LEVEL_REALLY_DARK_DIST
        sta .light_cols_length
        sta .light_rows_length
        rts
+       stz .light_cols_length
        stz .light_rows_length
        rts

GetSavedMinersCount:            ;OUT: .A = number of saved miners (example: game ends on level 5 (not completed), start level is 1 -> 5 - 1 + 0 = 4)
        lda _level              
        sec
        sbc _startlevel
        clc
        adc _levelcompleted
        rts

.BlackOutLevel:
        ldy _level
        lda _leveldarktable,y
        bne +
        rts
+       stz VERA_CTRL
        lda #<(L0_MAP_ADDR+1)   ;set first pointer to first tile, second byte that contains the palette index
        sta VERA_ADDR_L
        lda #>(L0_MAP_ADDR+1)
        sta VERA_ADDR_M
        lda #$20                ;step 2 bytes for each read/write because tile info = 2 bytes
        sta VERA_ADDR_H

        lda #1
        sta VERA_CTRL
        lda #<(L0_MAP_ADDR+1)   ;set second pointer to first tile, second byte that contains the palette index
        sta VERA_ADDR_L
        lda #>(L0_MAP_ADDR+1)
        sta VERA_ADDR_M
        lda #$20                
        sta VERA_ADDR_H
        stz VERA_CTRL

        ldy _levelheight       
--      ldx _levelwidth
-       lda VERA_DATA0
        and #$0f                                                ;clear higher bits
        ora #(BLACK_TILE_PALETTE_INDEX<<4)       ;set new palette index and keep the lower bits unchanged
        sta VERA_DATA1
        dex
        bne -
        dey
        bne --
        rts
           
.light_row = ZP4        
.light_col = ZP6
.light_rows_count = ZP8
.light_cols_count = ZP9
.light_rows_length      !byte 0
.light_cols_length      !byte 0

LightUpLevel:
        ldy _level
        lda _leveldarktable,y
        bne +
        rts
+       lda .light_rows_length          ;start to assume that we are as far from level borders that we can light all tiles
        bne +                           ;if length = 0 this level is not dark
        rts
+       sta .light_rows_count
        lda .light_cols_length
        sta .light_cols_count

        ;set start row and start col
        +Copy16 _ypos_lo, .light_row
        +Copy16 _xpos_lo, .light_col        
        +DivideBy16 .light_row                  ;get row index
        +DivideBy16 .light_col                  ;get col index
        lda .light_rows_length
        lsr
        +Sub16 .light_row                       ;start x rows above player
        lda .light_cols_length
        lsr
        +Sub16 .light_col                       ;start x cols to the left of player

        ;make sure that start and end row are not outside tilemap boundaries
        lda .light_row
        bpl +
        clc                             ;if start row < 0
        adc .light_rows_count           ;then reduce length (eg row = -2 then take length + (-2) => length -2)
        sta .light_rows_count
        stz .light_row                  ;and start att row 0

+       lda .light_row                             
        clc
        adc .light_rows_count
        sec 
        sbc _levelheight
        bmi +                           
        sta ZPA
        lda .light_rows_count           ;if end row > (level height - 1)
        sec
        sbc ZPA                         ;then reduce length (eg row + length = 33 and level height = 32 then take length - (33-32) => length - 1)
        sta .light_rows_count

        ;make sure that start and end col are not outside tilemap boundaries
+       lda .light_col
        bpl +
        clc                             
        adc .light_cols_count
        sta .light_cols_count           
        stz .light_col                  

+       lda .light_col                             
        clc
        adc .light_cols_count
        sec 
        sbc _levelwidth
        bmi +                           
        sta ZPA
        lda .light_cols_count           
        sec
        sbc ZPA                         
        sta .light_cols_count

+       lda #<L0_MAP_ADDR
        sta ZP2
        lda #>L0_MAP_ADDR
        sta ZP3
        +GetElementIn16BitArray ZP2, .levelpow2width, .light_row, .light_col ;parameters: addr of array, width in 2^x notification, row and col. out: addr in ZP0,ZP1
        lda #$20                ;auto increment by 2 because tile info is 2 bytes
        adc #$0                 ;transfer carry flag to .A by adding WITH CARRY
        sta VERA_ADDR_H         ;set both data ports to the same start tile
        ldx #1
        stx VERA_CTRL
        sta VERA_ADDR_H
        +Inc16 ZP0              ;add 1 to get address to second byte of tile that contains the palette index
        ldx ZP0
        stx VERA_ADDR_L
        ldx ZP1
        stx VERA_ADDR_M
        stz VERA_CTRL
        ldx ZP0
        stx VERA_ADDR_L
        ldx ZP1
        stx VERA_ADDR_M

        lda _levelwidth                 ;calculate row offset in tilemap/level
        sec
        sbc .light_cols_count
        asl                             ;each tile uses 2 bytes
        sta .row_addr_offset

        ldy .light_rows_count
--      ldx .light_cols_count
-       lda VERA_DATA0
        and #$0f                        ;clear higher bits
        ora #(TILE_PALETTE_INDEX<<4)    ;set new palette index and keep the lower bits unchanged
        sta VERA_DATA1
        dex
        bne -
        lda .row_addr_offset
        +Add24 VERA_ADDR_L      ;add address offset to get address to first tile on next row
        ldx #1
        stx VERA_CTRL
        lda .row_addr_offset
        +Add24 VERA_ADDR_L
        stz VERA_CTRL
        dey
        bne --
        rts

.row_addr_offset        !byte 0