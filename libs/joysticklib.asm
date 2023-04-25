;*** joystick.lib **********************************************************************************

JOYSTICK_PRESENT        = $00
JOYSTICK_NOT_PRESENT    = $ff

JOY_NOTHING_PRESSED     = 255
JOY_BUTTON_B            = 128
JOY_BUTTON_A            = 64
JOY_SELECT              = 32
JOY_START               = 16
JOY_UP                  = 8
JOY_DOWN                = 4
JOY_LEFT                = 2
JOY_RIGHT               = 1
JOY_NO_DIRECTION        = 15

;what controllers are used (= what _joy0 and joy1 will correspond to) depends on how many game controllers are present
.joy0mapping:   !byte 0 ;can be keyboard or game controller 1
.joy1mapping:   !byte 0 ;can be nothing, game controller 1 or game controller 2
.joystick_count !byte 0

_joy0:          !byte 0 ;status for first controller
_joy1:          !byte 0 ;status for second controller

.joy_record     !byte 0 ;boolean - turn on or off recording of controllers
_joy_playback   !byte 0 ;boolean - turn on or off whether recorded data or actual status of controllers should be returned by GetJoys
.record_addr_lo !byte 0
.record_addr_hi !byte 0
.savedgamename  !text "SAVEDGAME.BIN",0 

!macro GetJoy0_NoRepeat .inputwait {            ;if flag .inputwait is set, wait for player to release everything before accepting input
        lda .inputwait
        beq ++
        lda _joy0
        cmp #JOY_NOTHING_PRESSED
        bne +
        stz .inputwait
+       lda #JOY_NOTHING_PRESSED
        bra +++
++      lda _joy0
+++
}


;*** Public functions **********************************************************

InitJoysticks:

        ;*** TEMP ****
        stz .joy0mapping
        lda #1
        sta .joy1mapping
        rts
        ;*** END TEMP ****

        jsr joystick_scan
        lda #1
        sta .joystick_count     ;keyboard joystick is always present
        lda #1
        jsr joystick_get
        cpy #JOYSTICK_NOT_PRESENT
        beq +
        inc .joystick_count     ;game controller 1 is present
+       lda #2
        jsr joystick_get
        cpy #JOYSTICK_NOT_PRESENT
        beq +
        inc .joystick_count     ;game controller 2 is present

+       lda .joystick_count
        cmp #1
        bne +      
        stz .joy0mapping        ;joy0 = keyboard
        lda #JOYSTICK_NOT_PRESENT
        sta .joy1mapping        ;joy1 = not present
        rts

+       cmp #2
        bne +
        lda #1                  ;joy0 = game controller
        sta .joy0mapping        
        stz .joy1mapping        ;joy1 = keyboard
        rts

+       lda #1                 
        sta .joy0mapping        ;joy0 = game controller 1
        lda #2
        sta .joy1mapping        ;joy1 = game controller 2
        rts

GetJoys:                        ;OUT: status of both controllers in _joy0 and _joy1
        ;jsr joystick_scan      ;only necessary if default irq handler is skipped
        lda _joy_playback
        beq +
        jsr .PlaybackJoysticks
        rts

+       lda .joy0mapping
        jsr .Wrapped_joystick_get
        sta _joy0
        lda .joy1mapping
        jsr .Wrapped_joystick_get
        sta _joy1
        lda .joy_record
        bne +
        rts
+       jsr .RecordJoysticks              
        rts

GetRealJoy0:                    ;always get real input regardless of playback on or off. OUT: status of first controller in .A
        lda .joy0mapping
        jsr .Wrapped_joystick_get
        rts

.Wrapped_joystick_get:
        jsr joystick_get
        ora #64         ;keep all except bit 6
        sta ZP0
        txa
        ora #127        ;mask out button A
        sec
        ror             ;move result to bit 6
        and ZP0         ;merge with other info
        rts

StartJoyRecording:
        lda #1
        sta .joy_record
        stz _joy_playback
        lda #<BANK_ADDR         ;init pointer for recording
        sta .record_addr_lo
        lda #>BANK_ADDR
        sta .record_addr_hi
        rts

EndJoyRecording:
        stz .joy_record
        lda #SAVEDGAME_BANK
        sta RAM_BANK
        lda #<.savedgamename
        sta ZP0
        lda #>.savedgamename
        sta ZP1
        lda #<BANK_ADDR
        sta ZP2
        lda #>BANK_ADDR
        sta ZP3
        lda .record_addr_lo
        sta ZP4
        lda .record_addr_hi
        sta ZP5
        jsr SaveFile
        lda #FIRST_BANK
        sta RAM_BANK
        rts

StartJoyPlayback:
        lda #1
        sta _joy_playback
        stz .joy_record
        lda #<BANK_ADDR         ;init pointer for playback
        sta .record_addr_lo
        lda #>BANK_ADDR
        sta .record_addr_hi
        rts

EndJoyPlayback:
        stz _joy_playback
        rts

.PlaybackJoysticks:
        lda #SAVEDGAME_BANK
        sta RAM_BANK
        lda .record_addr_lo
        sta ZP0
        lda .record_addr_hi
        sta ZP1
        lda (ZP0)
        sta _joy0
        +Inc16 ZP0
        lda (ZP0)
        sta _joy1
        +Inc16 ZP0
        lda ZP0
        sta .record_addr_lo
        lda ZP1
        sta .record_addr_hi
        lda #FIRST_BANK
        sta RAM_BANK
        rts

.RecordJoysticks:
        lda #SAVEDGAME_BANK
        sta RAM_BANK
        lda .record_addr_lo
        sta ZP0
        lda .record_addr_hi
        sta ZP1
        lda _joy0
        sta (ZP0)
        +Inc16 ZP0
        lda _joy1
        sta (ZP0)
        +Inc16 ZP0
        lda ZP0
        sta .record_addr_lo
        lda ZP1
        sta .record_addr_hi
        lda #FIRST_BANK
        sta RAM_BANK
        rts

; O L D ! !
; ;*** joystick.lib **********************************************************************************

; JOYSTICK_NOT_PRESENT    = 0
; JOYSTICK_TYPE_NES       = 1
; JOYSTICK_TYPE_SNES      = 2

; JOY_NOTHING_PRESSED     = 255
; JOY_BUTTON_A            = 128
; JOY_BUTTON_B            = 64
; JOY_SELECT              = 32
; JOY_START               = 16
; JOY_UP                  = 8
; JOY_DOWN                = 4
; JOY_LEFT                = 2
; JOY_RIGHT               = 1

; _joy0type:	!byte 0 ;used by GetJoys to store status of game controller 0 in NES style
; _joy1type:	!byte 0 ;used by GetJoys to store status of game controller 1 in NES style
; _joy0:          !byte 0 ;status for game controller 0
; _joy1:          !byte 0 ;status for game controller 1

; ;*** Public functions **********************************************************

; InitJoysticks:
; 	jsr joystick_scan
; 	ldx #0
; 	jsr joystick_get
; 	txa
; 	and #12
; 	beq +
; 	lda #JOYSTICK_TYPE_SNES
; 	sta _joy0type
; 	bra ++
; +	lda #JOYSTICK_TYPE_NES
; 	sta _joy0type
; ++      ldx #1
; 	jsr joystick_get
;         tya
;         beq +
;         lda #JOYSTICK_NOT_PRESENT
;         sta _joy1type
;         rts
; +	txa
; 	and #12
; 	beq +
; 	lda #JOYSTICK_TYPE_SNES
; 	sta _joy1type
; 	rts
; +	lda #JOYSTICK_TYPE_NES
; 	sta _joy1type
; 	rts

; GetJoys:                        ;OUT: status of both joysticks in _joy0 and _joy1
;         jsr joystick_scan
;         ldx #0
;         jsr joystick_get
;         pha
;         lda _joy0type
;         cmp #JOYSTICK_TYPE_NES
;         bne +
;         pla
;         sta _joy0
;         bra ++
; +       pla
;         jsr .MoveBits
;         sta _joy0
; ++      ldx #1
;         jsr joystick_get
;         pha
;         lda _joy1type
;         cmp #JOYSTICK_TYPE_NES
;         bne +
;         pla
;         sta _joy1
;         rts
; +       pla
;         jsr .MoveBits
;         sta _joy1
;         rts

; GetJoy0:                        ;OUT: .A = status of joystick 0 in NES layout regardless of joystick type
;         jsr joystick_scan
;         ldx #0
;         jsr joystick_get        
;         pha
;         lda _joy0type
;         cmp #JOYSTICK_TYPE_NES
;         bne +
;         pla                     ;do nothing if NES
;         rts                     

; GetJoy1:
;         jsr joystick_scan       ;OUT: .A = status of joystick 1 in NES layout regardless of joystick type
;         ldx #1
;         jsr joystick_get
;         pha
;         lda _joy1type
;         cmp #JOYSTICK_TYPE_NES
;         bne +
;         pla                     ;do nothing if NES
;         rts

; ;*** Private functions *********************************************************

; +       pla
; .MoveBits:
;         and #191                ;set bit 6 to 0 in byte 0 (first byte with joystick info)
;         sta ZP0
;         and #128                ;keep just bit 7 (button B when SNES)
;         lsr                     ;shift 7 to 6
;         ora ZP0                 ;merge with byte 0
;         and #127                ;set bit 7 to 0
;         sta ZP0
;         txa
;         and #128                ;get bit 7 in byte 1 (button A when SNES)
;         ora ZP0                 ;merge with byte 0
;         rts