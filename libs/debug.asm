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
        pha
        lda _joy0
        bit #JOY_SELECT
        bne +
        !byte $db
+       pla
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
        +SetPrintParams 2,2,$01
        lda _laserpossible
        jsr VPrintHexNumber
        +SetPrintParams 4,2
        +VPrintHex16Number _ypos_lo
        +SetPrintParams 5,2
        +VPrintHex16Number _xpos_lo
        rts

DebugChangeColor:
        jsr VPoke               
        !word TILES_PALETTES_ADDR+2        
        !byte $c5               
        jsr VPoke               
        !word TILES_PALETTES_ADDR+3        
        !byte $00               
        rts

DebugRestoreColor:
        jsr VPoke                
        !word TILES_PALETTES_ADDR+2        
        !byte $00               
        jsr VPoke               
        !word TILES_PALETTES_ADDR+3        
        !byte $00               
        rts
