\ TVIDEO.SEQ                                            by Tom Zimmer

comment:

  Direct video screen write display routine.

  This is not the fastest possible display routine, but it is much better
than the normal DOS output routine. Be sure to call VMODE.SET before using
VTYPE or VIDEO-TYPE, then use VAT to position the cursor instead of AT.

comment;

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

VARIABLE VIDEO-SEG

CODE VIDEO-TYPE ( string length x y -- )
                [ASSEMBLER]
                CMP BX, &> ROWS
            U>= IF      MOV BX, &> ROWS         \ limit line to screen
                        DEC BX                  \ lines minus one
                THEN
                PUSH BX                         \ preserve row
                MOV AX, BX
                MOV DX, 0 [SI]                  \ copy of column
                MOV BX, 2 [SI]
                ADD DX, BX      MOV DH, AL
                SUB BX, BX
                MOV AH, # 2
                INT $10
                POP BX                          \ recover row
                MOV AX, &> COLS
                SHL AX, # 1
                MUL BX
                MOV DI, AX
                LODSW           SHL AX          \ get col
                ADD DI, AX                      \ actual destination address
                LODSW           MOV CX, AX      \ get string length
                LODSW           MOV BX, AX      \ get source address
                XCHG DI, BX                     \ exchange src/dest
          CX<>0 IF      MOV DX, ES
                        MOV ES, VIDEO-SEG       \ destination address
                        MOV AH, ATTRIB          \ load attribute into AH
                        0 $:    MOV AL, 0 [DI]
                                MOV ES: 0 [BX], AX
                                INC DI
                                INC BX
                                INC BX
                        LOOP    0 $
                        MOV ES, DX
                THEN
                LODSW
                MOV BX, AX
                RET             END-CODE

: %VTYPE        ( addr len -- )
                PRINTING @
                IF      %TYPE
                ELSE    TUCK #OUT @ #LINE @ VIDEO-TYPE #OUT +!
                THEN    ;

: %VSPACES      ( n1 -- )       \ Display n1 spaces up to 132
                0MAX 132 MIN
                "         " DROP        \ a buffer of 8 spaces
                SWAP 8 /MOD 0
                ?DO     OVER 8 %VTYPE
                LOOP    %VTYPE ;

: %VEMIT        ( c1 -- )
                PRINTING @
                IF      (EMIT)
                ELSE    SP@ 1 %VTYPE DROP
                THEN    ;

: %VCRLF        ( -- )
                $0D (EMIT) $0A (EMIT)
                #OUT OFF #LINE INCR ;

: NORM-DARK     ( --- )
                VIDEO-SEG @ 0 ROWS COLS 2* *
                ATTRIB C@ FLIP $20 OR LFILLW
                0 0 AT ;

: VIDEOIO_INIT  ( -- )          \ initialize the direct video system
                DECIMAL                         \ really need a default base
                ?VMODE 7 =
                IF      $0B000
                ELSE    ROW/COL_SET
                        $0B800
                THEN VIDEO-SEG !
                7 ATTRIB !
                PRINTING OFF ;

: FAST          ( -- )          \ select fast video routines
                VIDEOIO_INIT
                ['] %VCRLF    !> CR
                ['] IBM-AT?   !> AT?
                ['] IBM-AT    !> AT
                ['] %KEY      !> KEY
                ['] %VEMIT    !> EMIT
                ['] %VTYPE    !> TYPE
                ['] %VSPACES  !> SPACES
                ['] NORM-DARK !> DARK
                AT? AT ;

: VMODE.SET     ( --- )         \ must be done during initialization
                VIDEOIO_INIT FAST ;

: >NORM         ( --- ) $07 ATTRIB ! ;          \ NORMAL
: >REV          ( --- ) $78 ATTRIB ! ;          \ REVERSE
: >UL           ( --- ) $01 ATTRIB ! ;          \ UNDERLINE
: >BOLD         ( --- ) $7F ATTRIB ! ;          \ BRIGHT
: >BOLDUL       ( --- ) $79 ATTRIB ! ;          \ BOLD UNDERLINE
: >BOLDBLNK     ( --- ) $8F ATTRIB ! ;          \ BOLD BLINK
: >REVBLNK      ( --- ) $F0 ATTRIB ! ;          \ REVERSE BLINK

CODE BLINKOFF   ( -- )
                SAVE_BX
                MOV AX, # $1003
                MOV BL, # $00           \ DISABLE BLINK
                INT $10
                LOAD_BX
                RET     END-CODE

CODE BLINKON    ( -- )
                SAVE_BX
                MOV AX, # $1003
                MOV BL, # $01           \ ENABLE BLINK
                INT $10
                LOAD_BX
                RET     END-CODE

FORTH TARGET >TARGET

