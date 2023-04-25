;*** debuglib.asm - routines used for debugging and optimizing code ********************************

CLOCKCYCLES = $9FB8     ;clock cycles passed since start, 32 bit value

ERROR_CREATURE_NOT_FOUND = 1

_debug                  !byte 0         ;DEBUG - flag for breaking into debugger

!macro CondBreakpoint {
        lda _debug
        beq +
        !byte $db
+
}

!macro ActivateCondBreakpoint {
        lda #1
        sta _debug
}

!macro DebugSelectButtonBreakpoint {
        lda _joy0
        bit #JOY_SELECT
        bne +
        !byte $db
+
}

DebugPrintError:
        pha
        +SetPrintParams 1,1,$01
        +SetParamsI <.errormessage, >.errormessage
        jsr VPrintString
        pla
        jsr VPrintShortNumber
        rts

.errormessage    !scr "error ",0

DebugPrintInfo:
        +SetPrintParams 1,1,$01
        +VPrintHex16Number _xpos_lo
        +SetPrintParams 2,1,$01
        +VPrintHex16Number _camxpos_lo
        ; +SetPrintParams 3,1, $01
        ; +VPrintHex16Number _spr_xpos_lo
        rts

DebugChangeColor:
        jsr VPoke               
        !word TILES_PALETTE+2        
        !byte $c5               
        jsr VPoke               
        !word TILES_PALETTE+3        
        !byte $00               
        rts

DebugRestoreColor:
        jsr VPoke                
        !word TILES_PALETTE+2        
        !byte $00               
        jsr VPoke               
        !word TILES_PALETTE+3        
        !byte $00               
        rts
