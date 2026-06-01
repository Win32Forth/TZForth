\\ LIBRARY.SEQ     SAM8 Target Library Source by Bob Smith & Jerry Boutelle

Revision History:

 12/08/92 12:06 tjz
        Started modifications for SSP1600 Digital Signal Processor.

{

\ *********************************************************************
\ Target specific words used by the compiler to complete compilation of
\ the the various types of library and target definitions.

\ *********************************************************************
\                       Target Library words
\ *********************************************************************

>LIBRARY                \ set compiler to create library definitions

TARGET DEFINITIONS      \ select the target vocabulary for all definitions

\ Macros for pushing/popping R0/R1 and popping R2/R3

MACRO PUSH_A    ( -- )
                LD (R6+) A
                END-MACRO

MACRO PUSH_X    ( -- )
                LD (R6+) X
                END-MACRO

MACRO PUSH_Y    ( -- )
                LD (R6+) Y
                END-MACRO

MACRO POP_A     ( -- )
                LD A (R6-)
                END-MACRO

MACRO POP_X     ( -- )
                LD X (R6-)
                END-MACRO

MACRO POP_Y     ( -- )
                LD Y (R6-)
                END-MACRO

FORTH   >FORTH

\ **********************************************************************

I: (LIT)        ( n1 -- )       \ Compile an number to be pushed on the stack
                >R A;
                [FORTH] R> SPLIT >R >R
                2 #?OPT 0=
                HERE-T 2- @-T $0000 <> OR       \ LD A (R6-)
                IF      [ASM1600]
                        PUSH_A          A;      \ push current stack top
                        [FORTH]
                ELSE    2 1 DEL_B/I             \ discard 2 bytes & 1 inst
                THEN    [ASM1600]
                        INST-RESET              \ hide lit from assembler
                        [ASM1600]
                        LDI A # R>      A;
                        [FORTH]
                        R>DROP                  \ discard the word
                        [TARGET] ; IMMEDIATE

' (LIT) IS COMP_SINGLE \ link into number compiler

\ **********************************************************************

I: ,JUMP        ( n1 -- )
                [FORTH] >R [ASM1600]
                BRA     R> EXECUTE +br# $       a;
                ?REOPT ;

I: ,UNTIL       ( n1 -- )
                [FORTH] >R [ASM1600]
                BRA     R> EXECUTE -br#  dup>r  $ a; r> 01lab
                ?REOPT ;

TARGET  >LIBRARY

\ **********************************************************************

CODE PERFORM    ( a1 -- )       \ perform function at address a1
                LD R0 A
                POP_A
                LD PC (R0)
                END-CODE        NO-INTERPRET

\ **********************************************************************
\ Install linkage into TCOM to compile PERFORM. Typically compiled
\ following a literal address as in the case of a DEFERed word.
\ **********************************************************************

FORTH   >FORTH

I: %PERFORM      ( <a> -- ) \ Execute routine contained at address
                F['] PERFORM RES_COMP_CALL ; IMMEDIATE

' %PERFORM IS COMP_PERFORM      \ link into compiler

TARGET  >LIBRARY

\ **********************************************************************

CODE BOUNDS    ( n1 n2 -- n3 n4 ) \ Calculate limits used in DO-loop
                POP_X
                ADD             A X
                PUSH_A
                LD              A X
                RET
                END-CODE        NO-INTERPRET

MACRO EXIT      ( -- ) \ Terminate a high-level definition
                %END-T:
                ?REOPT    END-MACRO       NO-INTERPRET

\ **********************************************************************
\ BEGIN, THEN, DO ?DO, LOOP, +LOOP, UNTIL, AGAIN, REPEAT, IF ELSE,
\ WHILE: These are the compiling words needed to properly compile the
\ Forth Conditional Structures.  Each of them is immediate and they
\ must compile their runtime routines along withwhatever addresses
\ they need.  A modest amount of errorchecking is done.
\ **********************************************************************

LMACRO BEGIN     ( -- )          \ mark the beginning of a BEGIN AGAIN loop
                +br# $:
                OPT_OFF1
                7                       \ leave for branch pair checking
                END-LMACRO       NO-INTERPRET

LMACRO AGAIN     ( -- )          \ an unconditional branch back to BEGIN
                7 ?pairs        \ check for conditional branch pairing
                branch_mark             \ mark start of a branch operation
                F['] ALWAYS ,UNTIL
                END-LMACRO       NO-INTERPRET

FORTH >FORTH

\ **********************************************************************

I: ?PUSH_R1     ( f1 n1 -- f2 ) \ check at NEGATIVE offset n1 for PUSH_R1
                [FORTH]         \ accumulate "AND" into flag f1
                >R
                HERE-T  R> - 1+  @-T $0000 = AND ;    \ LD (R6-) A

                \ Make words that are "internal", that check at a
                \ NEGATIVE offset of n2 for the presence of byte n1
I: WORD_TEST    ( n1 -<name>- )         \ compile time
                ( f1 n2 -- f2 )         \ runtime
                [FORTH]
                beheadable
                if      ['] iheader %save!> header      \ make internal
                        CREATE
                        %restore> header
                else    CREATE                          \ else external
                then    , DOES> @ HERE-T ROT - @-T = AND ;

$56 WORD_TEST ?PUSH_A          \ check for PUSH A
$56 WORD_TEST ?AND_A_#         \ check for AND R1 # xx
$54 WORD_TEST ?AND_A_DA        \ check for AND R1 R xx
$1C WORD_TEST  ?LD_A_#         \ check for LD  R1 # xx
$18 WORD_TEST  ?LD_A_DA        \ check for LD  R1 R xx
$AF WORD_TEST  ?RET             \ check for RET INSTRUCTION
$8D WORD_TEST  ?BRA_T           \ check for JMP T INSTRUCTION

\ **********************************************************************

FORTH

I: OPT_ANDIF    ( -- )
                [FORTH]
                4 #?OPT
                4 ?PUSH_A                  \ and immediate with push
                2 ?AND_A_#
                IF      HERE-T 2- @-T >R   \ get the register xx
                        4 2 DEL_B/I        \ delete bytes & insts
                        branch_mark        \ mark start of a branch operation
                        [ASM1600]
                        CMPI    A # R>         a;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
                4 #?OPT
                4 ?PUSH_A                  \ and register with push
                2 ?AND_A_DA
                IF      HERE-T 2- @-T >R   \ get the register xx
                        4 2 DEL_B/I        \ delete bytes & insts
                        branch_mark        \ mark start of a branch operation
                        [ASM1600]
                        CMP     A R>         a;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
                2 #?OPT
                2 ?PUSH_R1              \ DUP preceeding IF
                IF      2 1 DEL_B/I     \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASM1600]
                        OR      A A             a;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
                branch_mark             \ and immediate or register, no push
                TRUE 2 ?AND_A_#
                TRUE 2 ?AND_A_DA OR 0=   \ if neither of these, then
                IF      [ASM1600]         \ assemble an OR instruction
                        OR      A A             a;
                        [FORTH]
                THEN    POP_A
                [TARGET] ;

I: OPT_ELSE     ( -- f1 )
                [FORTH]
                2 #?OPT                         \ optimizable,
                2 ?RET                          \ a RET opcode?
                HERE-T 1- ECS: C@L AND          \ and an inst extention byte
                4 #?OPT
                4 ?BRA_T                        \ BRA T,xxxx
                HERE-T 3 - ECS: C@L AND  OR     \ and an inst extention byte
                IF      -br# dup $:  01lab
                        27                      \ return pair match value 27
                        TRUE
                ELSE    FALSE
                THEN    [TARGET] ;

\ **********************************************************************

>LIBRARY

LMACRO IF        ( f -- )        \ branch if flag is zero
                [FORTH]
                OPT_ANDIF
                [ASM1600] F['] Z=1 ,JUMP
                ?REOPT
                3                               \ return matching pair 3
                END-LMACRO       NO-INTERPRET

LMACRO WHILE     ( f1 -- )
                7 ?pairs
                [TARGET]
                f['] IF >execute execute
                [FORTH]
                drop 8
                [ASM1600]
                END-LMACRO       NO-INTERPRET

LMACRO ELSE      ( -- )          \ ELSE portion of IF ELSE THEN conditionals
                [forth]
                3 ?pairs                \ check for matching previous IF
                OPT_ELSE 0=
        IF      [ASM1600]
                branch_mark             \ mark start of a branch operation
                F['] ALWAYS ,JUMP
                BR#SWAP
                -br# dup $:  01lab
                3                       \ return pair match value 3
                [FORTH]
        THEN    END-LMACRO       NO-INTERPRET

LMACRO THEN      ( n1 -- )       \ resolve branch with matching pair checking
                [forth]
                dup 27 <>               \ if type 27, then optimized
                IF      [ASM1600]
                        3 ?pairs                \ check matching branch type
                        -br# dup $:  01lab
                        [forth]
                ELSE    drop
                THEN    OPT_OFF1
                END-LMACRO       NO-INTERPRET

' THEN ALIAS ENDIF


LMACRO REPEAT    ( -- )          \ branch back portion of BEGIN WHILE REPEAT
                8 ?pairs                \ conditional match check
                branch_mark             \ mark start of a branch operation
                br#swap
                F['] ALWAYS ,UNTIL
                -br# dup $:  01lab
                END-LMACRO       NO-INTERPRET

LMACRO UNTIL     ( f1 -- )       \ conditional branch back of BEGIN UNTIL
                7 ?pairs        \ check branch pairing
                OPT_ANDIF
                F['] Z=1 ,UNTIL
                END-LMACRO       NO-INTERPRET

LMACRO FOR       ( n1 -- )       \ mark start of FOR NEXT looping structure
                [ASM1600]
                ld stack a      a;
                pop_a           a;
                [target]
                +br# $:
                OPT_OFF1
                5                               \ return matching pair 3
                END-LMACRO       NO-INTERPRET

LMACRO NEXT      ( -- )          \ branch back portion of FOR NEXT structure
                5 ?pairs                \ check for matching previous FOR
                branch_mark             \ mark start of a branch operation
                ld      a (R6)
                ld      x a
                add     a FFFF
                ld      (R6) a
                ld      a x
                or      a a     a;
                F['] Z=0 ,UNTIL a;
                ld      x (R6-)
                END-LMACRO       NO-INTERPRET

\ **********************************************************************

CODE EXECUTE    ( a1 -- )       \ execute (as in DOIT) the function whose
                                \ address is a1.
                branch_mark             \ mark start of a branch operation
                ld      x a
                pop_a
                ld      pc x            \ immediate branch to address
                END-CODE        NO-INTERPRET

\ **********************************************************************

FORTH   >FORTH

I: NOTSUPPORTED ( -- )
                0 " Function is not supported in this target" "errmsg
                ; IMMEDIATE

' NOTSUPPORTED IS COMP_SAVE             \ link into compiler
' NOTSUPPORTED IS COMP_SAVEST           \ link into compiler
' NOTSUPPORTED IS COMP_REST             \ link into compiler

\ **********************************************************************

TARGET  >LIBRARY

\ **********************************************************************

CODE @          ( a1 -- n1 )    \ fetch a word at the specified address
                ld      r0 a
                ld      a (r0)
                ret
                END-CODE        NO-INTERPRET

\ **********************************************************************

FORTH   >FORTH

I: %@           ( -- )  \ compile a call to fetch
                F['] @ RES_COMP_CALL ; IMMEDIATE

' %@ IS COMP_FETCH            \ link into compiler

TARGET  >LIBRARY

\ **********************************************************************

CODE !          ( n1 a1 -- )    \ store a word at the specified address
                ld      r0 a
                pop_a
                ld      (r0) a
                pop_a
                ret
                END-CODE        NO-INTERPRET

FORTH   >FORTH

I: %!           ( -- )  \ compile a call to store on each reference
                F['] ! RES_COMP_CALL ; IMMEDIATE

' %! IS COMP_STORE            \ link into compiler

TARGET  >LIBRARY

\ **********************************************************************

CODE +!         ( n1 a1 -- )    \ add "n" to the contents at address a1
                pop_x
                ld r0 a
                ld a (r0)
                add a x
                ld (r0) a
                pop_a
                ret
                END-CODE        NO-INTERPRET

\ **********************************************************************

FORTH   >FORTH

' NOTSUPPORTED IS COMP_PSTORE    \ link into compiler

TARGET  >LIBRARY

\ **********************************************************************

MACRO DROP      ( <n1> -- ) \ remove top element from parameter stack
                pop_a
                END-MACRO       EXECUTES> DROP

MACRO 2DROP     ( <n1> <n2> -- ) \ remove two elements from parameter stack
                pop_x
                pop_a
                END-MACRO       NO-INTERPRET

MACRO DUP       ( <n1> -- <n1> <n1> ) \ duplicate top element of param stack
                push_a
                END-MACRO       EXECUTES> DUP

CODE 2DUP       ( <n1> <n2> -- <n1> <n2> <n1> <n2> )
                ld      x (R6)
                push_a
                push_x
                ret
                END-CODE        EXECUTES> 2DUP

CODE SWAP       ( <n1> <n2> -- <n2> <n1> ) \ exchange top param stack items
                pop_x
                push_a
                ld      a x
                ret
                END-CODE        EXECUTES> SWAP

CODE OVER       ( <n1> <n2> -- <n1> <n2> <n1> ) \ copy 2nd on param stack
                ld      x (R6)
                push_a
                ld      a x
                ret
                END-CODE        EXECUTES> OVER

MACRO NIP       ( <n1> <n2> -- <n2> ) \ remove 2nd on param stack
                pop_x
                END-MACRO       EXECUTES> NIP

CODE ROT        ( <n1> <n2> <n3> -- <n2> <n3> <n1> ) \ rotate 3 of param stk
                pop_x
                pop_y
                push_x
                push_a
                ld      a y
                ret
                END-CODE        EXECUTES> ROT

CODE -ROT       ( <n1> <n2> <n3> -- <n3> <n1> <n2> ) \ rotate 3 of param stk
                pop_x
                pop_y
                push_a
                push_y
                ld      a x
                ret
                END-CODE        EXECUTES> -ROT

CODE ?DUP       ( <n1> -- <[n1]> <n1> ) \ dup top stack item, unless <>0
                or      a a
                BRA     z=1 0 $
                push_a
           0 $: ret
                END-CODE        EXECUTES> ?DUP

\ **********************************************************************
\ Logical stack operations
\ **********************************************************************

MACRO AND       ( <n1> <n2> -- <n3> ) \ logical and function
                and     a (R6-)
                END-MACRO       EXECUTES> AND

MACRO OR        ( <n1> <n2> -- <n3> ) \ logical or function
                or      a (R6-)
                END-MACRO       EXECUTES> OR

MACRO XOR       ( <n1> <n2> -- <n3> ) \ logical xor function
                eor     a (R6-)
                END-MACRO       EXECUTES> XOR

MACRO NOT       ( <n1> -- <n2> ) \ n2 = complement of n1
                eor     a FFFF
                END-MACRO       EXECUTES> NOT

CODE ON         ( addr -- )
                ld      r0 a
                ldi     (r0) $FFFF
                pop_a
                ret
                END-CODE        NO-INTERPRET

CODE OFF        ( addr -- )
                ld      r0 a
                ldi     (r0) $0000
                pop_a
                ret
                END-CODE        NO-INTERPRET


FORTH   >FORTH

' NOTSUPPORTED IS COMP_ON         \ link into compiler
' NOTSUPPORTED IS COMP_OFF        \ link into compiler

TARGET  >LIBRARY

\ **********************************************************************

CODE INCR       ( a1 -- )       \ add one to the contents at address a1
                ld r0 a
                ld a (r0)
                addi 1
                ld (r0) a
                pop_a
                ret
                END-CODE        NO-INTERPRET

\ **********************************************************************

FORTH   >FORTH

' NOTSUPPORTED IS COMP_INCR       \ link into compiler

TARGET  >LIBRARY

\ **********************************************************************

CODE DECR       ( a1 -- )       \ add one to the contents at address a1
                ld r0 a
                ld a (r0)
                add a FFFF
                ld (r0) a
                pop_a
                ret
                END-CODE        NO-INTERPRET

\ **********************************************************************

FORTH   >FORTH

' NOTSUPPORTED IS COMP_DECR       \ link into compiler

TARGET  >LIBRARY

\ **********************************************************************

CODE +          ( <n1> <n2> -- <n3> )    \ n3 = n1 + n2
                pop_x
                add     a x
                END-CODE        EXECUTES> +

CODE -          ( n1 n2 -- n1-n2 )
                ld      x a
                pop_a
                sub     a x
                END-CODE        EXECUTES> -

MACRO NEGATE    ( <n1> -- <n2> )         \ n2 = -n1
                mod always neg
                END-MACRO       EXECUTES> NEGATE

MACRO ABS       ( <n1> -- <n2> ) \ n2 = absolute value of n1
                mod always abs
                END-MACRO       EXECUTES> ABS

MACRO 2*        ( <n1> -- <n2> ) \ n2 = 2*n1 ( left shift by one)
                mod always shl
                END-MACRO       EXECUTES> 2*

MACRO 2/        ( <n1> -- <n2> ) \ n2 = n1/2 ( right shift by one)
                mod always shr
                END-MACRO       EXECUTES> 2/

MACRO 1+        ( <n1> -- <n2> ) \ n2 = n1+1
                mod always inc
                END-MACRO       EXECUTES> 1+

MACRO 2+        ( <n1> -- <n2> ) \ n2 = n1+2
                mod always inc
                mod always inc
                END-MACRO       EXECUTES> 2+

MACRO 1-        ( <n1> -- <n2> ) \ n2 = n1-1
                mod always dec
                END-MACRO       EXECUTES> 1-

MACRO 2-        ( <n1> -- <n2> ) \ n2 = n1-2
                mod always dec
                mod always dec
                END-MACRO       EXECUTES> 2-

\ **********************************************************************
\                       Logical operators
\ **********************************************************************

CODE 0=         ( <n1> -- <flag> ) \ return a true flag if n1 = 0
                or      a a
                ldi     0
                BRA     z=0 0 $
                eor     a FFFF
           0 $: ret
                END-CODE        NO-INTERPRET

CODE 0<         ( <n> -- <flag> ) \ return a true flag if n < 0
                or      a a
                ldi     0
                bra     n=0 0 $
                eor     a FFFF
           0 $: ret
                END-CODE        NO-INTERPRET

CODE 0>         ( <n> -- <flag> ) \ return a true flag if n > 0
                or      a a
                ldi     0
                bra     n=1 0 $
           0 $: eor     a FFFF
                ret
                END-CODE        NO-INTERPRET

CODE =          ( <n1> <n2> -- <flag> ) \ flag = true if n1 = n2
                pop_x
                sub     a x
                ldi     0
                bra     z=0 0 $
                eor     a FFFF
           0 $: ret
                END-CODE        NO-INTERPRET

CODE <>         ( <n1> <n2> -- <flag> ) \ flag = true if n1 <> n2
                pop_x
                sub     a x
                ldi     0
                bra     z=1 0 $
                eor     a FFFF
           0 $: ret
                END-CODE        NO-INTERPRET

CODE U<         ( <n1> <n2> -- <flag> ) \ return a true flag if n1 u< n2
                ld x a
                pop_a
                cmp     a x
                ldi     0
                bra     ov=0 0 $         \ jump if n1 u< n2 (high part)
                eor     a FFFF
           0 $: ret
                END-CODE        NO-INTERPRET

CODE U>         ( <n1> <n2> -- <flag> ) \ flag = true if n1 u> n2
                ld x a
                pop_a
                sub     a x
                ldi     0
                bra     ov=1 0 $      \ jump if n2 u< n1 (high part)
                eor     a FFFF
           0 $: ret
                END-CODE        NO-INTERPRET

\ **********************************************************************

CODE DEPTH      ( -- <n> )
                push_a
                ldi     a $00FF
                sub     a r7
                ret
                END-CODE        EXECUTES> DEPTH

LMACRO ?EXIT     ( f1 -- )       \ If boolean f1 is true, exit from definition.
                OPT_ANDIF
                F['] Z=1 ,JUMP
                ret a;                    \ true, return
                -br# [FORTH] dup [ASM1600] $: 01lab
                OPT_OFF1
                END-LMACRO       NO-INTERPRET

$00 CONSTANT FALSE
$FF CONSTANT TRUE

VARIABLE BASE

: DECIMAL       ( -- )
                $0A BASE C! ;    EXECUTES> DECIMAL

: HEX           ( -- )
                $10 BASE C! ;    EXECUTES> HEX

: OCTAL         ( -- )
                $08 BASE C! ;    EXECUTES> OCTAL

: BINARY        ( -- )
                $02 BASE C! ;    EXECUTES> BINARY

CODE CM-@       ( <code adr> -- <word> ) \ fetch a word from code memory
                ld      r0 a
                ld      a ((r0))
                ret
                END-CODE        NO-INTERPRET

\ **********************************************************************
\ Return stack operations
\ **********************************************************************

MACRO >R        ( <n> -- )  ( R: -- <n> ) \ pop param stack to return stack
                ld stack a
                pop_a
                END-MACRO       NO-INTERPRET

MACRO R@        ( -- <n> )      \ copy return stack to param stack
                push_a
                ld      a stack
                ld      stack a
                END-MACRO       NO-INTERPRET

MACRO R>        ( -- <n> )  ( R: <n> -- ) \ pop return stack to param stack
                push_a
                ld      a stack
                END-MACRO       NO-INTERPRET

MACRO R>DROP    ( -- )            \ pop and discard a return stack value
                ld      x stack
                END-MACRO       NO-INTERPRET

MACRO DUP>R     ( n1 -- n1 )      \ duplicate n1 on the return stack
                ld      stack a
                END-MACRO       NO-INTERPRET

MACRO NOOP      ( -- )          \ A do nothing function, just uses clocks
                bra always 0 $
        0 $:    END-MACRO       NO-INTERPRET


>FORTH

