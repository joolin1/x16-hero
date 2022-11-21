;*** Load graphic resources to VRAM ****************************************************************

;Memory layout for screen and graphic resources
!addr L1_MAP_ADDR            = $0000              ;         8 Kb | Layer 1 - the original text layer is located at $0000 an in front of layer 0
                                                  ;              | 80 cols (each 256 bytes) x 30 rows = 256 x 30 = $1e00 bytes
!addr TILES_ADDR             = $2000              ;        16 Kb | Room for 128 tiles   (16 rows x  8 bytes/row) -> 128 x 16 x  8 = $4000 bytes
!addr PLAYER_SPRITES_ADDR    = $6000              ;         6 Kb | Room for 24 32x16 sprites (32 rows x 8 bytes/row = 256 bytes/sprite)
!addr CREATURE_SPRITES_ADDR  = $7800              ;         6 Kb | Room for 48 16x16 sprites (16 rows x 8 bytes/row) = 128 bytes/sprite)
!addr NEW_CHAR_ADDR          = $9000              ;         2 Kb | Charset is relocated here
!addr L0_MAP_ADDR            = $A000              ;        64 Kb | Layer 0 - game graphics layer. Max 256 tiles high x 128 tiles wide x 2 bytes for each tile = 64 Kb

!addr GRAPHICS_PALETTES = PALETTE + $20
!addr TILES_PALETTE     = PALETTE + $60

;RAM Memory layout
;              $0810: game code
;              $9766: ZSound - NOT ADDED
;              $A000: RAM banks

;RAM banks
FIRST_BANK              = 1
ZSM_TITLE_BANK          = 1     ;NOTE: if tune more than 8 KB it needs several banks
ZSM_MENU_BANK           = 2
ZSM_NAMEENTRY_BANK      = 3
SAVEDGAME_BANK          = 4

;Graphic resources to load
.tilesname      !text "TILES.BIN",0
.playername     !text "PLAYER.BIN",0
.creaturesname  !text "CREATURES.BIN",0
.fontname       !text "FONT.BIN",0
.levelname      !text "LEVEL"
.levelnumber    !byte 0,0       ;level number in ascii
                !text ".BIN",0
.leveldecimal   !word 0         ;current level in decimal form

_fileerrorflag  !byte   0   ;at least one i/o error has occurred if set

!macro LoadResource .filename, .addr, .ramtype, .header {
        lda #<.filename
        sta ZP0
        lda #>.filename
        sta ZP1
        lda #<.addr
        sta ZP2
        lda #>.addr
        sta ZP3
        lda #.ramtype
        sta ZP4
        lda #.header
        sta ZP5
        jsr LoadFile                   ;call filehandler
        bcc +
        jsr PrintIOErrorMessage
        lda #1
        sta _fileerrorflag
+
}

LoadGraphics:
        stz _fileerrorflag
        +LoadResource .tilesname    , TILES_ADDR            , LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER
        +LoadResource .playername   , PLAYER_SPRITES_ADDR   , LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER
        +LoadResource .creaturesname, CREATURE_SPRITES_ADDR , LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER
        +LoadResource .fontname     , NEW_CHAR_ADDR         , LOAD_TO_VRAM_BANK0, FILE_HAS_NO_HEADER
        
        lda _fileerrorflag
        beq +
        sec                             ;set carry to flag error
        rts
+       clc                             ;clear carry to flag everything is ok
        rts

LoadLevel:
        stz _fileerrorflag
        lda _level
        +ConvertBinToDec _level, .leveldecimal
        
        lda .leveldecimal
        and #%11110000          ;mask out high digit of current level
        lsr
        lsr
        lsr
        lsr
        clc
        adc #$30                ;convert to ascii by adding code for "0"
        sta .levelnumber

        lda .leveldecimal
        and #%00001111          ;mask out low digit of current level
        clc
        adc #$30                ;convert to ascii
        sta .levelnumber+1

        +LoadResource .levelname, L0_MAP_ADDR, LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER

        lda _fileerrorflag
        beq +
        sec                             ;set carry to flag error
        rts
+       clc                             ;clear carry to flag everything is ok
        rts

