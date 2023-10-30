;*** Load graphic resources to VRAM ****************************************************************

;Memory layout for screen and graphic resources
!addr L1_MAP_ADDR            = $0000              ;         8 Kb | Layer 1 - the original text layer is located at $0000 an in front of layer 0
                                                  ;              | 80 cols (each 256 bytes) x 30 rows = 256 x 30 = $1e00 bytes
!addr TILES_ADDR             = $2000              ;        16 Kb | Room for 128 tiles   (16 rows x  8 bytes/row) -> 128 x 16 x  8 = $4000 bytes
!addr PLAYER_SPRITES_ADDR    = $6000              ;         5 Kb | Room for 20 32x16 sprites (32 rows x 8 bytes/row = 256 bytes/sprite)
!addr CREATURE_SPRITES_ADDR  = $7400              ;         8 Kb | Room for 64 16x16 sprites (16 rows x 8 bytes/row) = 128 bytes/sprite)
!addr NEW_CHAR_ADDR          = $9800              ;         2 Kb | Charset is relocated here
!addr L0_MAP_ADDR            = $A000              ;        64 Kb | Layer 0 - game graphics layer. Max 256 tiles high x 128 tiles wide x 2 bytes for each tile = 64 Kb
;!addr IMAGE_ADDR             = $A000              ;        37 Kb | Layer 0 - title image 320x240 shares memory with tiles

CREATURE_SPRITES_SIZE = 128

;RAM Memory layout
;              $0810: ZSound
;                   : Game Code
;              $A000: RAM banks

;VRAM banks
;IMAGE_BANK              = 1

;RAM banks
FIRST_BANK              = 1
SAVEDGAME_BANK          = 2             ;not implemented
ZSMKIT_BANK             = 3
ZSM_KILLED_BANK         = 4
ZSM_GAMEOVER_BANK       = 5
ZSM_LEVELCOMPLETE_BANK  = 6             ;33 KB
ZSM_GAMECOMPLETE_BANK   = 11   
ZSM_TITLE_BANK          = 12            ;121 KB
ZSM_HIGHSCORE_BANK      = 28            ;70 KB

;Graphic resources to load
;.imagename      !text "IMAGE.BIN",0
.tilesname      !text "TILES.BIN",0
.playername     !text "SPRITE0.BIN",0
.creaturesname  !text "SPRITE1.BIN",0
.fontname       !text "FONT.BIN",0
.palettename    !text "PAL.BIN",0

.lowlevelname           !text "MAP"
.lowlevelnumber         !byte 0         ;level number (0-9) in ascii
                        !text ".BIN",0

.highlevelname          !text "MAP"
.highlevelnumber        !byte 0,0       ;level number(10-) in ascii
                        !text ".BIN",0

.leveldecimal   !word 0         ;current level in decimal form

;Sound resources to load
.zsmtitle               !text "TITLE.ZSM",0;"TITLE.ZSM",0
.zsmkilled              !text "KILLED.ZSM",0
.zsmgameover            !text "GAMEOVER.ZSM",0
.zsmlevelcomplete       !text "LEVELCOMPLETE.ZSM",0
.zsmgamecomplete        !text "GAMECOMPLETE.ZSM",0
.zsmhighscore           !text "HIGHSCORE.ZSM",0

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

PlayMusic:                      ;IN: .A = memory bank where music is loaded     
        sta RAM_BANK
        ldx #0                  ;priority = 0
        lda #<BANK_ADDR
        ldy #>BANK_ADDR
        jsr zsm_setmem
        ldx #0
        jsr zsm_play   
        rts

StopMusic:
        ldx #0
        jsr zsm_stop
        rts

StartFadeOutMusic:
        lda #0
        sta .attenuation
        jsr FadeOutMusic
        rts

FadeOutMusic:
        ldx #0
        lda .attenuation
        jsr zsm_setatten
        dec .attenuation
        lda .attenuation
        bne + 

+       rts

.attenuation    !byte 0

LoadResources:
        stz _fileerrorflag
        +LoadResource .tilesname       , TILES_ADDR            , LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER
        +LoadResource .playername      , PLAYER_SPRITES_ADDR   , LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER
        +LoadResource .creaturesname   , CREATURE_SPRITES_ADDR , LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER
        +LoadResource .fontname        , NEW_CHAR_ADDR         , LOAD_TO_VRAM_BANK0, FILE_HAS_NO_HEADER
        +LoadResource .palettename     , PALETTE               , LOAD_TO_VRAM_BANK1, FILE_HAS_HEADER
        
        lda #ZSM_TITLE_BANK
        sta RAM_BANK
        +LoadResource .zsmtitle        , BANK_ADDR             , LOAD_TO_RAM       , FILE_HAS_NO_HEADER
        lda #ZSM_GAMECOMPLETE_BANK
        sta RAM_BANK
        +LoadResource .zsmgamecomplete , BANK_ADDR             , LOAD_TO_RAM       , FILE_HAS_NO_HEADER
        lda #ZSM_HIGHSCORE_BANK
        sta RAM_BANK
        +LoadResource .zsmhighscore    , BANK_ADDR             , LOAD_TO_RAM       , FILE_HAS_NO_HEADER

        lda #ZSM_KILLED_BANK
        sta RAM_BANK
        +LoadResource .zsmkilled       , BANK_ADDR             , LOAD_TO_RAM       , FILE_HAS_NO_HEADER
        lda #ZSM_GAMEOVER_BANK
        sta RAM_BANK
        +LoadResource .zsmgameover     , BANK_ADDR             , LOAD_TO_RAM       , FILE_HAS_NO_HEADER
        lda #ZSM_LEVELCOMPLETE_BANK
        sta RAM_BANK
        +LoadResource .zsmlevelcomplete, BANK_ADDR             , LOAD_TO_RAM       , FILE_HAS_NO_HEADER

        lda _fileerrorflag
        beq +
        sec                             ;set carry to flag error
        rts
+       clc                             ;clear carry to flag everything is ok
        rts

; LoadStartImage:
;         +LoadResource .imagename, IMAGE_ADDR, LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER
;         rts

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
        sta .highlevelnumber

        lda .leveldecimal
        and #%00001111          ;mask out low digit of current level
        clc
        adc #$30                ;convert to ascii
        sta .highlevelnumber+1

        lda .highlevelnumber
        cmp #$30                ;if high digit is "0" then load skip it in filename
        bne +
        lda .highlevelnumber+1
        sta .lowlevelnumber
        +LoadResource .lowlevelname, L0_MAP_ADDR, LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER
        bra ++

+       +LoadResource .highlevelname, L0_MAP_ADDR, LOAD_TO_VRAM_BANK0, FILE_HAS_HEADER

++      lda _fileerrorflag
        beq +
        sec                             ;set carry to flag error
        rts
+       clc                             ;clear carry to flag everything is ok
        rts

