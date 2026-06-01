\ LIB11.SEQ           6811 Target Library Source        by Tom Zimmer
\ as translated from the 6805 by Andrew McKewen
\ LIB5.SEQ            6805 Target Library Source        by Andrew McKewan

\ 05/04/94 09:30 tjz Started conversion to top of stack in reg A

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
                IF      [ASM6811]
                        jmp     -br# dup>r  $ a; r> 01lab
                        [FORTH]
                ELSE    [ASM6811]
                        jmp     -br# dup>r $ a; r> 01lab
                        [FORTH]
                THEN    ?long_set ;

: ,+JUMP        ( -- )
                ?LONG   [FORTH]
                IF      [ASM6811]
                        jmp     +br# $ a;
                        [FORTH]
                ELSE    [ASM6811]
                        jmp     +br# $ a;
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
                PUSH
                LDAA # r>        \ to the stack.
                END-MACRO       NO-INTERPRET

' (LIT) >EXECUTE IS COMP_SINGLE \ link into number compiler


MACRO EXIT      ( -- )
                EXIT_OPT        END-MACRO       NO-INTERPRET

MACRO ?EXIT     ( f1 -- )       \ If boolean f1 is true, exit from definition
                TAB
                POP
                TSTB
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
                TAB
                POP
                TSTB
                [FORTH]
                ?LONG
                IF      [ASM6811]
                        BEQ 0 $    A;
                        ,+JUMP
                   0 $: A;
                        [FORTH]
                ELSE    [ASM6811]
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
                TAB
                POP
                TSTB
                BNE 0 $ A;
                ,-jump  A;
           0 $:         A;
                ?REOPT
                END-LMACRO       NO-INTERPRET

\ ***************************************************************************
\ Runtime Primatives for for/next loop

LMACRO FOR      ( n1 -- )
                TAB
                POP     A;
                +BR# $: A;
                PSHB    A;
                OPT_OFF1
                5
                END-LMACRO      NO-INTERPRET

LMACRO NEXT     ( -- )
                5 ?pairs        \ check for matching previous FOR
                PULB
                DECB
                BNE -br# dup>r $ a; r> 01lab
                ?REOPT
                END-LMACRO       NO-INTERPRET

LMACRO I        ( -- n )
                PUSH
                PULA
                PSHA
                END-LMACRO       NO-INTERPRET

\ ***************** NOT IMPLEMENTED FOR NOW ********************
\ LMACRO LEAVE    ( -- )          \ LEAVE forces an exit at the end
\                                 \ of the loop by setting the index to 1.
\                 END-LMACRO       NO-INTERPRET


\ ***************************************************************************
\ Stack Operators

LMACRO DROP     ( n1 -- )
                [FORTH]
                DROP_OPT        \ check for preseeding SWAP
                IF
                        [ASM6811]
                        INX A;
                        [FORTH]
                ELSE
                        POP
                THEN
                END-LMACRO       EXECUTES> DROP

LMACRO DUP      ( n1 -- n1 n1 )
                [FORTH]
                [ASM6811]
                PUSH
                [TARGET]
                END-LMACRO      EXECUTES> DUP

LMACRO SWAP     ( n1 n2 -- n2 n1 )
                TAB
                LDAA 0 X
                STAB 0 X
                END-LMACRO      EXECUTES> SWAP

LMACRO OVER     ( n1 n2 -- n1 n2 n1 )
                PUSH
                LDAA 2 X
                END-LMACRO      EXECUTES> OVER

CODE ROT        ( n1 n2 n3 -- n2 n3 n1 )
                PSHA
                LDAA 1 X
                LDAB 0 X
                STAB 1 X
                PULB
                STAB 0 X
                RTS             END-CODE        EXECUTES> ROT

LMACRO NIP      ( n1 n2 -- n2 )
                INX
                END-LMACRO       EXECUTES> NIP

CODE TUCK       ( n1 n2 -- n2 n1 n2 )
                LDAB 0 X
                DEC X
                STAB 0 X
                STAA 1 X
                RTS             END-CODE        EXECUTES> TUCK

LMACRO ?DUP     ( n -- n | n n )
                BEQ 0 $
                PUSH
        0 $:    A;
                END-LMACRO      EXECUTES> ?DUP

CODE PICK       ( n1 -- n2 )
                PSHX
                TAB
                ABX
                LDAA 0 X
                PULX
                END-CODE        EXECUTES> PICK

\ ***************************************************************************
\ Double stack operators

LMACRO 2DROP    ( n1 n2 -- )
                INX
                POP
                END-LMACRO       EXECUTES> 2DROP

CODE 2DUP       ( n1 n2 -- n1 n2 n1 n2 )
                PUSH
                TAB
                LDAA 1 X
                PUSH
                TBA
                RTS             END-CODE        EXECUTES> 2DUP

\ ***************************************************************************
\ Arithmetic/logical operators

LMACRO +         ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      + >R
                [ASM6811]
                LDAA # R> A;
                [FORTH]
        ELSE
                LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6811]
                                ADDA # R> A;
                                [FORTH]
                        ELSE    >R
                                [ASM6811]
                                ADDA R> A;
                                [FORTH]
                        THEN
                ELSE
                        [ASM6811]
                        ADDA 0 X A;
                        INX      A;
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> +


LMACRO -        ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      - >R
                [ASM6811]
                LDAA # R> A;
                [FORTH]
        ELSE
                LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6811]
                                SUBA # R> A;
                                [FORTH]
                        ELSE    >R
                                [ASM6811]
                                SUBA R> A;
                                [FORTH]
                        THEN
                ELSE
                        [ASM6811]
                        SUBA 0 X A;
                        NEGA     A;
                        INX      A;
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> -


LMACRO 1+       ( n1 -- n2 )
                INCA
                END-LMACRO       EXECUTES> 1+

LMACRO 2+       ( n1 -- n2 )
                ADDA # 2
                END-LMACRO       EXECUTES> 2+

LMACRO AND      ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      AND >R
                [ASM6811]
                LDAA # R> A;
                [FORTH]
        ELSE
                LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6811]
                                ANDA # R> A;
                                [FORTH]
                        ELSE    >R
                                [ASM6811]
                                ANDA R> A;
                                [FORTH]
                        THEN
                ELSE
                        [ASM6811]
                        ANDA 0 X A;
                        INX      A;
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> AND


LMACRO OR       ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      OR >R
                [ASM6811]
                LDAA # R> A;
                [FORTH]
        ELSE
                LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6811]
                                ORAA # R> A;
                                [FORTH]
                        ELSE    >R
                                [ASM6811]
                                ORAA R> A;
                                [FORTH]
                        THEN
                ELSE
                        [ASM6811]
                        ORAA 0 X A;
                        INX      A;
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> OR


LMACRO XOR      ( n1 n2 -- n3 )
                [FORTH]
                LIT_LIT_OPT
        IF      XOR >R
                [ASM6811]
                LDAA # R> A;
                [FORTH]
        ELSE
                LIT/MEM_OPT ?DUP
                IF
                        0<
                        IF      >R
                                [ASM6811]
                                EORA # R> A;
                                [FORTH]
                        ELSE    >R
                                [ASM6811]
                                EORA R> A;
                                [FORTH]
                        THEN
                ELSE
                        [ASM6811]
                        EORA 0 X A;
                        INX      A;
                        [FORTH]
                THEN
        THEN    [TARGET]        END-LMACRO       EXECUTES> XOR


LMACRO *        ( u1 u2 -- u3 )
                [FORTH]
                LIT/MEM_OPT ?DUP
        IF      0<
                IF      >R
                        [ASM6811]
                        PSHX             A;
                        LDX # R> ( xxx ) A;
                        MUL              A;
                        PULX             A;
                        [FORTH]
                ELSE    >R
                        [ASM6811]
                        PSHX           A;
                        LDX R> ( xxx ) A;
                        MUL            A;
                        PULX           A;
                        [FORTH]
                THEN
        ELSE    [ASM6811]
                PSHX     A;
                LDX 0 X  A;
                MUL      A;
                PULX     A;
                INX      A;
                [FORTH]
        THEN    [TARGET]        END-LMACRO       EXECUTES> *

\ CODE M*         ( u1 u2 -- ud )
\                 STX TEMP
\                 LDAA 0 X
\                 LDX 1 X
\                 MUL
\                 STX TEMP 1+
\                 LDX TEMP
\                 STAA 1 X
\                 LDAA TEMP 1+
\                 STAA 0 X
\                 RTS             END-CODE



( NO DIVIDE YET !!! )

\ ***************************************************************************
\ Unary arithmetic/logical operators

LMACRO NEGATE   ( n1 -- n2 )
                NEGA
                END-MACRO       EXECUTES> NEGATE

LMACRO NOT      ( n1 -- n2 )
                COMA A;
                END-LMACRO       EXECUTES> NOT

LMACRO 2*       ( n1 -- n2 )
                LSLA A;
                END-LMACRO       EXECUTES> 2*

LMACRO 2/       ( n1 -- n2 )
                LSRA A;
                END-LMACRO       EXECUTES> 2/

$FF CONSTANT TRUE
$00 CONSTANT FALSE

\ ***************************************************************************
\ Program control

LMACRO SP!      ( ? -- )        \ reset data stack pointer
                LDX # SP0
                END-LMACRO      NO-INTERPRET

LMACRO RP!      ( -- )          \ reset return stack pointer
                LDS # $00FE
                END-LMACRO      NO-INTERPRET

LMACRO NOOP     ( -- )          \ no operation
                NOP
                END-LMACRO      EXECUTES> NOOP

\ ***************************************************************************
\ 6811 Special instructions
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

CODE _@         ( addr -- n )      \ default subroutine call
                LDAB # 0
                XGDY
                LDAA 0 Y
                RTS             END-CODE

LMACRO @        ( a1 -- n1 )    \ The @ MACRO
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6811]
                        PUSH            A;
                        LDAA R> ( xxx ) A;
                        [FORTH]
                ELSE    IMM_OPT
                        IF      >R
                                [ASM6811]
                                LDAA R> ( xxx ) A;
                                [FORTH]
                        ELSE
                                F['] _@ TARG_COMPILE
                        THEN
                THEN
                [TARGET]        END-LMACRO      NO-INTERPRET

' @ >EXECUTE IS COMP_FETCH              \ link into compiler


CODE _!         ( n a -- )              \ default subroutine
                PSHA
                POP
                LDAB # 0
                XGDY
                PULA
                STAA 0 Y
                POP
                RTS             END-CODE

LMACRO !         ( n addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6811]
                        STAA R> ( xxx ) A;
                        POP             A;
                        [FORTH]
                ELSE    IMM_OPT
                        IF      >R
                                [ASM6811]
                                POP             A;
                                STAA R> ( xxx ) A;
                                POP             A;
                                [FORTH]
                        ELSE
                                F['] _! TARG_COMPILE
                        THEN
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' ! >EXECUTE IS COMP_STORE      \ link to compiler

CODE _+!        ( n addr -- )             \ default subroutine
                PSHA
                POP
                LDAB # 0
                XGDY
                PULA
                ADDA 0 Y
                POP
                RTS             END-CODE

LMACRO +!        ( n addr -- )
                [FORTH]
                LIT_OPT
                IF      DUP >R >R
                        [ASM6811]
                        ADDA R> ( xxx ) A;
                        STAA R> ( xxx ) A;
                        POP             A;
                        [FORTH]
                ELSE    IMM_OPT
                        IF      >R
                                [ASM6811]
                                POP             A;
                                ADDA R> ( xxx ) A;
                                STAA R> ( xxx ) A;
                                POP             A;
                                [FORTH]
                        ELSE
                                F['] _+! TARG_COMPILE
                        THEN
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' +!   >EXECUTE IS COMP_PSTORE     \ link to compiler

CODE _ON        ( addr -- )             \ default subroutine
                LDAB # 0
                XGDY
                LDAA # FFh
                STAA 0 Y
                POP
                RTS             END-CODE

LMACRO ON        ( addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6811]
                        LDAB # $FF      A;
                        STAB R> ( xxx ) A;
                        [FORTH]
                ELSE    IMM_OPT
                        IF      >R
                                [ASM6811]
                                LDAB # $FF      A;
                                STAB R> ( xxx ) A;
                                POP             A;
                                [FORTH]
                        ELSE
                                F['] _ON TARG_COMPILE
                        THEN
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' ON  >EXECUTE IS COMP_ON         \ link to compiler

CODE _OFF       ( addr -- )             \ default subroutine
                LDAB # 0
                XGDY
                CLRA
                STAA 0 Y
                POP
                RTS             END-CODE

LMACRO OFF       ( addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6811]
                        CLR R> ( xxx )  A;
                        [FORTH]
                ELSE    IMM_OPT
                        IF      >R
                                [ASM6811]
                                CLR R> ( xxx )  A;
                                POP             A;
                                [FORTH]
                        ELSE
                                F['] _OFF TARG_COMPILE
                        THEN
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' OFF >EXECUTE IS COMP_OFF        \ link to compiler


CODE _INCR      ( addr -- )             \ default subroutine
                LDAB # 0
                XGDY
                INC 0 Y
                POP
                RTS             END-CODE

LMACRO INCR      ( addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6811]
                        INC R> ( xxx ) A;
                        [FORTH]
                ELSE    IMM_OPT
                        IF      >R
                                [ASM6811]
                                INC R> ( xxx )  A;
                                POP             A;
                                [FORTH]
                        ELSE
                                F['] _INCR TARG_COMPILE
                        THEN
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' INCR >EXECUTE IS COMP_INCR       \ link to compiler


CODE _DECR      ( addr -- )             \ default subroutine
                LDAB # 0
                XGDY
                DEC 0 Y
                POP
                RTS             END-CODE

LMACRO DECR      ( addr -- )
                [FORTH]
                LIT_OPT
                IF      >R
                        [ASM6811]
                        DEC R> ( xxx ) A;
                        [FORTH]
                ELSE    IMM_OPT
                        IF      >R
                                [ASM6811]
                                DEC R> ( xxx )  A;
                                POP             A;
                                [FORTH]
                        ELSE
                                F['] _DECR TARG_COMPILE
                        THEN
                THEN
                [TARGET]        END-LMACRO       NO-INTERPRET

' DECR >EXECUTE IS COMP_DECR       \ link to compiler

\ ***************************************************************************
\ Double Memory Operarors

CODE 2@         ( adr -- n1 n2 )
                LDAB # 0
                XGDY
                LDAA 1 Y
                PUSH
                LDAA 0 Y
                RTS             END-CODE        NO-INTERPRET

CODE 2!         ( n1 n2 adr -- )
                PSHA
                POP
                LDAB # 0
                XGDY
                PULA
                STAA 0 Y
                POP
                STAA 1 Y
                RTS             END-CODE        NO-INTERPRET

\ ***************************************************************************
\ Block Memory Operators

CODE CMOVE      ( from to len -- )
                TSTA
                BNE 0 $         \ move length must be non zero
                INX
                INX
                POP
                RTS
        0 $:    PSHX
                PSHA
                CLRB
                POP
                XGDY
                CLRB
                POP
                XGDX
                PULA
        1 $:    LDAB 0 X
                STAB 0 X
                INX
                INY
                DECA
                BNE 1 $
                PULX
                INX
                INX
                POP
                RTS             END-CODE

CODE FILL       ( adr len n -- )
                PSHA
                LDAA 1 X
                CLRB
                XGDY            \ set Y to be pointer
                LDAB 0 X
                BEQ 1 $         \ if length is zero, just exit
                PULA            \ recover value sto fill with
        0 $:    STAA 0 Y
                INY
                DECB
                BNE 0 $
        1 $:    INX             \ cleanup stack
                INX
                POP
                RTS             END-CODE

: ERASE         ( addr len -- )  0 FILL ;

\ ***************************************************************************
\ Comparison Operators

LMACRO 0=       ( n -- f )
                LDAB # FFh
                TSTA
                BNE 0 $
                CLRB
        0 $:    TBA             END-LMACRO

LMACRO 0<>      ( n -- f )
                TSTA
                BEQ 0 $
                ORAA # FFh
        0 $:    A;              END-LMACRO

LMACRO 0<       ( n -- f )
                CLRB
                TSTA
                BPL 0 $
                LDAB # FFh
        0 $:    TBA             END-LMACRO

LMACRO 0>       ( n -- f )
                CLRB
                TSTA
                BMI 0 $
                LDAB # FFh
        0 $:    TBA             END-LMACRO

LMACRO =        ( n n1 -- f )
                CLRB
                CMPA 0 X
                BNE 0 $
                LDAB # FFh
        0 $:    TBA
                INX             END-LMACRO

LMACRO <>       ( n n1 -- f )
                CLRB
                CMPA 0 X
                BEQ 0 $
                LDAB # FFh
        0 $:    TBA
                INX             END-LMACRO

LMACRO <        ( n n1 -- f )
                CLRB
                CMPA 0 X
                BLS 0 $
                LDAB # FFh
        0 $:    TBA
                INX             END-LMACRO

LMACRO >        ( n n1 -- f )
                CLRB
                CMPA 0 X
                BCC 0 $
                LDAB # FFh
        0 $:    TBA
                INX             END-LMACRO

LMACRO <=       ( n n1 -- f )
                CLRB
                CMPA 0 X
                BCS 0 $
                LDAB # FFh
        0 $:    TBA
                INX             END-LMACRO

CODE >=         ( n n1 -- f )
                CLRB
                CMPA 0 X
                BHI 0 $
                LDAB # FFh
        0 $:    TBA
                INX             END-LMACRO

\ LOAD THESE VERY LATE, SO WE DON'T GET VOCABULARY CONFLICT PROBLEMS !!!

LMACRO R@       ( -- n1 )       \ return copy of top of return stack
                PUSH
                TSY
                LDAA 0 Y
                END-MACRO       NO-INTERPRET

LMACRO >R       ( n1 -- )       \ push n1 onto the return stack
                PSHA
                POP
                END-LMACRO      NO-INTERPRET

LMACRO R>       ( -- n1 )       \ pop n1 from the return stack
                PUSH
                PULA
                END-LMACRO      NO-INTERPRET

\ ***************************************************************************

CODE MS         ( n -- )                \ Delay for N milliseconds
                CLRB
        0 $:            DECB
                        BNE 0 $
                        DECA
                BNE 0 $
                POP
                RTS     END-CODE

: 500MS         ( -- )                  \ Delays approximately 500 msec.
                250 MS  250 MS ;

>FORTH

