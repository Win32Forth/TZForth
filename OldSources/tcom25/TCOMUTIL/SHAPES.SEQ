\\ Circle and Arc drawing for TCOM & F-PC.  Credit for this and other parts
   of the graphics support in TCOM goes to all of the following people:

        Wempe
        Oliver Shank
        Keith Gunn
        John Bumgarner
        Tom Zimmer
        Mike Mayo

{

\tcom   FORTH DECIMAL TARGET >LIBRARY       \ A Library file

( TRIG APPROXIMATIONS - by J. BUMGARNER              ODS01JUL87)

\tcom   TABLE  SINTBL    /nostack1
\fpc    CREATE SINTBL
     0 ,   174 ,   348 ,   522 ,   697 ,   870 ,  1045 ,  1218 ,
  1391 ,  1563 ,  1736 ,  1907 ,  2078 ,  2250 ,  2418 ,  2587 ,
  2755 ,  2923 ,  3089 ,  3255 ,  3419 ,  3583 ,  3745 ,  3907 ,
  4066 ,  4226 ,  4382 ,  4539 ,  4693 ,  4847 ,  4999 ,  5150 ,
  5298 ,  5446 ,  5592 ,  5735 ,  5877 ,  6017 ,  6155 ,  6292 ,
  6427 ,  6559 ,  6690 ,  6819 ,  6946 ,  7070 ,  7193 ,  7314 ,
  7431 ,  7546 ,  7659 ,  7771 ,  7879 ,  7985 ,  8089 ,  8191 ,
  8290 ,  8386 ,  8480 ,  8571 ,  8659 ,  8746 ,  8829 ,  8910 ,
  8986 ,  9062 ,  9134 ,  9204 ,  9271 ,  9336 ,  9397 ,  9455 ,
  9511 ,  9562 ,  9612 ,  9616 ,  9702 ,  9743 ,  9780 ,  9814 ,
  9846 ,  9876 ,  9903 ,  9926 ,  9945 ,  9963 ,  9974 ,  9986 ,
  9993 ,  9997 , 10000 ,
\tcom   END-TABLE

CODE ISIN       ( n1-degrees ---, n2-sine*10K )
\fpc            POP BX
                XOR CX, CX
                MOV DX, # $168
                BEGIN   CMP BX, CX
             <  WHILE   ADD BX, DX
                REPEAT
                BEGIN   CMP BX, DX
             >= WHILE   SUB BX, DX
                REPEAT
                MOV DX, # $B4
                CMP DX, BX
              < IF      INC CX
                        SUB BX, DX
                THEN
                MOV AX, # $5A
                CMP AX, BX
              < IF      SUB DX, BX
                        MOV BX, DX
                THEN
                SHL BX, # 1
                ADD BX, # SINTBL
                MOV AX, 0 [BX]
                CMP CX, # 0
            0<> IF      NEG AX
                THEN
\tcom           MOV BX, AX
\tcom           RET
\fpc            1PUSH
                END-CODE

: ICOS  NEGATE 90 + ISIN ;

\ DEGS XI>P YI>P                                OODS01JUL87

    0 VALUE    ?PIXELS          \ pixels or inches for radius, true=pixels
    9 VALUE    DEGS             \ 9  degrees per segment res/speed tradeoff
10000 CONSTANT 10K              \ scale factor for SIN and COS functions

: !PIXELS!      ( -- )          \ select a pixel for radius
                ON> ?PIXELS ;

: !INCHES!      ( -- )          \ select an inches*10 for radius
                OFF> ?PIXELS ;

: XI>P          ( -- )
                ?PIXELS ?EXIT
                HDOTS 100 */ ;           \ horizontal inches to pixels

: YI>P          ( n1 -- n2 )
                ?PIXELS ?EXIT
                VDOTS 100 */ ;           \ vertical   inches to pixels

\ DOARC  CIRCLE  ARC                            1/ODS04JUL87

: DOARC         ( ??????? -- )
                DO      2 PICK OVER   XI>P I ICOS 10K */ +
                        2 PICK 2 PICK YI>P I ISIN 10K */ +
                        LINETO DEGS
                +LOOP 2DROP DROP ;

                \ HDOTS 2/ VDOTS 2/ RADIUS -- puts cir. in center
                \ RADIUS is in inches*10 or pixels depending on the use
                \ of the words !PIXELS! and !INCHES!. Default is inches*10
: CIRCLE        ( x y radius -- )
                2 PICK OVER XI>P 0 ICOS 10K */ + 2 PICK MOVETO
                361 DEGS DOARC ;

                \ For RADIUS information, see CIRCLE above.
: ARC           ( x y radius start-ang end-ang -- )
                >R >R
                2 PICK OVER   XI>P R@ ICOS 10K */ +
                2 PICK 2 PICK YI>P R@ ISIN 10K */ + MOVETO
                R> DEGS + R> 1+ SWAP DOARC ;

\tcom   FORTH TARGET >TARGET

