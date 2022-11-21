;*** timer.asm **************************************************************************************
 
InitTimer:
        stz _minutes
        stz _seconds
        stz _jiffies
        rts

.TimeAddSeconds:                ;IN: .A = number of seconds to add
        cmp #0                  
        bne +
        rts
+       tax
-       jsr .TimeAddSecond
        dex
        bne -
        rts

TimeTick:
        inc _jiffies            ;interrupt is triggered once every 1/60 second. That is why we add exactly this.
        lda _jiffies
        cmp #60
        beq +
        rts
+       stz _jiffies

.TimeAddSecond:
        inc _seconds
        lda _seconds
        cmp #60
        beq +
        rts
+       stz _seconds

.TimeAddMinute:
        inc _minutes
        lda _minutes
        cmp #60
        beq +
        rts
+       stz _minutes            ;59:59:59 is max time
        rts

.TimeSubSeconds:                ;.A = number of seconds to subtract
        cmp #0
        bne +
        rts
+       tax
-       jsr .TimeSubSecond
        dex
        bne -
        rts

.TimeSubSecond:
        dec _seconds
        bmi +
        rts
+       lda #59
        sta _seconds
        dec _minutes
        bmi +
        rts
+       lda #59
        sta _minutes
        rts

_minutes    !byte 0             ;timer data
_seconds    !byte 0
_jiffies    !byte 0