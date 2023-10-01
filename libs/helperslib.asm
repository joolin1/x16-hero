;*** helperslib.asm - global helper routines *******************************************************

!macro SetParams .p0, .p1 {
        lda .p0
        sta ZP0
        lda .p1
        sta ZP1
}

!macro SetParamsI .p0, .p1 {
        lda #.p0
        sta ZP0
        lda #.p1
        sta ZP1
}

!macro SetParams .p0, .p1, .p2 {
        lda .p0
        sta ZP0
        lda .p1
        sta ZP1
        lda .p2
        sta ZP2
}

!macro SetParams .p0, .p1, .p2, .p3 {
        lda .p0
        sta ZP0
        lda .p1
        sta ZP1
        lda .p2
        sta ZP2
        lda .p3
        sta ZP3
}

!macro SetParams .p0, .p1, .p2, .p3, .p4 {
        lda .p0
        sta ZP0
        lda .p1
        sta ZP1
        lda .p2
        sta ZP2
        lda .p3
        sta ZP3
        lda .p4
        sta ZP4
}

!macro SetParams .p0, .p1, .p2, .p3, .p4, .p5 {
        lda .p0
        sta ZP0
        lda .p1
        sta ZP1
        lda .p2
        sta ZP2
        lda .p3
        sta ZP3
        lda .p4
        sta ZP4
        lda .p5
        sta ZP5
}

!macro GetElementIn16BitArray .address, .colpoweroftwo, .row, .col { ;OUT: ZP0-ZP1 = address of element in a two-dimensional array
        ;start with row offset
        lda .row
        sta ZP0
        stz ZP1
        ldy .colpoweroftwo
-       asl ZP0                 ;multiply by two
        rol ZP1                 
        dey
        bne - 
 
        ;add col offset
        lda .col      
        clc
        adc ZP0
        sta ZP0
        lda ZP1
        adc #0
        sta ZP1
        
        ;multiply offset by two because the elements are words (= two bytes)
        asl ZP0
        rol ZP1

        ;finally add base address
        lda ZP0
        clc
        adc .address
        sta ZP0
        lda ZP1
        adc .address+1                  
        sta ZP1                 ;now ZP0 and ZP1 = address to element, NOTE! carry is set if overflow
}

!macro CheckTimer .counter, .limit {    ;IN: address of counter, limit as immediate value. OUT: .A = true if counter has reached its goal otherwise false 
        inc .counter
        lda .counter
        cmp #.limit
        bne +
        stz .counter
        lda #1
        bra ++
+       lda #0
++
}

!macro CheckTimer .counter {   ;IN: address of counter, .A = limit. OUT: .A = true if counter has reached its goal otherwise false 
        sta ZP0
        inc .counter
        lda .counter
        cmp ZP0
        bne +
        stz .counter
        lda #1
        bra ++
+       lda #0
++        
}

!macro Copy16 .src_lo, .dst_lo {
        lda .src_lo
        sta .dst_lo
        lda .src_lo+1
        sta .dst_lo+1
}

CopyMem:                ;IN: ZP0, ZP1 = src. ZP2, ZP3 = dest. ZP4, ZP5 = number of bytes.      
-       lda (ZP0)
        sta (ZP2)
        +Inc16 ZP0
        +Inc16 ZP2
        +Dec16 ZP4
        lda ZP4
        bne -
        lda ZP5
        bne -
        rts

