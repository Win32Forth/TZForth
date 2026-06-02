\ LIBRARY.SEQ           Target Library Source           by Tom Zimmer

\ Version for 80c196 by Mike Mayo

\ ***************************************************************************
\ Target specific words used by the compiler to complete compilation of
\ the the various types of library and target definitions.  These words
\ will need to be re-written when a new traget is being written.

\ ***************************************************************************
\                       Target Library words
\ ***************************************************************************

>LIBRARY

TARGET DEFINITIONS

\ ***************************************************************************
\ This macro puts a literal number on the data stack. The instructon
\ sequence used is not optimal, but is likely to be optimized later by the
\ automatic SAVE_BX optimizer.

MACRO (LIT)     ( n1 -- )       \ Special macro to compile an inline number
                SAVE_TTOS       \ to the stack.
                [FORTH]
                HERE-T IMM-HERE !
                [ASM96]
                LD TTOS #    swap A;
        END-MACRO       NO-INTERPRET

' (LIT) >EXECUTE IS COMP_SINGLE \ link into number compiler


CODE EXEC:     ( n1 -- )       \ execute the n-th CALL following EXEC:
                                \ MUST be followed by CALL's, not MACROS
                LD      W0 TTOS
                SHL     W0 # 1
                ADD     W0 TTOS         \ n1 * 3
                ADD     W0 []+ SP       \ POP and add the return address
                INC     W0              \ W0 now points to the CALL address
                LOAD_TTOS
                LDB     W2 []+ W0
                LDB     W3 []+ W0
                ADD     W0 W2
                BR[]    W0      \ jump where the CALL instruction would go
        END-CODE        NO-INTERPRET


CODE BOUNDS    ( n1 n2 --- n3 n4 )  \ Calculate limits used in DO-loop
                LD      W0 [] PSP
                ADD     TTOS W0
                ST      TTOS [] PSP
                LD      TTOS W0
                RET
        END-CODE        NO-INTERPRET

MACRO ?EXIT     ( f1 -- )       \ If boolean f1 is true, exit from definition.
                LD      W0 TTOS
                LD      TTOS []+ PSP
                OR      W0 W0
                [ASM96]
            0<> IF      RET
                THEN            END-MACRO       NO-INTERPRET

MACRO EXIT      ( -- )          \ Terminate a high-level definition
                RET             END-MACRO       NO-INTERPRET


MACRO BEGIN     ( -- )
                +BR# $:         END-MACRO       NO-INTERPRET

MACRO AGAIN     ( -- )          \ an unconditional branch
                LJMP -BR# DUP $  01LAB
                                END-MACRO       NO-INTERPRET

MACRO IF        ( f -- )        \ branch if flag is zero
                LD      W0 TTOS
                LOAD_TTOS
                OR      W0 W0
                [ASM96]
                JNE here 5 +    A;      \ branch around JMP
                LJMP +BR# $     A;
                [FORTH]
                [ASM96]     END-MACRO       NO-INTERPRET

TARGET ' IF ALIAS WHILE     ( f1 -- )

MACRO ELSE      ( -- )
                LJMP +BR# $ A;
                BR#SWAP
                -BR# DUP $:  01LAB A;
                END-MACRO       NO-INTERPRET

MACRO THEN      ( -- )          \ resolve branch
                -BR# DUP $:  01LAB A;
                END-MACRO       NO-INTERPRET

' THEN ALIAS ENDIF


FORTH   >FORTH

MACRO REPEAT    ( -- )
                BR#SWAP
                LJMP -BR# DUP $   01LAB
                     -BR# DUP $:  01LAB
                END-MACRO                       NO-INTERPRET

MACRO UNTIL     ( f1 -- )
                LD      W0 TTOS
                LD      TTOS []+ PSP
                OR      W0 W0
                JNE here 5 +    A;      \ branch around JMP
                LJMP -BR# DUP $ 01LAB A;
        END-MACRO       NO-INTERPRET

MACRO FOR       ( n1 -- )
                PUSH    TTOS
                LOAD_TTOS
                +BR# $:
        END-MACRO       NO-INTERPRET

MACRO NEXT      ( -- )
                POP     W0
                OR      W0 W0
            0<> IF
                        DEC W0
                        PUSH W0
                        LJMP -BR# DUP $  01LAB
                THEN            END-MACRO       NO-INTERPRET

MACRO UNDO      ( --- )
                ADD SP # 4     END-MACRO       NO-INTERPRET

MACRO DO        ( l i -- )
                [FORTH]
                ?DOING   OFF
                [ASM96]
                LD      W0 []+ PSP
                ADD     W0 # $8000
                PUSH    W0
                SUB     TTOS W0
                PUSH    TTOS
                LOAD_TTOS
                +BR# $:
        END-MACRO       NO-INTERPRET

MACRO (LOOP)    ( -- )
                LD      W0 [] SP
                INC     W0
                ST      W0 [] SP
                JV here 5 +             A;      \ branch around JMP
                LJMP -BR# DUP $ 01LAB   A;
        END-MACRO       NO-INTERPRET

MACRO (+LOOP)   ( n -- )
                ADD     TTOS [] SP
                ST      TTOS [] SP
                LD      TTOS []+ PSP
                JV here 5 +             A;      \ branch around JMP
                JMP -BR# DUP $ 01LAB   A;
        END-MACRO       NO-INTERPRET

MACRO DO?       ( -- )
                -BR# DUP $:  01LAB
                [FORTH]
                ?DOING OFF      END-MACRO       NO-INTERPRET

MACRO LEAVE?    ( -- )
                20 DUP $:  01LAB
                [FORTH]
                ?LEAVING DECR   END-MACRO       NO-INTERPRET

FORTH   >FORTH

: %LOOP         ( -- )
                ['] (LOOP) >EXECUTE EXECUTE
                [FORTH]
                ?LEAVING @
                IF      ['] LEAVE? >EXECUTE EXECUTE
                THEN
                [TARGET]
                ['] UNDO >EXECUTE EXECUTE
                [FORTH]
                ?DOING @
                IF      ['] DO? >EXECUTE EXECUTE
                THEN
                [TARGET]
                ;

FORTH

: LOOP          ( -- )
                [FORTH]
                ?LIB
                IF      COMPILE %LOOP
                ELSE    %LOOP
                THEN
                [TARGET]
                ; IMMEDIATE

FORTH

: %+LOOP        ( -- )
                ['] (+LOOP) >EXECUTE EXECUTE
                [FORTH]
                ?LEAVING @
                IF      ['] LEAVE? >EXECUTE EXECUTE
                THEN
                [TARGET]
                ['] UNDO >EXECUTE EXECUTE
                [FORTH]
                ?DOING @
                IF      ['] DO? >EXECUTE EXECUTE
                THEN
                [TARGET]
                ;

FORTH

: +LOOP         ( -- )
                [FORTH]
                ?LIB
                IF      COMPILE %+LOOP
                ELSE    %+LOOP
                THEN
                [TARGET]
                ; IMMEDIATE

TARGET  >LIBRARY

MACRO LEAVE     ( -- )
                [FORTH] ?LEAVING INCR [ASM96]
                LJMP 20 $         END-MACRO       NO-INTERPRET

MACRO ?LEAVE    ( f -- )
                [FORTH] ?LEAVING INCR [ASM96]
                LD      W0 TTOS
                LOAD_TTOS
                OR      W0 W0
                JE here 5 +             A;      \ branch around JMP
                JMP 20 $                A;
        END-MACRO       NO-INTERPRET

MACRO I        ( -- n )
                SAVE_TTOS
                LD      TTOS [] SP
                ADD     TTOS [I] 2 SP
        END-MACRO       NO-INTERPRET

MACRO J         ( -- n )
                SAVE_TTOS
                LD      TTOS [I] 4 SP
                ADD     TTOS [I] 6 SP
        END-MACRO       NO-INTERPRET

MACRO K         ( -- n )
                SAVE_TTOS
                LD      TTOS [I] 8 SP
                ADD     TTOS [I] 10 SP
        END-MACRO       NO-INTERPRET



MACRO @         ( addr -- n )
                ld      ttos [] ttos
                END-MACRO       EXECUTES> @

' @ >EXECUTE IS COMP_FETCH              \ link into compiler

MACRO !         ( n addr -- )
                LD      W0 []+ PSP
                ST      W0 [] TTOS
                LOAD_TTOS
                END-MACRO       EXECUTES> !

' ! >EXECUTE IS COMP_STORE      \ link to compiler

MACRO %SAVE>R   ( a1 -- )
                LD      W0 [] TTOS
                PUSH    W0
                LOAD_TTOS
                END-MACRO       NO-INTERPRET

' %SAVE>R >EXECUTE IS COMP_SAVE


MACRO C@        ( addr -- char )
                LDB     TTOS [] TTOS
                CLRB    TTOSH
                END-MACRO       EXECUTES> C@

MACRO C!        ( char addr -- )
                LD      W0 []+ PSP
                STB     W0 [] TTOS
                LOAD_TTOS
                END-MACRO       EXECUTES> C!

\ MACRO DEPTH     ( -- n1 )
\                 SAVE_TTOS
\                 LD      TTOS PSP
\                 SUB     TTOS PSP0
\                 SHR     TTOS # 1
\                 END-MACRO       EXECUTES> DEPTH

MACRO SP@       ( -- n )
                SAVE_TTOS
                LD      TTOS PSP
                END-MACRO       NO-INTERPRET

MACRO SP!       ( n -- )
                LD      PSP TTOS
                END-MACRO       NO-INTERPRET

MACRO RP@       ( -- addr )
                SAVE_TTOS
                LD      TTOS SP
                END-MACRO       NO-INTERPRET

MACRO RP!       ( n -- )
                LD      SP TTOS
                LOAD_TTOS         END-MACRO       NO-INTERPRET

MACRO DROP      ( n1 -- )
                LOAD_TTOS         END-MACRO       EXECUTES> DROP

MACRO DUP       ( n1 -- n1 n1 )
                SAVE_TTOS
        END-MACRO       EXECUTES> DUP

MACRO SWAP      ( n1 n2 -- n2 n1 )
                LD      W0 [] PSP
                ST      TTOS [] PSP
                LD      TTOS W0
        END-MACRO       EXECUTES> SWAP

MACRO OVER      ( n1 n2 -- n1 n2 n1 )
                SAVE_TTOS
                LD      TTOS [I] 2 PSP
        END-MACRO       EXECUTES> OVER


MACRO PLUCK     ( n1 n2 n3 --- n1 n2 n3 n1 )
                SAVE_TTOS
                LD      TTOS [I] 4 PSP
        END-MACRO       NO-INTERPRET

CODE TUCK       ( n1 n2 -- n2 n1 n2 )
                LD      W0 [] PSP
                SUB     PSP # 2
                ST      W0 [] PSP
                ST      TTOS [I] 2 PSP
                RET             END-CODE        EXECUTES> TUCK

MACRO NIP       ( n1 n2 -- n2 )
                ADD     PSP # 2
                END-MACRO       EXECUTES> NIP

CODE ROT        ( n1 n2 n3 --- n2 n3 n1 )
                LD  W0 [I] 2 PSP  \ get n1
                LD  W2 [] PSP     \ get n2
                ST  TTOS [] PSP   \ store n3
                ST  W2 [I] 2 PSP  \ store n2
                LD  TTOS W0       \ store n1
                RET             END-CODE        EXECUTES> ROT

CODE -ROT       ( n1 n2 n3 --- n3 n1 n2 )
                LD  W0 [I] 2 PSP    \ get n1
                LD  W2 [] PSP       \ get n2
                ST  TTOS [I] 2 PSP  \ store n3
                ST  W0 [] PSP       \ store n1
                LD  TTOS W0         \ store n2
                RET             END-CODE        EXECUTES> -ROT

MACRO FLIP      ( n1 -- n2 )
                LD      W0 TTOS
                LDB     TTOS W1
                LDB     TTOSH W0
                END-MACRO       EXECUTES> FLIP

CODE SPLIT      ( n1 --- n2 n3 )
                LD      W0 TTOS
                CLR     TTOSH
                SAVE_TTOS
                LDB     TTOS W1
                RET             END-CODE        EXECUTES> SPLIT

MACRO ?DUP      ( n1 -- [n1] n1 )
                OR  TTOS TTOS
                [ASM96]
            0<> IF      SAVE_TTOS
                THEN            END-MACRO       EXECUTES> ?DUP

MACRO R>        ( -- n )
                SAVE_TTOS
                POP TTOS        END-MACRO       NO-INTERPRET

MACRO R>DROP   ( --- )
                ADD SP # 2      END-MACRO

MACRO DUP>R    ( n1 --- n1 )
                PUSH TTOS       END-MACRO

MACRO >R       ( n -- )
                PUSH TTOS
                LOAD_TTOS       END-MACRO

MACRO 2R>      ( -- n1 n2 )
                SAVE_TTOS
                POP TTOS
                SAVE_TTOS
                POP TTOS        END-MACRO

MACRO 2>R      ( n1 n2 -- )
                PUSH TTOS
                LOAD_TTOS
                PUSH TTOS
                LOAD_TTOS       END-MACRO

MACRO R@       ( -- n )
                SAVE_TTOS
                LD  TTOS [] SP  END-MACRO

MACRO 2R@      ( -- n1 n2 )
                SAVE_TTOS
                LD  TTOS [] SP
                SAVE_TTOS
                LD  TTOS [I] 2 SP       END-MACRO

MACRO PICK      ( nm ... n2 n1 k -- nm ... n2 n1 nk )
                SHL  TTOS # 1
                ADD  TTOS PSP
                LD   TTOS [I] -2 TTOS
                        END-MACRO       NO-INTERPRET

MACRO RPICK    ( nm ... n2 n1 k -- nm ... n2 n1 nk )
                SHL  TTOS # 1
                ADD  TTOS SP
                LD   TTOS [I] -2 TTOS
                        END-MACRO

MACRO AND       ( n1 n2 -- n3 )
                AND     TTOS []+ PSP
                END-MACRO       EXECUTES> AND

MACRO OR        ( n1 n2 -- n3 )
                OR      TTOS []+ PSP
                END-MACRO       EXECUTES> OR

MACRO NOT       ( n -- n' )
                NOT     TTOS
                END-MACRO       EXECUTES> NOT

MACRO CSET     ( b addr -- )
                LDB  W0 []+ PSP
                ORB  W0 [] TTOS
                STB  W0 [] TTOS
                LOAD_TTOS         END-MACRO

MACRO CRESET   ( b addr -- )
                LDB  W0 []+ PSP
                NOTB  W0
                ANDB  W0 [] TTOS
                STB  W0 [] TTOS
                LOAD_TTOS         END-MACRO

MACRO CTOGGLE  ( b addr -- )
                LDB     W0 [] TTOS
                XORB    W0 []+ PSP
                STB     W0 [] TTOS
                LOAD_TTOS         END-MACRO

MACRO ON        ( addr -- )
                LD      W0 # $0FFFF
                ST      W0 [] TTOS
                LOAD_TTOS
                END-MACRO       NO-INTERPRET

' ON  >EXECUTE IS COMP_ON         \ link to compiler

MACRO OFF       ( addr -- )
                ST      0 [] TTOS
                LOAD_TTOS
                END-MACRO       NO-INTERPRET

' OFF >EXECUTE IS COMP_OFF        \ link to compiler

MACRO INCR      ( addr --- )
                LD      W0 [] TTOS
                INC     W0
                ST      W0 [] TTOS
                LOAD_TTOS
                END-MACRO       NO-INTERPRET

' INCR >EXECUTE IS COMP_INCR       \ link to compiler

MACRO DECR      ( addr --- )
                LD      W0 [] TTOS
                DEC     W0
                ST      W0 [] TTOS
                LOAD_TTOS
                END-MACRO       NO-INTERPRET

' DECR >EXECUTE IS COMP_DECR       \ link to compiler


MACRO +         ( n1 n2 -- sum )
                ADD     TTOS []+ PSP
                END-MACRO       EXECUTES> +


MACRO NEGATE    ( n -- n' )
                NEG TTOS        END-MACRO       EXECUTES> NEGATE

MACRO -         ( n1 n2 -- n1-n2 )
                SUB     TTOS []+ PSP
                NEG     TTOS
                END-MACRO       EXECUTES> -

MACRO ABS       ( n1 -- n2 )
                LDBSE   W0 TTOSH        \ get sign of TTOS in W1
                LDB     W0 W1           \ and W0
                XOR     TTOS  W0        \ complement TTOS if negative
                SUB     TTOS  W0        \ and add 1 if TTOS was negative
                END-MACRO       EXECUTES> ABS

MACRO 2*        ( n -- 2*n )
                SHL ttos # 1    END-MACRO       EXECUTES> 2*

MACRO 4*        ( n -- 2*n )
                SHL ttos # 1
                SHL ttos # 1    END-MACRO       NO-INTERPRET

MACRO 2/        ( n -- n/2 )
                SHRA TTOS # 1   END-MACRO       EXECUTES> 2/

MACRO U2/       ( u -- u/2 )
                SHR TTOS # 1    END-MACRO       EXECUTES> U2/

ICODE U16/      ( u -- u/16 )
                SHR TTOS # 1     SHR TTOS # 1
                SHR TTOS # 1     SHR TTOS # 1
                RET             END-ICODE

ICODE U8/       ( u -- u/8 )
                SHR TTOS # 1
                SHR TTOS # 1
                SHR TTOS # 1
                RET             END-ICODE

ICODE 8*        ( n -- 8*n )
                SHL TTOS # 1
                SHL TTOS # 1
                SHL TTOS # 1
                RET             END-ICODE

MACRO 1+        ( n1 --- n2 )
                INC TTOS        END-MACRO       EXECUTES> 1+

MACRO 2+        ( n1 --- n2 )
                ADD TTOS # 2    END-MACRO      EXECUTES> 2+

MACRO 1-        ( n1 --- n2 )
                DEC TTOS        END-MACRO       EXECUTES> 1-

MACRO 2-        ( n1 --- n2 )
                SUB TTOS # 2    END-MACRO      EXECUTES> 2-

MACRO *         ( n1 n2 -- n3 )
\                LD      W0 []+ PSP
\                CLR     W2
\                MUL     W0 TTOS
\                CLR     TTOS+
                CLR     W2
                MUL     W0  <-- TTOS  []+ PSP
                LD      TTOS W0
                END-MACRO       EXECUTES> *

MACRO 0=        ( n -- f )
                SUB TTOS # 1
                SUBC TTOS TTOS  END-MACRO       EXECUTES> 0=

MACRO 0<        ( n -- f )
                BITSET TTOSH 7 IF  LD TTOS # -1
                             ELSE  CLR TTOS
                             THEN
\                MOV AX, BX
\                CWD
\                MOV BX, DX
                END-MACRO       EXECUTES> 0<

\ MACRO U<        ( n1 n2 -- f )
\         LD      W0 []+ PSP
\         SUB     W0 TTOS
\         SUBC    W0 W0
\         LD      TTOS W0
\         END-MACRO       NO-INTERPRET

MACRO /         ( num den --- quot )
                LD      W0 []+ PSP
                CLR     W2
                DIV     W0 TTOS
                LD      TTOS W0
                END-MACRO       EXECUTES> /

CODE FILL      (  start-addr count char -- )
                LD      W2 []+ PSP
                LD      W0 []+ PSP
        1 $:
                STB     TTOS []+ W0
                DEC     W2
                JNE     1 $
                LOAD_TTOS
                RET             END-CODE

: ERASE         ( addr len -- )
                0 FILL   ;                      NO-INTERPRET

$20 CONSTANT BL                 \ a blank

: BLANK         ( addr len -- )
                BL FILL   ;                     NO-INTERPRET

>FORTH

