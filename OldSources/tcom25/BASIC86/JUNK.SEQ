REM  A simple basic attribute screen clear routine

command debug @next
HERE:   FOR J = 1 TO 15 STEP 1
        FOR I = 1 TO 3999 STEP 2
                POKE $0B800:I,J : REM video attributes = the value of "J"
                POKE $0B800:4000-I,J*16
                FOR I = 1 TO 30 : NEXT
        NEXT
        NEXT
        IF INKEY$=0 THEN GOTO HERE
        FOR I = 1 TO 3999 STEP 2
                POKE $0B800:I,7  : REM restore video attributes to normal
        NEXT
        END

