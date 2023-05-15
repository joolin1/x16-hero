;*** Set up screen and sprites ************************************************************************

SCREENWIDTH = 320
SCREENHEIGHT = 240
TILEWIDTH = 16
TILEHEIGHT = 16

!addr GRAPHICS_PALETTES_ADDR = PALETTE + $20
!addr TILES_PALETTES_ADDR    = PALETTE + $80

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

        ;layer 1 - text layer
        lda L1_MAPBASE
        sta .original_l1_mapbase
        lda #0                          ;WARNING hard coded address, should be L1_MAP_ADDR>>9
        sta L1_MAPBASE                  ;relocate text layer
        lda #NEW_CHAR_ADDR>>9           ;set tile (char address) to new location and tile size to 8x8
        sta L1_TILEBASE

        ;(layer 0 is not set here, it will switch between bitmap and tile mode)

        +CopyPalettesToVRAM _palettes, 0, 4             ;copy menu, player and creature colors to palette 0-3
        +CopyPalettesToVRAM _imagepalette, 15,1         ;copy image colors to palette 15
        +CopyPalettesFromVRAM _tilespalettes, 4,2       ;copy tile colors from VRAM, these are loaded directly there but needs backup to be able to restore light after darkness
        rts

ShowStartImage:
        jsr LoadStartImage
        jsr SetLayer0ToBitmapMode
        jsr EnableLayer0
        jsr DisableLayer1
        rts

SetLayer0ToBitmapMode:
        lda #%00000110                  ;Bitmap mode, 4 bpp = 16 colors
        sta L0_CONFIG
        lda #IMAGE_ADDR>>9              ;set bitmap address and width 320 pixels
        and #%11111100
        sta L0_TILEBASE 
        lda #15                         ;set palette index                
        sta L0_HSCROLL_H
        rts

SetLayer0ToTileMode:
        lda #L0_MAP_ADDR>>9             ;set map base address
        sta L0_MAPBASE
        lda #TILES_ADDR>>9              ;set tile address and tile size to 16x16
        ora #%00000011
        sta L0_TILEBASE
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
	rts

RestoreScreenAndSprites:        ;Restore screen and sprites when user ends game
        
        stz VERA_CTRL           ;R-----DA (R=RESET, D=DCSEL, A=ADDRSEL)
        jsr HideCreatures
        jsr HidePlayer

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

;*** Palette Layout *****************************

;0 - user interface (C64 palette but 6 = lighter blue and 11 = black instead of dark grey)                                             
_palettes:              !word $0000, $0fff, $0800, $0afe, $0c4c, $0080, $005f, $0ee7, $0d85, $0640, $0f77, $0000, $0777, $0af6, $008f, $0bbb

_graphicpalettes:

;1 - player sprite
_playerpalette:         !src "player_palette.asm"

;2 - creature sprites
_creaturespalette:      !src "creatures_palette.asm"

;3 - reserved
                        !fill 16*2,0

;4-5 - tiles
_tilespalettes:         !fill 16*2,0
                        !fill 16*2,0

;15 - start image
_imagepalette:          !src "image_palette.asm"

