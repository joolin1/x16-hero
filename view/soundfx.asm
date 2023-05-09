;*** soundfx.asm ***********************************************************************************

PLAYING_ENGINE       = 0
PLAYING_CREATUREDEAD = 1
PLAYING_LASER        = 2
PLAYING_PLAYERDEAD   = 3
PLAYING_EXPLOSION    = 4
PLAYING_FINISHED1    = 5
PLAYING_FINISHED2    = 6

_playingtable   !fill 7,0      ;boolean table for sound effects (NOTE: Make sure to reserv the same number of bytes as number of sound effects)

!macro SfxPlay .playing_fx, .voice, .length, .repeat, .data, .index, .delay { ;IN: 4 immediate values and 3 vectors
        ldy #.playing_fx
        lda _playingtable,y
        beq +++                 ;exit if this sound isn't playing
        lda .delay
        beq +                   ;read new sound data if delay = 0
        dec .delay
        bra +++

+       lda .index
        cmp #.length*5          ;reached end of sound data?
        bne ++
        lda #.repeat
        beq +                   ;should sound be repeated?
        stz .index              ;yes, start from the beginning
        bra ++
+       ldy #.playing_fx
        lda #0
        sta _playingtable,y     ;no, stop sound
        lda #.voice             
        jsr StopSound
        bra +++

++      lda #<PSG_ADDR          ;start with base address of PSG
        sta ZP0
        lda #>PSG_ADDR
        sta ZP1
        lda #.voice
        asl
        asl
        clc
        adc ZP0                 ;add voice number*4 because each voice has four addresses to write to
        sta ZP0
        lda #0
        adc ZP1
        sta ZP1

        lda ZP0                 ;set start voice address
        sta VERA_ADDR_L
        lda ZP1
        sta VERA_ADDR_M
        lda #$11                ;auto increment one
        sta VERA_ADDR_H

        ldy .index              ;read data from table and stor in addresses of the voice
        lda .data,y
        ldx #.playing_fx
        jsr AdjustEngineSound   ;if engine sound, change frequency according to speed            
        sta VERA_DATA0
        iny
        lda .data,y             
        sta  VERA_DATA0
        iny
        lda .data,y          
        sta VERA_DATA0
        iny
        lda .data,y       
        sta VERA_DATA0
        iny
        lda .data,y
        sta .delay              ;set how many jiffies this data should sound
        iny
        sty .index              
+++     nop     
}

StopSound:                      ;IN: .A = voice to silence      
        ldx #<PSG_ADDR          ;start with base address of PSG
        stx ZP0
        ldx #>PSG_ADDR
        stx ZP1
        asl
        asl
        clc
        adc ZP0                 ;add voice number*4 because each voice has four addresses to write to
        sta ZP0
        lda #0
        adc ZP1
        sta ZP1
        lda ZP0                 ;set start voice address
        sta VERA_ADDR_L
        lda ZP1
        sta VERA_ADDR_M
        lda #$11                ;auto increment one
        sta VERA_ADDR_H
        stz VERA_DATA0          ;set all registers of voice to 0
        stz VERA_DATA0
        stz VERA_DATA0
        stz VERA_DATA0
        rts

StopPlayerSounds:
        jsr StopEngineSound
        jsr StopLaserSound
        rts

;*** Helicopter Engine **************************

PlayEngineSound:
        ldy #PLAYING_ENGINE
        lda _playingtable,y
        beq +
        rts                     ;sound is already playing
+       lda #1
        sta _playingtable,y
        stz .engine_index
        stz .engine_delay
        rts

.engine_index          !byte 0
.engine_delay          !byte 0

AdjustEngineSound:
        cpx #PLAYING_ENGINE
        bne +
        sta ZP0
        lda _flyingspeed
        asl
        clc
        adc ZP0
+       rts

StopEngineSound:
        ldy #PLAYING_ENGINE     ;set effects as not playing
        lda #0
        sta _playingtable,y
        lda #ENGINE_VOICE                  
        jsr StopSound           
        rts

;*** Laser **************************************        

PlayLaserSound:
        ldy #PLAYING_LASER
        lda #1
        sta _playingtable,y
        stz .laser_index
        stz .laser_delay
        rts

StopLaserSound:
        ldy #PLAYING_LASER
        lda #0
        sta _playingtable,y
        lda #LASER_VOICE
        jsr StopSound
        rts

.laser_index            !byte 0
.laser_delay            !byte 0

;*** Player killed ******************************

PlayPlayerKilledSound:
        ldy #PLAYING_PLAYERDEAD
        lda #1
        sta _playingtable,y
        stz .playerdead_index
        stz .playerdead_delay
        rts

.playerdead_index           !byte 0
.playerdead_delay           !byte 0

;*** Creature killed ****************************

PlayCreatureKilledSound:
        ldy #PLAYING_CREATUREDEAD
        lda #1
        sta _playingtable,y
        sta _playingtable+1,y
        stz .creaturedead_index
        stz .creaturedead_delay
        rts

.creaturedead_index        !byte 0
.creaturedead_delay        !byte 0

;*** Bomb detonating ****************************

PlayExplosionSound:
        ldy #PLAYING_EXPLOSION
        lda #1
        sta _playingtable,y
        stz .explosion_index
        stz .explosion_delay
        rts

.explosion_index        !byte 0
.explosion_delay        !byte 0

;*** Level completed ****************************

PlayFinishedSound:
        ldy #PLAYING_FINISHED1
        lda #1
        sta _playingtable,y
        stz .finished1_index
        stz .finished1_delay
        ldy #PLAYING_FINISHED2            ;use two voices
        lda #1
        sta _playingtable,y
        stz .finished2_index
        stz .finished2_delay
        rts

.finished1_index           !byte 0
.finished1_delay           !byte 0
.finished2_index           !byte 0
.finished2_delay           !byte 0

;************************************************

SfxTick:
                ;sound fx              voice                 length            repeat? data          
        +SfxPlay PLAYING_ENGINE,       ENGINE_VOICE,         ENGINE_LENGTH,       1,   .enginefx,       .engine_index,       .engine_delay
        +SfxPlay PLAYING_LASER,        LASER_VOICE,          LASER_LENGTH,        0,   .laserfx,        .laser_index,        .laser_delay
        +SfxPlay PLAYING_CREATUREDEAD, CREATUREDEAD_VOICE,   CREATUREDEAD_LENGTH, 0,   .creaturedeadfx, .creaturedead_index, .creaturedead_delay
        +SfxPlay PLAYING_EXPLOSION,    EXPLOSION_VOICE,      EXPLOSION_LENGTH,    0,   .explosionfx,    .explosion_index,    .explosion_delay
        +SfxPlay PLAYING_PLAYERDEAD,   PLAYERDEAD_VOICE,     PLAYERDEAD_LENGTH,   0,   .playerdeadfx,   .playerdead_index,   .playerdead_delay
        +SfxPlay PLAYING_FINISHED1,    FINISHED_VOICE1,      FINISHED_LENGTH,     0,   .finished1fx,    .finished1_index,    .finished1_delay
        +SfxPlay PLAYING_FINISHED2,    FINISHED_VOICE2,      FINISHED_LENGTH,     0,   .finished2fx,    .finished2_index,    .finished2_delay
        rts         

;*** definitions of sound effects ******************************************************************

RIGHT_PAN       = 64
LEFT_PAN        = 128
BOTH_PAN        = 192
PULSE           = 0
SAW             = 64
TRIANGLE        = 128
NOISE           = 192

MASTER_VOICE = 0 ;set this to change interval of voices used

ENGINE_VOICE  = MASTER_VOICE + 0
ENGINE_LENGTH = 4
.enginefx       !byte 74, 0, BOTH_PAN + 48, PULSE + 10, 4     ;low freq, high freq, pan + vol, waveform + wavelength, delay
                !byte 74, 0, BOTH_PAN + 48, PULSE + 20, 4
                !byte 74, 0, BOTH_PAN + 48, PULSE + 10, 4
                !byte 74, 0, BOTH_PAN + 48, PULSE + 20, 4

LASER_VOICE  = MASTER_VOICE + 1
LASER_LENGTH = 8
.laserfx        !byte 200, 5, BOTH_PAN + 50, PULSE    + 15, 2 
                !byte 180, 5, BOTH_PAN + 50, SAW      + 25, 2
                !byte 160, 5, BOTH_PAN + 50, PULSE    + 35, 2 
                !byte 140, 5, BOTH_PAN + 50, TRIANGLE + 45, 2
                !byte 120, 5, BOTH_PAN + 50, PULSE    + 35, 2 
                !byte 100, 5, BOTH_PAN + 50, SAW      + 25, 2
                !byte  80, 5, BOTH_PAN + 50, PULSE    + 15, 2 
                !byte  60, 5, BOTH_PAN + 50, TRIANGLE + 25, 2

CREATUREDEAD_VOICE  = MASTER_VOICE + 2
CREATUREDEAD_LENGTH = 5
.creaturedeadfx !byte 249, 12, BOTH_PAN + 63, NOISE + 10, 4
                !byte 249, 12, BOTH_PAN + 48, NOISE + 20, 4
                !byte 249, 12, BOTH_PAN + 32, NOISE + 30, 4
                !byte 249, 12, BOTH_PAN + 32, NOISE + 20, 4
                !byte 249, 12, BOTH_PAN + 24, NOISE + 10, 4
                
EXPLOSION_VOICE  = MASTER_VOICE + 3
EXPLOSION_LENGTH = 12
.explosionfx    !byte 249, 10, BOTH_PAN + 63, NOISE + 10, 8
                !byte 249, 10, BOTH_PAN + 63, NOISE + 20, 8
                !byte 249, 10, BOTH_PAN + 48, NOISE + 30, 8
                !byte 249, 10, BOTH_PAN + 48, NOISE + 20, 8
                !byte 249, 10, BOTH_PAN + 32, NOISE + 10, 8
                !byte 249, 10, BOTH_PAN + 32, NOISE + 20, 8
                !byte 249, 10, BOTH_PAN + 24, NOISE + 30, 8
                !byte 249, 10, BOTH_PAN + 24, NOISE + 20, 8
                !byte 249, 10, BOTH_PAN + 16, NOISE + 10, 8
                !byte 249, 10, BOTH_PAN + 16, NOISE + 20, 8
                !byte 249, 10, BOTH_PAN +  8, NOISE + 30, 8
                !byte 249, 10, BOTH_PAN +  8, NOISE + 20, 8

PLAYERDEAD_VOICE = MASTER_VOICE + 4
PLAYERDEAD_LENGTH = 4
.playerdeadfx   
                !byte  14,2, RIGHT_PAN + 63, TRIANGLE + 52, 24 ;G3
                !byte 178,1, RIGHT_PAN + 63, TRIANGLE + 52, 12 ;E3
                !byte  14,2, RIGHT_PAN + 63, TRIANGLE + 52, 12 ;G3
                !byte  95,1, RIGHT_PAN + 63, TRIANGLE + 52, 48 ;C3

FINISHED_VOICE1  = MASTER_VOICE + 4
FINISHED_VOICE2  = MASTER_VOICE + 5
FINISHED_LENGTH = 4
.finished1fx    
                !byte  28,4, LEFT_PAN + 63, TRIANGLE + 52, 24 ;G4
                !byte 117,3, LEFT_PAN + 63, TRIANGLE + 52, 12 ;E4
                !byte  28,4, LEFT_PAN + 63, TRIANGLE + 52, 12 ;G4
                !byte 125,5, LEFT_PAN + 63, TRIANGLE + 52, 48 ;C5
.finished2fx
                !byte  14,2, RIGHT_PAN + 63, TRIANGLE + 52, 24 ;G3
                !byte 178,1, RIGHT_PAN + 63, TRIANGLE + 52, 12 ;E3
                !byte  14,2, RIGHT_PAN + 63, TRIANGLE + 52, 12 ;G3
                !byte 190,2, RIGHT_PAN + 63, TRIANGLE + 52, 48 ;C4

