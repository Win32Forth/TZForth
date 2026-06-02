\ LIB5.SEQ            6805 Target Library Source        by Andrew McKewan

\ ***************************************************************************
\ Target specific words used by the compiler to complete compilation of
\ the the various types of library and target definitions.  These words
\ will need to be re-written when a new traget is being written.

HEAD2 HEX
HEAD2 DECIMAL

\ ***************************************************************************
\                       Target Library words
\ ***************************************************************************

\ **********************************************************************
\ ,+JUMP and ,-JUMP
\ **********************************************************************

>FORTH

: ,-JUMP        ( -- )
                a; ?LONG   [FORTH]
                IF      [ASM6805]
                        jmp     -br# dup>r  $ extended a; r> 01lab
                        [FORTH]
                ELSE    [ASM6805]
                        jmp     -br# dup>r $ a; r> 01lab
                        [FORTH]
                THEN    ?long_set ;

: ,+JUMP        ( -- )
                ?LONG   [FORTH]
                IF      [ASM6805]
                        jmp     +br# $ extended a;
                        [FORTH]
                ELSE    [ASM6805]
                        jmp     +br# $          a;
                        [FORTH]
                THEN    ?long_set ;

>LIBRARY

TARGET DEFINITIONS

\ ***************************************************************************
\ This macro puts a literal number on the data stack. The instructon
\ sequence used is not optimal, but is likely to be optimized later by the
\ automatic POP optimizer.

MACRO (LIT)     ( n1 -- )       \ Special macro to compile an inline number
                >R
                LDA # r>        \ to the stack.
                PUSH
                END-MACRO       NO-INTERPRET

' (LIT) >EXECUTE IS COMP_SINGLE \ link into number compiler


MACRO EXIT      ( -- )
                EXIT_OPT        END-MACRO       NO-INTERPRET

MACRO ?EXIT     ( f1 -- )       \ If boolean f1 is true, exit from definition
                POP
                TST A
                BNE 0 $
                RTS
          0 $:  END-MACRO       NO-INTERPRET

\ ***************************************************************************
\ Compiler Control Structures

LMACRO BEGIN    ( -- )
                +BR# $:
                OPT_OFF1
                7
                END-LMACRO      NO-INTERPRET

LMACRO AGAIN     ( -- )          \ an unconditional branch back to BEGIN
                7 ?pairs        \ check for conditional branch pairing
                ,-jump
                ?REOPT
                END-LMACRO       NO-INTERPRET

LMACRO IF       ( f -- )        \ branch if flag is zero
                POP
                TST A
                [FORTH]
                ?LONG
                IF      [ASM6805]
                        BEQ 0 $    A;
                        ,+JUMP
                   0 $: A;
                        [FORTH]
                ELSE    [ASM6805]
                        BNE +br# $ A;
                        [FORTH]
                THEN    ?REOPT
                3                               \ return matching pair 3
                END-LMACRO       NO-INTERPRET

\ TARGET ' IF ALIAS WHILE     ( f1 -- )
LMACRO WHILE     ( f1 -- )
                7 ?pairs
                [TARGET]
                f['] IF >execute execute
                drop 8
                END-LMACRO       NO-INTERPRET

LMACRO ELSE      ( -- )          \ ELSE portion of IF ELSE THEN conditionals
                3 ?pairs                \ check for matching previous IF
                ,+jump
                BR#SWAP
                -br# dup $:  01lab
                ?REOPT
                3                       \ return pair match value 3
                END-LMACRO       NO-INTERPRET

LMACRO THEN      ( -- )          \ resolve branch
                3 ?pairs                \ check matching branch type
                -br# dup $:  01lab
                OPT_OFF1
                END-LMACRO       NO-INTERPRET

' THEN ALIAS ENDIF

LMACRO REPEAT    ( -- )          \ branch back portion of BEGIN WHILE REPEAT
                8 ?pairs        \ conditional match check
                br#swap                                         \ r:0
                ,-jump
                -br# dup $:  01lab
                ?REOPT
                END-LMACRO       NO-INTERPRET

LMACRO UNTIL     ( f1 -- )       \ conditional branch back of BEGIN UNTIL
                7 ?pairs        \ check branch pairing
                POP
                TST A
                BNE 0 $ A;
                ,-jump  A;
           0 $:         A;
                ?REOPT
                END-LMACRO       NO-INTERPRET

\ ***************************************************************************
\ Runtime Primatives for for/next loop

CODE (FOR)      ( n -- )
                LDA %LOOP 1+
                STA %LOOP 2+
                LDA %LOOP
                STA %LOOP 1+
                POP
                STA %LOOP
                RTS             END-CODE

CODE (NEXT)     ( -- )
                LDA %LOOP 1+
                STA %LOOP
                LDA %LOOP 2+
                STA %LOOP 1+
                RTS             END-CODE

LMACRO FOR      ( n1 -- )
                F['] (FOR) res_comp_call        \ TARG_COMPILE
                +BR# $:
                OPT_OFF1
                5
                END-LMACRO      NO-INTERPRET

LMACRO NEXT     ( -- )
                5 ?pairs        \ check for matching previous FOR
                DEC %LOOP
                BNE -br# dup>r $ a; r> 01lab
                F['] (NEXT) res_comp_call       \ TARG_COMPILE
                ?REOPT
                END-LMACRO       NO-INTERPRET

LMACRO I        ( -- n )
                LDA %LOOP
                PUSH
                END-LMACRO       NO-INTERPRET

\ LMACRO LEAVE    ( -- )          \ LEAVE forces an exit at the end
\                                 \ of the loop by setting the index to 1.
\                 LDA # 1
\                 STA %LOOP
\                 END-LMACRO       NO-INTERPRET


\ ***************************************************************************
\ Stack Operators

LMACRO DROP     ( n1 -- )
                INC X
                END-LMACRO       EXECUTES> DROP

LMACRO DUP      ( n1 -- n1 n1 )
                [FORTH]
                PUSH_OPT
                IF      [ASM6805]
                        PUSH
                        PUSH
                        [FORTH]
                ELSE    [ASM6805]
                        LDA 0 X
                        PUSH
                        [FORTH]
                THEN    [TARGET]
                END-LMACRO       EXECUTES> DUP

CODE SWAP       ( n1 n2 -- n2 n1 )
                LDA 0 X
                STA TEMP
                LDA 1 X
                STA 0 X
                LDA TEMP
                STA 1 X
                RTS             END-CODE        EXECUTES> SWAP

LMACRO OVER     ( n1 n2 -- n1 n2 n1 )
                LDA 1 X
                PUSH
                END-LMACRO      EXECUTES> OVER

CODE ROT        ( n1 n2 n3 -- n2 n3 n1 )
                LDA 0 X
                STA TEMP
                LDA 1 X
                STA TEMP 1+
                LDA 2 X
                STA 0 X
                LDA TEMP
                STA 1 X
                LDA TEMP 1+
                STA 2 X
                RTS             END-CODE        EXECUTES> ROT

LMACRO NIP      ( n1 n2 -- n2 )
                POP
                STA 0 X
                END-LMACRO       EXECUTES> NIP

CODE TUCK       ( n1 n2 -- n2 n1 n2 )
                LDA 0 X
                STA TEMP
                LDA 1 X
                STA 0 X
                LDA TEMP
                STA 1 X
                PUSH
                RTS             END-CODE        EXECUTES> TUCK

CODE ?DUP       ( n -- n | n n )
                LDA 0 X
                BEQ 0 $         \ 0= NOT IF,
                PUSH
                                \ THEN,
        0 $:    RTS             END-CODE        EXECUTES> ?DUP

CODE (PICK)     ( n1 -- n2 )
                STX TEMP
                LDA 0 X
                ADD TEMP
                TAX
                LDA 1 X
                LDX TEMP
                STA 0 X
                RTS             END-CODE

LMACRO PICK     ( n1 -- n2 )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6805]
                        LDA R> ( xxx ) X
                        [FORTH]
                        PUSH
                ELSE
                        F['] (PICK) res_comp_call \ TARG_COMPILE
                THEN
                [TARGET]        END-LMACRO      NO-INTERPRET

\ ***************************************************************************
\ Double stack operators

LMACRO 2DROP    ( n1 n2 -- )
                INC X
                INC X
                END-LMACRO       EXECUTES> 2DROP

CODE 2DUP       ( n1 n2 -- n1 n2 n1 n2 )
                LDA 1 X
                PUSH
                LDA 1 X
                PUSH
                RTS             END-CODE        EXECUTES> 2DUP

\ ***************************************************************************
\ Arithmetic/logical operators

LMACRO +         ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      + >R
                [ASM6805]
                LDA # R>
                PUSH
                [FORTH]
        ELSE
                PUSH_LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6805]
                                ADD # R>
                                [FORTH]
                        ELSE    >R
                                [ASM6805]
                                ADD MEM R>
                                [FORTH]
                        THEN    PUSH
                ELSE
                        POP
                        [ASM6805]
                        ADD 0 X
                        STA 0 X
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> +


LMACRO -        ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      - >R
                [ASM6805]
                LDA # R>
                PUSH
                [FORTH]
        ELSE
                PUSH_LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6805]
                                SUB # R>
                                [FORTH]
                        ELSE    >R
                                [ASM6805]
                                SUB MEM R>
                                [FORTH]
                        THEN    PUSH
                ELSE
                        POP
                        [ASM6805]
                        SUB 0 X
                        NEG A
                        STA 0 X
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> -


LMACRO 1+       ( n1 -- n2 )
                ADD # 1
                END-LMACRO       EXECUTES> 1+

LMACRO 2+       ( n1 -- n2 )
                ADD # 2
                END-LMACRO       EXECUTES> 2+

LMACRO AND      ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      AND >R
                [ASM6805]
                LDA # R>
                PUSH
                [FORTH]
        ELSE
                PUSH_LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6805]
                                AND # R>
                                [FORTH]
                        ELSE    >R
                                [ASM6805]
                                AND MEM R>
                                [FORTH]
                        THEN    PUSH
                ELSE
                        POP
                        [ASM6805]
                        AND 0 X
                        STA 0 X
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> AND


LMACRO OR       ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      OR >R
                [ASM6805]
                LDA # R>
                PUSH
                [FORTH]
        ELSE
                PUSH_LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6805]
                                ORA # R>
                                [FORTH]
                        ELSE    >R
                                [ASM6805]
                                ORA MEM R>
                                [FORTH]
                        THEN    PUSH
                ELSE
                        POP
                        [ASM6805]
                        ORA 0 X
                        STA 0 X
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> OR


LMACRO XOR      ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      XOR >R
                [ASM6805]
                LDA # R>
                PUSH
                [FORTH]
        ELSE
                PUSH_LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6805]
                                EOR # R>
                                [FORTH]
                        ELSE    >R
                                [ASM6805]
                                EOR MEM R>
                                [FORTH]
                        THEN    PUSH
                ELSE
                        POP
                        [ASM6805]
                        EOR 0 X
                        STA 0 X
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> XOR


\ LABEL (*)       ( u1 u2 -- u3 )
\                 POP
\                 TEMP STX,  0 ,X LDX,  MUL,
\                 TEMP LDX,  0 ,X STA,
\                 RTS,            END-CODE

LMACRO *        ( u1 u2 -- u3 )
                [FORTH]
                PUSH_LIT/MEM_OPT ?DUP
        IF      0<
                IF      >R
                        [ASM6805]
                        STX TEMP
                        LDX # R> ( xxx )
                        MUL
                        LDX TEMP
                        PUSH
                        [FORTH]
                ELSE    >R
                        [ASM6805]
                        STX TEMP
                        LDX R> ( xxx )
                        MUL
                        LDX TEMP
                        PUSH
                        [FORTH]
                THEN
        ELSE
\                 F['] (*) TARG_COMPILE
                [ASM6805]
                POP
                STX TEMP
                LDX 0 X
                MUL
                LDX TEMP
                STA 0 X
                [FORTH]
        THEN    [TARGET]        END-LMACRO       EXECUTES> *

CODE M*         ( u1 u2 -- ud )
                STX TEMP
                LDA 0 X
                LDX 1 X
                MUL
                STX TEMP 1+
                LDX TEMP
                STA 1 X
                LDA TEMP 1+
                STA 0 X
                RTS             END-CODE



( NO DIVIDE YET !!! )

\ ***************************************************************************
\ Unary arithmetic/logical operators

LMACRO NEGATE   ( n1 -- n2 )
                [FORTH]
                PUSH_OPT
        IF
                [ASM6805]
                NEG A
                [FORTH]
                PUSH
        ELSE
                [ASM6805]
                NEG 0 X
                [FORTH]
        THEN    [TARGET]        END-MACRO       EXECUTES> NEGATE

LMACRO NOT      ( n1 -- n2 )
                [FORTH]
                PUSH_OPT
        IF
                [ASM6805]
                COM A
                PUSH
                [FORTH]
        ELSE
                [ASM6805]
                COM 0 X
                [FORTH]
        THEN    [TARGET]        END-LMACRO       EXECUTES> NOT

LMACRO 2*       ( n1 -- n2 )
                [FORTH]
                PUSH_OPT
        IF      [ASM6805]
                LSL A
                PUSH
                [FORTH]
        ELSE    [ASM6805]
                LSL 0 X
                [FORTH]
        THEN    [TARGET]        END-LMACRO       EXECUTES> 2*

LMACRO 2/       ( n1 -- n2 )
                [FORTH]
                PUSH_OPT
        IF      [ASM6805]
                LSR A
                PUSH
                [FORTH]
        ELSE    [ASM6805]
                LSR 0 X
                [FORTH]
        THEN    [TARGET]        END-LMACRO       EXECUTES> 2/

$FF CONSTANT TRUE
$00 CONSTANT FALSE

\ ***************************************************************************
\ Program control

LMACRO SP!      ( ? -- )        \ reset data stack pointer
                LDX # SP0
                END-LMACRO      NO-INTERPRET

LMACRO RP!      ( -- )          \ reset return stack pointer
                RSP
                END-LMACRO      NO-INTERPRET

LMACRO NOOP     ( -- )          \ no operation
                NOP
                END-LMACRO      EXECUTES> NOOP

\ ***************************************************************************
\ 6805 Special instructions
\ MAYBE PUT THESE IN INTERRUPT LIBRARY FILE

LMACRO EI       ( -- )          \ enable interrupts
                CLI             END-LMACRO       NO-INTERPRET

LMACRO DI       ( -- )          \ disable interrupts
                SEI             END-LMACRO       NO-INTERPRET

LMACRO SWI      ( -- )          \ software interrupt
                SWI             END-LMACRO       NO-INTERPRET

LMACRO WAIT     ( -- )          \ wait for interrupt
                WAIT            END-LMACRO       NO-INTERPRET

LMACRO STOP     ( -- )          \ stop processor
                STOP            END-LMACRO       NO-INTERPRET

\ ***************************************************************************
\ Memory operations

CODE (@)        ( addr -- n )      \ default subroutine call
                STX TEMP
                LDX 0 X
                LDA 0 X
                LDX TEMP
                STA 0 X
                RTS          END-CODE

LMACRO @         ( -- )          \ The ! MACRO
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6805]
                        LDA R> ( xxx )
                        PUSH
                        [FORTH]
                ELSE
                        F['] (@) TARG_COMPILE
                THEN
                [TARGET]        END-LMACRO      NO-INTERPRET

' @ >EXECUTE IS COMP_FETCH              \ link into compiler


CODE (!)        ( n a -- )              \ default subroutine
                STX TEMP
                LDA 1 X
                LDX 0 X
                STA 0 X
                LDX TEMP
                INC X
                INC X
                RTS             END-CODE

LMACRO !         ( n addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6805]
                        POP
                        STA R> ( xxx )
                        [FORTH]
                ELSE
                        F['] (!) TARG_COMPILE
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' ! >EXECUTE IS COMP_STORE      \ link to compiler


CODE (+!)       ( n addr -- )             \ default subroutine
                STX TEMP
                LDA 1 X
                LDX 0 X
                ADD 0 X
                STA 0 X
                LDX TEMP
                INC X
                INC X
                RTS             END-CODE

LMACRO +!        ( n addr -- )
                [FORTH]
                LIT_OPT
                IF      DUP >R >R
                        [ASM6805]
                        POP
                        ADD R> ( xxx )
                        STA R> ( xxx )
                        [FORTH]
                ELSE
                        F['] (+!) TARG_COMPILE
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' +!   >EXECUTE IS COMP_PSTORE     \ link to compiler


CODE (ON)       ( addr -- )             \ default subroutine
                STX TEMP
                LDX 0 X
                LDA # $FF
                STA 0 X
                LDX TEMP
                INC X
                RTS             END-CODE

LMACRO ON        ( addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6805]
                        LDA # $FF
                        STA R> ( xxx )
                        [FORTH]
                ELSE
                        F['] (ON) TARG_COMPILE
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' ON  >EXECUTE IS COMP_ON         \ link to compiler


CODE (OFF)      ( addr -- )             \ default subroutine
                STX TEMP
                LDX 0 X
                CLR 0 X
                LDX TEMP
                INC X
                RTS             END-CODE

LMACRO OFF       ( addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6805]
                        CLR R> ( xxx )
                        [FORTH]
                ELSE
                        F['] (OFF) TARG_COMPILE
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' OFF >EXECUTE IS COMP_OFF        \ link to compiler


CODE (INCR)     ( addr -- )             \ default subroutine
                STX TEMP
                LDX 0 X
                INC 0 X
                LDX TEMP
                INC X
                RTS             END-CODE

LMACRO INCR      ( addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6805]
                        INC R> ( xxx )
                        [FORTH]
                ELSE
                        F['] (INCR) TARG_COMPILE
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' INCR >EXECUTE IS COMP_INCR       \ link to compiler


CODE (DECR)     ( addr -- )             \ default subroutine
                STX TEMP
                LDX 0 X
                DEC 0 X
                LDX TEMP
                INC X
                RTS             END-CODE

LMACRO DECR      ( addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6805]
                        DEC R> ( xxx )
                        [FORTH]
                ELSE
                        F['] (DECR) TARG_COMPILE
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' DECR >EXECUTE IS COMP_DECR       \ link to compiler

\ ***************************************************************************
\ Double Memory Operarors

CODE 2@         ( adr -- n1 n2 )
                STX TEMP
                LDX 0 X
                LDA 0 X
                STA TEMP 1+
                LDX TEMP
                LDX 0 X
                LDA 1 X
                LDX TEMP
                STA 0 X
                LDA TEMP 1+
                PUSH
                RTS             END-CODE

CODE 2!         ( n1 n2 adr -- )
                POP
                STA TEMP 1+
                STX TEMP
                LDA 0 X
                LDX TEMP 1+
                STA 0 X
                LDX TEMP
                LDA 1 X
                LDX TEMP 1+
                STA 1 X
                LDX TEMP
                INC X
                INC X
                RTS             END-CODE

\ ***************************************************************************
\ Block Memory Operators

CODE MOVE       ( from to len -- )
                POP
                STA TEMP ( len )
                POP
                STA TEMP 1+ ( to )
                POP
                STA TEMP 2+ ( from )
                STX TEMP 3 + ( save X )
                TST TEMP
                BEQ 0 $
\                0= NOT
\                IF,     BEGIN,
        1 $:            LDX TEMP 2+
                        LDA 0 X
                        LDX TEMP 1+
                        STA 0 X
                        INC TEMP 2+
                        INC TEMP 1+
                        DEC TEMP
                BNE 1 $
\                        0=
\                        UNTIL,
\                THEN,
        0 $:    LDX TEMP 3 +
                RTS             END-CODE

CODE FILL       ( adr len n -- )
                POP
                STA TEMP ( n )
                POP
                STA TEMP 1+ ( len )
                POP
                STA TEMP 2+ ( addr )
                STX TEMP 3 + ( save X )
                TST TEMP 1+
                BEQ 0 $
\                0= NOT
\                IF,
                        LDA TEMP
                        LDX TEMP 2+
\                        BEGIN,
        1 $:                    STA 0 X
                                INC X
                                DEC TEMP 1+
                        BNE 1 $
\                                0=
\                        UNTIL,
\                THEN,
        0 $:    LDX TEMP 3 +
                RTS             END-CODE

: ERASE         ( addr len -- )  0 FILL ;

\ ***************************************************************************
\ Comparison Operators

CODE 0=         ( n -- f )
                LDA 0 X
                BNE 0 $
\                0= IF,
                LDA # $FF
                STA 0 X
                RTS
\                THEN,
        0 $:    CLR 0 X
                RTS             END-CODE

CODE 0<>        ( n -- f )
                LDA 0 X
                BEQ 0 $
\                0= NOT IF,
                LDA # $FF
                STA 0 X
                RTS
\                THEN,
        0 $:    CLR 0 X
                RTS             END-CODE

CODE 0<         ( n -- f )
                LDA 0 X
                BPL 0 $
\                0< IF,
                LDA # $FF
                STA 0 X
                RTS
\                THEN,
        0 $:    CLR 0 X
                RTS             END-CODE

CODE 0>         ( n -- f )
                LDA 0 X
                BNE 0 $
\                0= IF,
                CLR 0 X
                RTS
\                THEN,
        0 $:    BPL 1 $
\                0< IF,
                CLR 0 X
                RTS
\                THEN,
        1 $:    LDA # $FF
                STA 0 X
                RTS             END-CODE

CODE =          ( n n1 -- f )
                POP
                CMP 0 X
                BNE 0 $
\                0= IF,
                LDA # $FF
                STA 0 X
                RTS
\                THEN,
        0 $:    CLR 0 X
                RTS             END-CODE

CODE <>         ( n n1 -- f )
                POP
                CMP 0 X
                BEQ 0 $
\                0= NOT IF,
                LDA # $FF
                STA 0 X
                RTS
\                THEN,
        0 $:    CLR 0 X
                RTS             END-CODE

CODE <          ( n n1 -- f )
                POP
                CMP 0 X
                BLS 0 $
\                > IF,
                LDA # $FF
                STA 0 X
                RTS
\                THEN,
        0 $:    CLR 0 X
                RTS             END-CODE

CODE >          ( n n1 -- f )
                POP
                CMP 0 X
                BCC 0 $
\                < IF,
                LDA # $FF
                STA 0 X
                RTS
\                THEN,
        0 $:    CLR 0 X
                RTS             END-CODE

CODE <=         ( n n1 -- f )
                POP
                CMP 0 X
                BCS 0 $
\                < NOT IF,
                LDA # $FF
                STA 0 X
                RTS
\                THEN,
        0 $:    CLR 0 X
                RTS             END-CODE

CODE >=         ( n n1 -- f )
                POP
                CMP 0 X
                BHI 0 $
\                > NOT IF,
                LDA # $FF
                STA 0 X
                RTS
\                THEN,
        0 $:    CLR 0 X
                RTS             END-CODE

\ ***************************************************************************

CODE MS         ( n -- )                \ Delay for N milliseconds
                POP
                CLR TEMP
\                BEGIN,  BEGIN,
        0 $:            DEC TEMP
                        BNE 0 $
\                        0= UNTIL,
                        DEC A
                BNE 0 $
\                        0=
\                UNTIL,
                RTS     END-CODE

: 500MS         ( -- )                  \ Delays approximately 500 msec.
                250 MS  250 MS ;


>FORTH

