;*** veralib.asm ****************************************************************

!macro VPoke .addr, .data {     ;.addr = address to change value of
        ldx #<.addr             ;.data = absolute value (memory address which holds the value to set)
        stx VERA_ADDR_L
        ldx #>.addr
        stx VERA_ADDR_M
        ldx #$01
        stx VERA_ADDR_H
        lda .data
        sta VERA_DATA0
}

!macro VPokeI .addr, .data {    ;.addr = address to change value of
        ldx #<.addr             ;.data = immediate value to set 
        stx VERA_ADDR_L
        ldx #>.addr
        stx VERA_ADDR_M
        ldx #$01
        stx VERA_ADDR_H
        lda #.data
        sta VERA_DATA0
}

!macro VPoke .addr {            ;.addr = address to change value of
        ldx #<.addr             ;.A = value to set
        stx VERA_ADDR_L
        ldx #>.addr
        stx VERA_ADDR_M
        ldx #$01
        stx VERA_ADDR_H
        sta VERA_DATA0
}

!macro VPokeIndirect .addr {    ;.addr and .addr+1 = pointer to address to change value of
        ldx .addr               ;.A = value to set
        stx VERA_ADDR_L
        ldx .addr+1
        stx VERA_ADDR_M
        ldx #$01
        stx VERA_ADDR_H
        sta VERA_DATA0        
}

!macro VPeek .addr_lo {         ;carry flag = bank 0 or 1
        lda #0                  ;addr_lo = address to read, OUT: .A = value of memory address
        adc #0                  ;transfer carry flag to .A by adding WITH CARRY
        sta VERA_ADDR_H
        lda .addr_lo
        sta VERA_ADDR_L
        lda .addr_lo+1
        sta VERA_ADDR_M
        lda VERA_DATA0
}

!macro VPokeSprites .addr, .count {             ;.addr = address of first sprite
        ldx #<.addr                             ;.count = number of continous sprites to set data to
        stx VERA_ADDR_L                         ;.A = value to set
        ldx #>.addr
        stx VERA_ADDR_M
        ldx #$41
        stx VERA_ADDR_H
        ldx .count
-       sta VERA_DATA0
        dex
        bne -
}

!macro VPokeSpritesI .addr, .count, .data {     ;.addr = address of first sprite
        ldx #<.addr                             ;.count = number of continous sprites to set data to
        stx VERA_ADDR_L                         ;.data = immediate value to set
        ldx #>.addr
        stx VERA_ADDR_M
        ldx #$41
        stx VERA_ADDR_H 
        ldx .count
        lda #.data
-       sta VERA_DATA0
        dex
        bne -
}

!macro PositionSprite .pos_lo, .pos_hi, .campos_lo, .campos_hi, .screencenter, .spritewidth {        
        ;calculate screen coordinates for a sprite in relation to camera.
        ;OUT: ZP0, ZP1 = 16 bit position, if off screen position is set to 512

        lda .pos_lo                     ;1 - start with sprite position - camera position
        sec
        sbc .campos_lo
        sta ZP0
        lda .pos_hi
        sbc .campos_hi
        sta ZP1

        lda #.screencenter-.spritewidth/2 ;2 - add middle of screen - sprite width/2 to get position for middle of sprite
        clc
        adc ZP0
        sta ZP0
        lda #0
        adc ZP1
        sta ZP1

        cmp #$0f                        ;3 - check high byte to see if sprite position is between -256 and 512, if not hide it 
        bcs +                           ;(a position of for example 1024+50 would display the sprite at pos 50 otherwise...)
        cmp #$02
        bcc +
        stz ZP0                         ;sprite should not be displayed, to achieve this just set pos to 512
        lda #2
        sta ZP1
+       
}

!macro CopyPalettesToVRAM .source,.deststart, .count {      ;IN .source = source address, .deststart = first palette index to copy to, .count = number of palettes (max 8!)
        lda #<PALETTE+.deststart*32
        sta VERA_ADDR_L
        lda #>PALETTE+.deststart*32           
        sta VERA_ADDR_M
        lda #$11                
        sta VERA_ADDR_H

        ldy #0           
-       lda .source,y        
        sta VERA_DATA0     
        iny
        cpy #.count*32  ;loop through number of palettes * 16 colors * 2 bytes             
        bne -
}

!macro CopyPalettesFromVRAM .dest,.sourcestart, .count {    ;IN .dest = destination address, .sourcestart = first palette index to copy from, .count = number of palettes (max 8!)
        lda #<PALETTE+.sourcestart*32
        sta VERA_ADDR_L
        lda #>PALETTE+.sourcestart*32           
        sta VERA_ADDR_M
        lda #$11                
        sta VERA_ADDR_H

        ldy #0           
-       lda VERA_DATA0
        sta .dest,y     
        iny
        cpy #.count*32  ;loop through number of palettes * 16 colors * 2 bytes             
        bne -
}

VPoke:  ;routine for poking VRAM that takes inline parameters
        ; example: jsr VPoke           
        ;          !word SPR_CTRL
        ;          !byte 1

        ;First modify the return address in stack to point after the inline arguments (+ 3 bytes)

        clc
        tsx                 ;transfer stack pointer to x, points to next free byte in stack    
        lda $0101,x         ;load low byte of return address
        sta ZP0             ;and store it in zeropage location unused by KERNAL/BASIC
        adc #3              ;add 3 bytes (a word arg and a byte arg) to return address
        sta $0101,x         ;and store the low byte of the new return address
            
        lda $0102,x         ;load high byte of return address
        sta ZP1             ;and store it in next zeropage location unused by KERNAL/BASIC
        adc #0              ;add 0 to which includes the carry flag to complete a full 16-bit add
        sta $0102,x         ;and store the high byte of the return address
            
        ;Then use the original return address to access inline arguments
        ldy #1              ;The return address is actually pointing to the return address-1
        lda (ZP0),y         ;therefore access the first argument with an offset of 1 and so on
        sta VERA_ADDR_L
            
        ldy #2
        lda (ZP0),y
        sta VERA_ADDR_M

        lda #1         
        sta VERA_ADDR_H

        stz VERA_CTRL
        ldy #3
        lda (ZP0),y
        sta VERA_DATA0
        rts

