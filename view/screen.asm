;*** Set up screen and sprites ************************************************************************

SCREENWIDTH = 320
SCREENHEIGHT = 240
TILEWIDTH = 16
TILEHEIGHT = 16

;tile categories
TILECAT_SPACE            = 0
TILECAT_BLOCK            = 1
TILECAT_WALL             = 2
TILECAT_FIRST_CREATURE   = 3        ;(alias to next category)
TILECAT_SPIDER           = 3
TILECAT_CLAW             = 4
TILECAT_ALIEN            = 5
TILECAT_BAT              = 6
TILECAT_LAMP             = 7
TILECAT_TRAPPED_MINER    = 8
TILECAT_OBSTACLE         = 9

;tiles
TILE_SPACE = 0  ;used for replacing sprite tiles and blasted walls

;table for mapping tile and category
_tilecategorytable      !byte  0, 1, 1, 1, 1, 1, 1, 1
                        !byte  1, 1, 2, 2, 2, 3, 4, 5
                        !byte  6, 7, 8, 1

InitScreenAndSprites:
        jsr DisableLayers       ;Disable layers while setting up start screen

        stz VERA_CTRL           ;R-----DA (R=RESET, D=DCSEL, A=ADDRSEL)

        ;Display (DCSEL=0)
        lda DC_VIDEO
        ora #64
        sta DC_VIDEO            ;enable sprites
        lda #64
        sta DC_HSCALE           ;set horizontal and vertical scale to 2:1
        sta DC_VSCALE

        ;layer 0 - graphics layer
        lda #L0_MAP_ADDR>>9             ;set map base address
        sta L0_MAPBASE
        lda #TILES_ADDR>>9              ;set tile address and tile size to 16x16
        ora #%00000011
        sta L0_TILEBASE

        ;layer 1 - text layer
        lda L1_MAPBASE
        sta .original_l1_mapbase
        lda #0                          ;WARNING hard coded address, should be L1_MAP_ADDR>>9
        sta L1_MAPBASE                  ;relocate text layer
        lda #NEW_CHAR_ADDR>>9           ;set tile (char address) to new location and tile size to 8x8
        sta L1_TILEBASE

        +CopyPalettesToVRAM _palettes, 0, 4
        rts

SetLayer0Size:                          ;IN: ZP0 = number or rows, ZP1 = number of cols (0 = 32 tiles, 1 = 64, 2 = 128, 3 = 256)
        lda ZP0
        asl
        asl
        asl
        asl
        asl
        asl
        sta ZP0
        lda ZP1
        asl
        asl
        asl
        asl
        sta ZP1
        lda #2                          ;color depth 4bpp
        ora ZP0                         ;add number of tilemap rows
        ora ZP1                         ;add number of tilemap cols
        sta L0_CONFIG 
        rts

ClearTextLayer:				
	lda #<L1_MAP_ADDR
        sta VERA_ADDR_L
        lda #>L1_MAP_ADDR
	clc
	adc #30
	sta VERA_ADDR_M
	lda #$10			;increment 1
	sta VERA_ADDR_H
	lda #S_SPACE
	ldy #$01			;bg = black (transparent), fg = white
--	ldx #41                         ;clear one extra col in case layer is slightly scrolled
-	sta VERA_DATA0			;print space						
	sty VERA_DATA0			;set color
	dex
	bne -
	stz VERA_ADDR_L
	dec VERA_ADDR_M
	bpl --
        lda #0                          ;reset scroll offset
        sta L1_HSCROLL_L
        sta L1_VSCROLL_L
        stz L1_HSCROLL_H
        stz L1_VSCROLL_H
	rts

RestoreScreenAndSprites:        ;Restore screen and sprites when user ends game
        
        stz VERA_CTRL           ;R-----DA (R=RESET, D=DCSEL, A=ADDRSEL)

        ;Display (DCSEL=0)
        lda DC_VIDEO
        and #%10101111          
        sta DC_VIDEO            ;disable sprites and layer 0
        
        lda #128
        sta DC_HSCALE           ;set horizontal scale to 1:1
        sta DC_VSCALE           ;set vertical scale to 1:1

        +CopyPalettesToVRAM _originalpalette, 0, 1

        lda #%01100000
        sta L1_CONFIG           ;enable layer 1 in 16 color text mode 
        lda .original_l1_mapbase
        sta L1_MAPBASE  
        lda #CHAR_ADDR>>9       ;set tile (char address) to new location and tile size to 8x8
        sta L1_TILEBASE

        lda #$8e       
        jsr BSOUT               ;trigger kernal to upload original character set from ROM to VRAM

        lda #147
        jsr BSOUT               ;clear screen

-       jsr GETIN               ;empty keyboard buffer
        cmp #0
        bne -
        rts

EnableLayers:
        jsr EnableLayer0
        jsr EnableLayer1
        rts

DisableLayers:
        jsr DisableLayer0
        jsr DisableLayer1
        rts

EnableLayer0:
        lda DC_VIDEO
        ora #16
        sta DC_VIDEO
        rts

EnableLayer1:
        lda DC_VIDEO
        ora #32
        sta DC_VIDEO
        rts

DisableLayer0:
        lda DC_VIDEO
        and #255-16
        sta DC_VIDEO
        rts

DisableLayer1:
        lda DC_VIDEO
        and #255-32
        sta DC_VIDEO
        rts

.original_l1_mapbase    !byte 0

_originalpalette:
        !word $0000, $0fff, $0800, $0afe, $0c4c, $00c5, $000a, $0ee7, $0d85, $0640, $0f77, $0333, $0777, $0af6, $008f, $0bbb    ;original colors, used for restoring colors when quitting game

_palettes:                                       
        !word $0000, $0fff, $0800, $0afe, $0c4c, $0080, $005f, $0ee7, $0d85, $0640, $0f77, $0000, $0777, $0af6, $008f, $0bbb    ;user interface (C64 palette but 6 = lighter blue and 11 = black instead of dark grey)
_graphicspalettes:
_playerpalette:
        !src "playerpalette.asm"
_creaturespalette:
        !src "creaturespalette.asm"
_tilespalette:
        !src "tilespalette.asm"

