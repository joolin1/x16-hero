;*** debuglib.asm - routines used for debugging and optimizing code ********************************

CLOCKCYCLES = $9FB8     ;clock cycles passed since start, 32 bit value

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

ChangeDebugColor:
        jsr VPoke               
        !word TILES_PALETTE+2        
        !byte $c5               
        jsr VPoke               
        !word TILES_PALETTE+3        
        !byte $00               
        rts

RestoreDebugColor:
        jsr VPoke                
        !word TILES_PALETTE+2        
        !byte $00               
        jsr VPoke               
        !word TILES_PALETTE+3        
        !byte $00               
        rts
