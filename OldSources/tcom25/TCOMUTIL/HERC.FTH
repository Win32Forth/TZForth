\\ HERC.SEQ     Hercules point plotting routines by Wempe

  Hercules graphics support, originally by Wempe, subsequently
modified by Oliver Shank, Mike Mayo, and Tom Zimmer.

  This is a simple two color system, color zero being black, and color
one being white. If you set a color above 127, a point will be drawn
XOR'd with the current pixel.

Requires GRAPH.SEQ
{

FORTH DECIMAL
\tcom TARGET >LIBRARY           \ A TCOM Library file

VARIABLE HERC-SEG   \ segment for Hercules video buffer

\tcom table  GTBL       /nostack1
\fpc  create GTBL
        $35 c, $2D c, $2E c, $07 c, $5B c, $02 c,
        $57 c, $57 c, $02 c, $03 c, $00 c, $00 c,
\tcom end-table

\tcom table  TTBL       /nostack1
\fpc  create TTBL
        $61 c, $50 c, $52 c, $0F c, $19 c, $06 c,
        $19 c, $19 c, $02 c, $0D c, $0B c, $0C c,
\tcom end-table


\tcom table  BIT-MASKS  /nostack1
\fpc  create BIT-MASKS
        $7F c, $BF c, $DF c, $EF c, $F7 c, $FB c, $FD c, $FE c,
\tcom end-table

: SET-HMODE     ( tbl -- )
        12 0 do  i $3B4 pc!  dup c@  $3B5 pc!  1+  loop
        drop  ;

: HPAGED ( p -- ) \ select displaying lower or upper page of video buffer
        0= if  $0A  else  $8A  then
        $3B8 pc!  ;

: HPAGEW ( p -- ) \ select writing to lower or upper page of video buffer
        0= if  $B000  else  $B800  then
        DUP =: VID.SEG  HERC-SEG !   ;

LABEL XY_ADDR   ( x y -- a1:DX )
\tcom           MOV DX, BX              \ y
\tcom           LODSW
\tcom           MOV CX, AX              \ x
        \ y in DX
        \ x in CX
        \ returns bit mask in AL and address in DI
                MOV AX, DX
                SHR AX, # 1
                SHR AX, # 1             \ row/4 in AX
                PUSH DX                 \ y  for later
                MOV BX, # 90
                MUL BX
                MOV DI, AX              \ DI is now row/4 * 90
                MOV AX, CX
                SHR AX, # 1
                SHR AX, # 1
                SHR AX, # 1             \ col/8 in AX
                ADD DI, AX              \ DI is now the byte address
                POP DX
                TEST DX, # 1
             U> IF      ADD DI, # $2000 \ deal with row mod 4
                THEN
                TEST DX, # 2
             U> IF      ADD DI, # $4000
                THEN
                AND CX, # 7
                MOV BX, # BIT-MASKS
                MOV AX, CX
                XLAT                    \ get bit mask
                RET             END-CODE


CODE HPLOT      ( x y -- ) \ turn on pixel at x,y
\fpc            POP DX                  \ y
\fpc            POP CX                  \ x
                CALL XY_ADDR
                MOV CX, COLOR           \ is COLOR zero
                PUSH DS
                MOV DS, HERC-SEG
          CX<>0 IF      NOT AL
                        CMP CX, # 128
                      < IF      OR  0 [DI], AL          \ set   the bit
                        ELSE    XOR 0 [DI], AL          \ xor   the bit
                        THEN
                ELSE    AND 0 [DI], AL                  \ clear the bit
                THEN
\fpc            POP DS
\fpc            NEXT            END-CODE
\tcom           POP DS  LOAD_BX                         \ reload BX
\tcom           RET             END-CODE


CODE HPOINT     ( x y -- n1 )   \ Get status of pixel at x,y
\fpc            POP DX                  \ y
\fpc            POP CX                  \ x
                CALL XY_ADDR
                PUSH DS
                MOV DS, HERC-SEG
                MOV BL, 0 [DI]
                NOT AL
                AND BL, AL              \ mask the bit
                POP DS
\fpc            SUB AH, AH
\fpc            1push           END-CODE
\tcom        0= IF      SUB BX, BX
\tcom           ELSE    MOV BX, # 1
\tcom           THEN
\tcom           RET             END-CODE

: herc-emit ( c -- )
        8 * chartblL +  =: charadr
        G-X 8 /
        G-Y 4 /mod 90 *  swap $2000 * +
        +  ( video-byte-addr )

\ POINTOFFSET       = INT[ROW/4] * 90 + REM[ROW/4]*$2000 + INT[COL/8]
\ PIXEL(1 BIT)ADDR  = REM[COL/8] {WITHIN BYTE}
\ Next bit, step along byte and to next byte.
\ Next row, add $2000, and add 90 when wrapping.

        8 0 do  charseg charadr c@l  incr> charadr
                over herc-seg @ swap c!l
                $2000 +  dup $7FFF u> if 90 + then  $7FFF and
          loop
        drop

        t-width +!> g-x
        hdots g-x - t-width  <= if  g-cr  then
        ;

: htext ( -- ) \ switch from Hercules to text mode
        $20 $3B8 PC!    \ set mode register for text, with video disabled
        ttbl set-hmode
        $28 $3B8 PC!    \ re-enable video
        gtext-off
        ;

: hercules ( -- ) \ switch to Hercules graphics mode
        3 $3BF P!           \ set herc for FULL mode
        $02 $3B8 PC!        \ set mode register for graphics, with video disabled
        gtbl set-hmode
        $8000 =: VID.SIZE   \ Hercules video buffer size
        0 HPAGED            \ display the first graphics page
        0 HPAGEW            \ enable writing to the first graphics page
        720 =: HDOTS
        348 =: VDOTS
          2 =: #COLORS
        1 hpagew
        1 hpaged
        gtext-on    \ switch text words to graphics mode
        ['] herc-emit   is emit
        ['] hplot       is plot
        ['] hpoint      is point
        ['] htext       is text-mode
        ;

\tcom   FORTH TARGET >TARGET

