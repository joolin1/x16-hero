;*** leaderboard.asm *******************************************************************************

;*** Public ****************************************************************************************

PrintLeaderboard:

        ;print headings
        +SetPrintParams LB_ROW, 0
        lda #<.scoretable
        sta ZP0
        lda #>.scoretable
        sta ZP1
        lda #0
-       pha
        tay
        lda .leaderboard_colors,y
        sta _color
        jsr VPrintString
        pla
        inc
        cmp #LB_HEADING_COUNT
        bne -
-       pha
        tay
        lda .leaderboard_colors,y
        sta _color
        jsr VPrintString
        inc _row
        pla
        inc
        cmp #LB_HEADING_COUNT+LB_ENTRIES_COUNT
        bne -

        ;print names
        lda #LB_ROW+LB_HEADING_COUNT
        sta _row
        lda #<.leaderboard_names
        sta ZP0
        lda #>.leaderboard_names
        sta ZP1
        lda #0
-       pha
        tay
        lda .leaderboard_table_colors,y
        sta _color
        lda #LB_NAME_COL
        sta _col
        jsr VPrintString
        inc _row
        pla
        inc
        cmp #LB_ENTRIES_COUNT
        bne -

        ;print number of saved miners (= coompleted levels)
        lda #LB_ROW+LB_HEADING_COUNT
        sta _row
        lda #0
-       pha
        tay
        lda .leaderboard_table_colors,y
        sta _color
        lda #LB_MINERS_COL
        sta _col
        lda .leaderboard_saved,y
        jsr VPrintShortNumber
        inc _row
        inc _row
        pla
        inc
        cmp #LB_ENTRIES_COUNT
        bne -

        ;print times
        lda #LB_ROW+LB_HEADING_COUNT
        sta _row
        lda #0
-       pha
        tay      
        lda .leaderboard_table_colors,y
        sta _color
        lda #LB_TIME_COL
        sta _col
        tya
        asl                             ;take y*2 becauese each time take 2 bytes (minutes and seconds)
        tay
        lda .leaderboard_times,y
        sta ZP0
        lda .leaderboard_times+1,y
        sta ZP1
        jsr VPrintTime
        inc _row
        pla
        inc
        cmp #LB_ENTRIES_COUNT
        bne -

        ;print start level
        lda #LB_ROW+LB_HEADING_COUNT
        sta _row
        lda #0
-       pha
        tay
        lda .leaderboard_table_colors,y
        sta _color
        lda #LB_START_COL
        sta _col
        lda .leaderboard_start,y
        jsr VPrintShortNumber
        inc _row
        inc _row
        pla
        inc
        cmp #LB_ENTRIES_COUNT
        bne -
        rts

GetHighScoreRank:                               ;IN. ZP0 = number of saved miners, ZP1-ZP2 = time. OUT: .A = rank (zero-indexed)
        lda ZP0                                 ;move parameters to be able to call IsTimeLess
        sta ZP6
        lda ZP1
        sta ZP3
        lda ZP2
        sta ZP4
        stz ZP5
        ldy #0

-       lda .leaderboard_saved,y
        cmp ZP6
        beq ++                                  ;if same number of saved miners than compare times 
        bcc +                                   ;if less number of saved miners then what player just achieved - this is the rank!  
        iny
        cpy #LB_ENTRIES_COUNT
        bne -
        lda #LB_ENTRIES_COUNT                   ;return last place in high score table + 1 = not a new high score (rank is zero-indexed)
        rts
+       tya                                     ;return rank in high score table (1-10)
        rts
++      tya                                     ;if same number of saved miners, compare times instead
        asl
        tay
        lda .leaderboard_times,y                ;high score table time in ZP0-ZP2
        sta ZP0
        lda .leaderboard_times+1,Y
        sta ZP1
        stz ZP2
        tya
        lsr
        tay
        phy
        jsr IsTimeLess
        bcc +                                   ;if player time is less - this is the rank!
        ply
        iny
        cpy #LB_ENTRIES_COUNT
        bne -
        tya                                     ;number of saved miners were same as someone else in the table, but the time was not good enoug
        rts
+       ply
        tya
        rts

SetNewHighScoreName:            ;IN: .A = rank. ZP0-ZP1 = address of new name
        ldx ZP0
        stx .newname
        ldx ZP1
        stx .newname +1
        ldx #<.leaderboard_names
        stx ZP0
        ldx #>.leaderboard_names
        stx ZP1
        jsr GetStringInArray                    ;get current name
        lda ZP0
        sta ZP2
        lda ZP1
        sta ZP3                                 ;ZP2, ZP3 = current name
        lda .newname
        sta ZP0
        lda .newname + 1
        sta ZP1                                 ;ZP1, ZP2 = new name
        lda #LB_NAME_LENGTH
        sta ZP4
        stz ZP5                                 ;ZP4, ZP5 = string length
        jsr CopyMem                             ;update name
        rts

.newname        !byte 0,0

SetNewHighScore:                               ;IN: .A = rank. ZP0-ZP1 = address of new name, ZP2 = saved miners, ZP3-ZP4 = time, ZP5 = start level

        ;store parameters
        sta .newrank
        lda ZP2
        sta .newminers
        lda ZP3
        sta .newtime
        lda ZP4
        sta .newtime+1
        lda ZP5
        sta .newstart  

        ;make room for new record
        lda .newrank
        jsr .MakeRoomInHighScoreTable
       
        ;set saved miners
        +ConvertBinToDec .newminers, .newminers_dec
        lda .newminers_dec
        ldy .newrank
        sta .leaderboard_saved,y

        ;set start level 
        +ConvertBinToDec .newstart, .newstart_dec
        lda .newstart_dec
        ldy .newrank
        sta .leaderboard_start,y
        
        ;set time
        tya
        asl
        tay
        lda .newtime
        sta .leaderboard_times,y
        lda .newtime+1
        sta .leaderboard_times+1,y
        rts

.newrank        !byte 0
.newminers      !byte 0
.newminers_dec  !word 0
.newtime        !byte 0,0
.newstart       !byte 0
.newstart_dec   !word 0

InitHighScoreInput:
        ;get rank
        jsr GetSavedMinersCount ;OUT: .A = number of saved miners
        sta ZP0
        lda _minutes
        sta ZP1
        lda _seconds
        sta ZP2
        jsr GetHighScoreRank    ;IN: ZP0 = number of saved miners, ZP1-ZP2 = time 
        sta .newrank

        ;set new high score (except name)
        jsr GetSavedMinersCount
        sta ZP2
        lda _minutes
        sta ZP3
        lda _seconds
        sta ZP4
        lda _startlevel
        sta ZP5
        lda .newrank
        jsr SetNewHighScore     ;IN: .A = rank. ZP2 = saved miners, ZP3-ZP4 = time, ZP5 = start level
        jsr DisableLayer0
        jsr ClearTextLayer
        jsr PrintLeaderboard    ;print high score table with everything but name
        
        ;init input textbox
        lda .newrank
        asl                     ;take rank times 2 because of empty row between each entry in table when printed
        clc
        adc #LB_ROW+LB_HEADING_COUNT
        sta _row
        lda #LB_NAME_COL
        sta _col
        lda #LB_NAME_LENGTH
        jsr InitInputString
        rts

HighScoreInput:                 ;let player enter name. when finished update high score table and save to disk. OUT: carry set when finished
        jsr InputString         ;receive input and blink cursor. OUT: carry set when finished. ZP0-ZP1 = inputstring
        bcs +                   
        rts
+       lda .newrank
        jsr SetNewHighScoreName
        lda _level
        cmp _leaderboard_start_high
        bcc +
        sta _leaderboard_start_high     ;set new highest allowed start level if player managed to exceed it
+       jsr SaveLeaderboard
        sec
        rts

LoadLeaderboard:
        lda #<.leaderboardname
        sta ZP0
        lda #>.leaderboardname
        sta ZP1
        lda #<.leaderboard
        sta ZP2
        lda #>.leaderboard
        sta ZP3
        lda #LOAD_TO_RAM
        sta ZP4
        lda #FILE_HAS_HEADER
        sta ZP5
        jsr LoadFile            ;call filehandler
        bcc +
        jsr ResetLeaderboard
        jsr SaveLeaderboard     ;if load fails, create a new file
+       rts

SaveLeaderboard:
        lda #<.leaderboardname
        sta ZP0
        lda #>.leaderboardname
        sta ZP1
        lda #<.leaderboard
        sta ZP2
        lda #>.leaderboard
        sta ZP3
        lda #<.leaderboard_end
        sta ZP4
        lda #>.leaderboard_end
        sta ZP5
        jsr SaveFile            ;call filehandler
        rts  

ResetLeaderboard:               ;copy default leaderboard to leaderboard
        lda #<.default_leaderboard
        sta ZP0
        lda #>.default_leaderboard
        sta ZP1
        lda #<.leaderboard
        sta ZP2
        lda #>.leaderboard
        sta ZP3
        lda #.leaderboard_end-.leaderboard
        sta ZP4
        lda #0
        sta ZP5
        jsr CopyMem
        lda #1
        sta _startlevel
        rts

;*** Private ***************************************************************************************

.MakeRoomInHighScoreTable:                      ;Copy rows downwards to make room for new record. IN: .A = rank (zero-indexed)
        sta .makeroom_row
        lda #LB_ENTRIES_COUNT-2                 ;begin with second last index and work upwards
-       pha
        jsr .CopyHighScoreTableRow
        pla
        dec
        cmp .makeroom_row
        bpl -
        rts

.makeroom_row   !byte 0

.CopyHighScoreTableRow:                 ;Copy a row in the high score table down one step.
        cmp #LB_ENTRIES_COUNT-1         ;IN: .A = source row (zero-indexed)
        bcc +                           ;row must be lesser than the last 
        rts             

        ;copy name
+       tay
        phy
        ldx #<.leaderboard_names
        stx ZP0
        ldx #>.leaderboard_names
        stx ZP1
        jsr GetStringInArray            ;address of name in source row now in ZP0, ZP1
        lda ZP0                         
        sta ZP2
        lda ZP1
        sta ZP3
        +Add16I ZP2, LB_NAME_LENGTH+1   ;add name length +1 to get address of next name in ZP2, ZP3
        lda #LB_NAME_LENGTH
        sta ZP4                         ;number of bytes to copy in ZP4
        stz ZP5
        jsr CopyMem                     ;copy

        ;copy saved miners and start level
        ply
        lda .leaderboard_saved,y
        sta .leaderboard_saved+1,y
        lda .leaderboard_start,y
        sta .leaderboard_start+1,y

        ;copy time
        tya
        asl
        tay
        lda .leaderboard_times,y
        sta .leaderboard_times+2,y
        lda .leaderboard_times+1,y
        sta .leaderboard_times+3,y
        rts

.leaderboardname        !raw "@:HIGHSCORES.BIN",0

LB_ROW = 4
LB_NAME_LENGTH = 11
LB_HEADING_COUNT = 3
LB_ENTRIES_COUNT = 10

LB_NAME_COL = 8
LB_MINERS_COL = 22
LB_TIME_COL = 27
LB_START_COL = 34
;
.scoretable             !scr "                    saved       start",0
                        !scr "   rank name        miners time level",0
                        !scr 0
                        !scr "    1st",0
                        !scr "    2nd",0
                        !scr "    3rd",0
                        !scr "    4th",0
                        !scr "    5th",0
                        !scr "    6th",0
                        !scr "    7th",0
                        !scr "    8th",0
                        !scr "    9th",0
                        !scr "   10th",0

.leaderboard_colors             !byte 7,7,0                       ;headings
.leaderboard_table_colors       !byte 2,7,14,5,15,8,4,9,13,10      ;table

.leaderboard            ;data are read from file
.leaderboard_names      !fill LB_ENTRIES_COUNT*(LB_NAME_LENGTH+1),0     ;each name is max 11 chars long (= 12 with 0 to terminate)
.leaderboard_saved      !fill LB_ENTRIES_COUNT,0                        ;number of saved miners
.leaderboard_times      !fill LB_ENTRIES_COUNT*2,0                      ;each time takes 2 bytes (minutes and seconds)
.leaderboard_start      !fill LB_ENTRIES_COUNT,0                        ;start levels
_leaderboard_start_high !byte 0                                         ;highest allowed start level
.leaderboard_end

.default_leaderboard    !scr "roderrick  ",0                    ;names
                        !scr "elvin a    ",0
                        !scr "guybrush   ",0
                        !scr "sandy pantz",0
                        !scr "z mckracken",0
                        !scr "bruce lee  ",0
                        !scr "armakuni   ",0
                        !scr "rockford   ",0
                        !scr "giana      ",0
                        !scr "monty mole ",0

                        !byte 10,9,8,7,5,5,4,3,2,1              ;saved miners
                        !byte 20,0, 18,0, 16,0, 14,0, 12,0      ;times
                        !byte 10,0,  8,0,  6,0,  4,0,  2,0
                        !byte 1,2,3,4,5,6,7,8,9,10              ;start levels

                        !byte 1                                 ;highest allowed start level
