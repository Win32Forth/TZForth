\ BASLIBS8.SEQ           Target Library Source           by Tom Zimmer

\ ***************************************************************************
\ Target specific words used by the compiler to complete compilation of
\ the the various types of library and target definitions.  These words
\ will need to be re-written when a new traget is being written.

\ ***************************************************************************
\                       Target Library words
\ ***************************************************************************

>LIBRARY                \ set compiler to create library definitions

TARGET DEFINITIONS      \ select the target vocabulary for all definitions

\ Macros for pushing/popping R0/R1 and popping R2/R3

MACRO PUSH_R0   ( -- )
                pushui  @r psp r0
                END-MACRO

MACRO PUSH_R1   ( -- )
                pushui  @r psp r1
                END-MACRO

MACRO PUSH_R2   ( -- )
                pushui  @r psp r2
                END-MACRO

MACRO PUSH_R3   ( -- )
                pushui  @r psp r3
                END-MACRO

MACRO PUSH_R4   ( -- )
                pushui  @r psp r4
                END-MACRO

MACRO POP_R0    ( -- )
                popud   r0 @r psp
                END-MACRO

MACRO POP_R1    ( -- )
                popud   r1 @r psp
                END-MACRO

MACRO POP_R2    ( -- )
                popud   r2 @r psp
                END-MACRO

MACRO POP_R3    ( -- )
                popud   r3 @r psp
                END-MACRO

MACRO POP_R4    ( -- )
                popud   r4 @r psp
                END-MACRO

\ ***************************************************************************
\ This macro puts a literal number on the data stack. The instructon
\ sequence used is not optimal, but is likely to be optimized later

FORTH >FORTH
                                \ working regs: r0, r1
I: (LIT)        ( n1 -- )       \ Compile an number to be pushed on the stack
                >R A;
                [FORTH] R> SPLIT >R >R
                3 #?OPT 0=
                HERE-T  3 - C@-T $92   <> OR    \ POPUD
                HERE-T  2 -  @-T $C7C1 <> OR    \ @R7 R1
                IF      [ASMS8]
                        PUSH_R1         A;      \ push current stack top
                        [FORTH]
                ELSE    3 1 DEL_B/I             \ discard 3 bytes & 1 inst
                THEN    [ASMS8]
                        INST-RESET              \ hide lit from assembler
                        [ASMS8]
                        LD R1 # R>      A;
                        [FORTH]
                        R@ $01 $FE BETWEEN      \ IF between $100 to $FEFF
                        ?16-BIT OR
                        IF      [ASMS8]         \ then auto make it a double
                                PUSH_R1    A;
                                LD R1 # R@ A;
                                [FORTH]
                                ?16-BIT 0=
                           IF   0 " Bad litaral, outside range for a BYTE"
                                "errmsg
                           ELSE OFF> ?16-BIT
                           THEN
                        THEN    R>DROP          \ discard high byte
                        [TARGET] ; IMMEDIATE

' (LIT) IS COMP_SINGLE \ link into number compiler

FORTH >FORTH

\ **********************************************************************

I: ?PUSH_R1     ( f1 n1 -- f2 ) \ check at NEGATIVE offset n1 for PUSH_R1
                [FORTH]         \ accumulate "AND" into flag f1
                >R
                HERE-T  R@ -    C@-T $83   = AND      \ PUSHUI
                HERE-T  R> - 1+  @-T $C7C1 = AND ;    \ @R7 R1

\ I: ?POP_R0    ( f1 n1 -- f2 ) \ check at NEGATIVE offset n1 for POP_R0
\               [FORTH]         \ accumulate "AND" into flag f1
\               >R
\               HERE-T  R@ -    C@-T $92   = AND      \ POPUI
\               HERE-T  R> - 1+  @-T $C7C0 = AND ;    \ @R7 R0

                \ Make words that are "internal", that check at a
                \ NEGATIVE offset of n2 for the presence of byte n1
I: BYTE_TEST    ( n1 -<name>- )         \ compile time
                ( f1 n2 -- f2 )         \ runtime
                [FORTH]
                beheadable
                if      ['] iheader %save!> header      \ make internal
                        CREATE
                        %restore> header
                else    CREATE                          \ else external
                then    C, DOES> C@ HERE-T ROT - C@-T = AND ;

$04 BYTE_TEST ?ADD_R_R1         \ check for ADD R xx R1
$56 BYTE_TEST ?AND_R1_#         \ check for AND R1 # xx
$54 BYTE_TEST ?AND_R1_R         \ check for AND R1 R xx
$1C BYTE_TEST  ?LD_R1_#         \ check for LD  R1 # xx
$18 BYTE_TEST  ?LD_R1_R         \ check for LD  R1 R xx
$19 BYTE_TEST  ?LD_R_R1         \ check for LD  R xx R1
$E5 BYTE_TEST  ?LD_R1_@R        \ check for LD  R1 @R xx
$AF BYTE_TEST  ?RET             \ check for RET INSTRUCTION
$8D BYTE_TEST  ?JMP_T           \ check for JMP T INSTRUCTION
$8B BYTE_TEST  ?JR_T            \ check for JR T INSTRUCTION

\ **********************************************************************

FORTH

0 VALUE PREV_COND_ADDR          \ previous conditional address
0 VALUE PREV_COND_CODE          \ previous conditional code word
  DEFER PREV_COND_FUNC          \ function to perform

: COND!         ( a1 a2 -- )    \ setup a conditional information save
                                \ a1=the CFA of the conditional word
                                \ a2=the CFA of a MACRO ONLY
                [FORTH]
                ?if_opt
                IF      HERE-T !> PREV_COND_ADDR
                        >EXECUTE !> PREV_COND_FUNC
                        DUP !> PREV_COND_CODE
                ELSE    DROP
                        -1 !> PREV_COND_ADDR
                THEN    RES_COMP_CALL
                [TARGET] ;

I: FORWARD_CLR  ( -- )
                [FORTH]
                PREV_COND_CODE
                >CHAIN DUP @ -1 <>              \ if chain has info
                IF      DUP @ @-T OVER !        \ unlink one occurance
                        RES> DUP PREV_COND_CODE <>
                                                \ discard one res stack item
                        IF      DUP >RES        \ if not equal, put it back
                        THEN    DROP
                        -1 PREV_COND_CODE >COUNT +! \ set count to zero
                THEN    DROP ;

I: PREV_COND_ERR ( -- )
                0 " Previous conditional detected improperly" "errmsg ;

I: OPT_IF1      ( -- f1 )       \ optimize previous branch, f1=true if
                [FORTH]         \ we couldn't optimize
                HERE-T 3 - PREV_COND_ADDR =
                IF      FORWARD_CLR     \ clear possible forward reference
                        3 1 DEL_B/I     \ discard the CALL
                        PREV_COND_FUNC
                        -1 !> PREV_COND_ADDR
                        FALSE
                ELSE    TRUE
                THEN    F['] PREV_COND_ERR IS PREV_COND_FUNC ;

I: OPT_ANDIF    ( -- )
                [FORTH]
                6 #?OPT
                6 ?PUSH_R1                 \ and immediate with push
                3 ?AND_R1_#
                IF      HERE-T 1- C@-T >R  \ get the register xx
                        6 2 DEL_B/I        \ delete bytes & insts
                        branch_mark        \ mark start of a branch operation
                        [ASMS8]
                        tm      R1 # R>         a;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
                6 #?OPT
                6 ?PUSH_R1                 \ and register with push
                3 ?AND_R1_R
                IF      HERE-T 2- C@-T >R  \ get the register xx
                        6 2 DEL_B/I        \ delete bytes & insts
                        branch_mark        \ mark start of a branch operation
                        [ASMS8]
                        tm      R1 R R>         a;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
                8 #?OPT
                8 ?PUSH_R1              \ and register with imm and push
                5 ?LD_R1_R
                3 ?AND_R1_#
                IF      HERE-T 1- C@-T >R  \ get the register xx
                        HERE-T 4 - C@-T >R \ get the register yy
                        8 3 DEL_B/I        \ delete bytes & insts
                        branch_mark        \ mark start of a branch operation
                        [ASMS8]
                        tm      R R> ( yy ) # R> ( xx ) a;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
                3 #?OPT
                3 ?PUSH_R1              \ DUP preceeding IF
                IF      3 1 DEL_B/I     \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASMS8]
                        or      R1 R1           a;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
                branch_mark             \ and immediate or register, no push
                TRUE 3 ?AND_R1_#
                TRUE 3 ?AND_R1_R OR 0=  \ if neither of these, then
                IF      [ASMS8]         \ assemble an OR instruction
                        or      r1 r1           a;
                        [FORTH]
                THEN    pop_r1
                [TARGET] ;

I: OPT_IF2      ( -- )
                [FORTH]
                5 #?OPT
                5 ?PUSH_R1
                2 ?LD_R1_R
                IF      HERE-T 1 - C@-T >R \ get the register xx
                        5 2 DEL_B/I        \ delete bytes & insts
                        branch_mark        \ mark start of a branch operation
                        [ASMS8]
                        or      R R@ R R>       a;
                        [FORTH]
                ELSE    OPT_ANDIF
                THEN    [TARGET] ;


I: OPT_ELSE     ( -- f1 )
                [FORTH]
                1 #?OPT                         \ optimizable,
                1 ?RET                          \ a RET opcode?
                HERE-T 1- ECS: C@L AND          \ and an inst extention byte
                2 #?OPT
                2 ?JR_T                         \ JR T,xx
                HERE-T 2 - ECS: C@L AND  OR     \ and an inst extention byte
                3 #?OPT
                3 ?JMP_T                        \ JMP T,xxxx
                HERE-T 3 - ECS: C@L AND  OR     \ and an inst extention byte
                IF      -br# dup $:  01lab
                        27                      \ return pair match value 27
                        TRUE
                ELSE    FALSE
                THEN    [TARGET] ;

I: ,JUMP        ( n1 -- )
                [FORTH]
                >R
                ?LONG
                IF      [ASMS8]
                        jp      R> EXECUTE +br# $       a;
                        [FORTH]
                ELSE    [ASMS8]
                        jr      R> EXECUTE +br# $       a;
                        [FORTH]
                THEN    ?long_set
                [ASMS8] ?REOPT ;

\ **********************************************************************

TARGET  >LIBRARY

                                \ working regs: r1
LMACRO ?BRANCH   ( f -- )        \ branch if flag is zero
                [FORTH]
                OPT_IF1
        IF      OPT_IF2
                [ASMS8] F['] Z ,JUMP
                [FORTH]
        THEN    [ASMS8] ?REOPT
                3                               \ return matching pair 3
                END-LMACRO

' ?BRANCH >EXECUTE IS COMP_?BRANCH

                                \ working regs: NONE
LMACRO BRANCHRES ( -- )          \ ELSE portion of IF ELSE THEN conditionals
                [forth]
                off> exec:ing2?         \ no more data words, use CALLs
                3 ?pairs                \ check for matching previous IF
                OPT_ELSE 0=
        IF      [asms8]
                branch_mark             \ mark start of a branch operation
                F['] T ,JUMP
                BR#SWAP
                -br# dup $:  01lab
                3                       \ return pair match value 3
                [FORTH]
        THEN    END-LMACRO

' BRANCHRES >EXECUTE IS COMP_BRANCHRES

                                \ working regs: NONE
LMACRO RESOLVE   ( n1 -- )       \ resolve branch with matching pair checking
                [forth]
                off> exec:ing2?         \ no more data words, use CALLs
                dup 27 <>               \ if type 27, then optimized
                IF      [asms8]
                        3 ?pairs                \ check matching branch type
                        -br# dup $:  01lab
                        [forth]
                ELSE    drop
                THEN    OPT_OFF1
                END-LMACRO

' RESOLVE >EXECUTE IS COMP_RESOLVE

                                \ working regs: r0, r1, r2, r3
LCODE (DO)      ( <lim> <initial-index> -- ) \ run-time for do
                pop_r3
                add             r3 # $80     \ limit + 80 -> limit'
                pop             r0           \ save return address
                pop             r2
                push            r3           \ push limit' on return stack
                sub             r1 r3        \ index - limit' -> index'
                push            r1           \ push index' on return stack
                push            r2
                push            r0           \ push return address
                pop_r1
                ret
                END-LCODE

LCODE (DO2)     ( <lim> <initial-index> -- ) \ run-time for do
                pop             r0           \ save return address
                pop             r4
                push            r3           \ push limit' on return stack
                push            r2           \ push index' on return stack
                push            r4
                push            r0           \ push return address
                ret
                END-LCODE

                                \ working regs: NONE
LMACRO %dohere   ( -- )
                +br# $:
                END-LMACRO

LMACRO (do1)     ( n1 -- )
                [forth]
                >R A;
                [asms8]
                LDW R2 # R> A;
                END-LMACRO

FORTH   >FORTH

I: DO_OPT?      ( -- f1 )
                A; [FORTH]
                10 #?OPT
                10 ?PUSH_R1
                 7 ?LD_R1_#                     \ DO LOOP limit value
                 5 ?PUSH_R1
                 2 ?LD_R1_#                     \ DO LOOP start value
                IF      HERE-T 6 - C@-T $80 +   \ limit value
                        HERE-T 1 - C@-T OVER -  \ start value
                        JOIN                    \ make one word
                        10 4 DEL_B/I            \ delete bytes & insts
                        TRUE
                        [FORTH]
                ELSE    FALSE
                THEN    ?REOPT [TARGET]
                ;

I: %DO          ( <limit> <starting index> -- )
                [forth]
\                ?doing   off
                do_opt?
                if      [asms8]
                        f['] (do1) >execute execute
                        F['] (do2) RES_COMP_CALL
                        [forth]
                else    [asms8]
                        F['] (do) RES_COMP_CALL
                        [forth]
                then    [asms8]
                f['] %dohere >execute execute
                a; 6 ;                  \ return matching pair 6

                                \ working regs: r0, r1, r2, r3
LCODE I         ( -- n )        \  get the current index of the innermost loop
                push_r1
                ld              r0 r spl
                ld              r1 2 (r0)
                ld              r3 3 (r0)
                add             r1 r3
                ret
                END-LCODE

: DO            ( I-addr -- )
                %do
                F['] I RES_COMP_CALL
                comp_single comp_store ;

' DO IS COMP_DO

                                \ working regs: r0, r1, r2
LCODE (+LOOP)   ( <n> -- ) \ run-time for +loop
                ld              r2 r spl
                add             r2 # 2
                ld              r0 @r2
                add             r0 r1
                pop_r1
                ld              @r2 r0
                ret
                END-LCODE

                                \ working regs: NONE
LMACRO UNDO      ( -- )          \ un DOes what DO does in a DO LOOP structure
                                \ cleans up the return stack of DO stuff
                add             r spl # 2       \ discard loop parmeters
                END-LMACRO

                                \ working regs: NONE
LMACRO BACKBR    ( -- )          \ branch back primitive MACRO for LOOP
                [FORTH]
                ?LONG
                IF      [ASMS8]
                        jp      nov -br#  dup>r  $ a; r> 01lab
                        [FORTH]
                ELSE    [ASMS8]
                        jr      nov -br# dup>r $ a; r> 01lab
                        [FORTH]
                THEN    ?long_set
                [TARGET] ?REOPT    END-LMACRO

: %+LOOP       ( -- )
                F['] (+LOOP) RES_COMP_CALL
                F['] BACKBR  >EXECUTE EXECUTE
                F['] UNDO    >EXECUTE EXECUTE ;

' %+LOOP IS COMP_LOOP

\ **********************************************************************
\ Stack operators
\ **********************************************************************

LCODE SWAP      ( <n1> <n2> -- <n2> <n1> ) \ exchange top param stack items
                pop_r0
                push_r1
                ld              r1 r0
                ret
                END-LCODE

I: %SWAP        ( n1 n2 -- n2 n1 )
                ['] SWAP RES_COMP_CALL ;

' %SWAP IS COMP_SWAP            \ link into compiler

LCODE _ROT      ( <n1> <n2> <n3> -- <n2> <n3> <n1> ) \ rotate 3 of param stk
                ld              r0 r1
                pop_r2
                pop_r1
                pushui          @r psp r2
                pushui          @r psp r0
                ret
                END-LCODE

I: ROT          ( -- )
                F['] _ROT RES_COMP_CALL ;

' ROT IS COMP_ROT                       \ link to compiler

                                \ working regs: r0, r1, r2
LCODE _-ROT     ( <n1> <n2> <n3> -- <n3> <n1> <n2> ) \ rotate 3 of param stk
                pop_r2
                popud           r0 @r psp
                push_r1
                pushui          @r psp r0
                ld              r1 r2
                ret
                END-LCODE

I: -ROT         ( -- )
                F['] _-ROT RES_COMP_CALL ;

' -ROT IS COMP_-ROT                     \ link to compiler

\ **********************************************************************
\ Memory operators
\ **********************************************************************

FORTH   >FORTH

I: NOTSUPPORTED ( -- )
                0 " Function is not supported in this target" "errmsg
                ; IMMEDIATE

TARGET >LIBRARY

' NOTSUPPORTED IS COMP_FETCH              \ link into compiler
' NOTSUPPORTED IS COMP_STORE      \ link to compiler

                                \ working regs: r1
MACRO REG-C@    ( a1 -- c1 )    \ fetch a byte from a register variable
                [FORTH]
                2 #?OPT
                2 ?LD_R1_#
                IF      HERE-T 1- C@-T  >R      \ get the register xx
                        2 1 DEL_B/I             \ delete bytes & insts
                        [ASMS8]
                        LD              R1 R R> ( xxx ) A;
                        [FORTH]
                ELSE    0 " MUST be preceeded by a literal register" "errmsg
                THEN    [TARGET]
                END-MACRO

' REG-C@ >EXECUTE IS COMP_CFETCH              \ link into compiler

\ **********************************************************************

FORTH >FORTH

I: OPT_C!1      ( -- f1 )       \ optimize "dup reg c!"
                A; [FORTH]
                8 #?OPT
                8 ?PUSH_R1
                5 ?PUSH_R1
                2 ?LD_R1_#                      \ LD      R1 # xx
                IF      HERE-T 1- C@-T  >R      \ get the register xx
                        8 3 del_b/i             \ delete 8 bytes & 3 insts
                        [ASMS8]
                        LD      R R> ( xxx ) R1 A;
                        [FORTH]
                        ?REOPT TRUE             \ all done no further
                                                \ optimization possible
                ELSE    FALSE
                THEN    [TARGET]
                ;

I: OPT_C!1A     ( -- f1 )       \ optimize "reg c!"
                A; [FORTH]
                5 #?OPT
                5 ?PUSH_R1
                2 ?LD_R1_#
                IF      HERE-T 1- C@-T  >R      \ get the register xx
                        5 2 DEL_B/I             \ delete bytes & insts
                        [ASMS8]
                        LD      R R> ( xx ) R1  A;
                        [FORTH]
                        TRUE
                ELSE    FALSE
                THEN    [TARGET]
                ;

I: OPT_C!2      ( -- f1 )    \ optimize "push number reg c!"
                [FORTH]
                7 #?OPT
                7 ?PUSH_R1
                4 ?LD_R1_#
                2 ?LD_R_R1
                IF      HERE-T 3 - C@-T >R      \ get the source        xx
                        HERE-T 1-  C@-T >R      \ get the destination   yy
                        7 3 DEL_B/I             \ delete bytes & insts
                        1 RPICK 0=              \ if setting to zero, use CLR
                        IF      [ASMS8]
                                CLR     R R>            A;
                                [FORTH]
                                R>DROP
                        ELSE    [ASMS8]
                                LD      R R> # R>       A;
                                [FORTH]
                        THEN    ?REOPT TRUE
                ELSE    FALSE
                THEN    [TARGET] ;

I: OPT_C!2A     ( -- f1 )    \ optimize "number reg c!"
                [FORTH]
                4 #?OPT
                4 ?LD_R1_#
                2 ?LD_R_R1
                IF      HERE-T 3 - C@-T >R      \ get the source        xx
                        HERE-T 1-  C@-T >R      \ get the destination   yy
                        4 2 DEL_B/I             \ delete bytes & insts
                        1 RPICK 0=              \ if setting to zero, use CLR
                        IF      [ASMS8]
                                CLR     R R>            A;
                                POP_R1                  A;
                                [FORTH]
                                R>DROP
                        ELSE    [ASMS8]
                                LD      R R> # R>       A;
                                POP_R1                  A;
                                [FORTH]
                        THEN    ?REOPT TRUE
                ELSE    FALSE
                THEN    [TARGET] ;

I: OPT_C!3      ( f1 -- f1 )    \ optimize "push reg c@ reg c!"
                [FORTH]
                7 #?OPT
                7 ?PUSH_R1
                4 ?LD_R1_R
                2 ?LD_R_R1
                IF      HERE-T 3 - C@-T >R      \ get the source        xx
                        HERE-T 1-  C@-T >R      \ get the destination   yy
                        7 3 DEL_B/I             \ delete bytes & insts
                        [ASMS8]
                        LD      R R> R R>       A;
                        [FORTH]
                        ?REOPT TRUE
                ELSE    FALSE
                THEN    [TARGET] ;

I: OPT_C!3A     ( -- f1 )    \ optimize "reg c@ reg c!"
                [FORTH]
                4 #?OPT
                4 ?LD_R1_R
                2 ?LD_R_R1
                IF      HERE-T 3 - C@-T >R      \ get the source        xx
                        HERE-T 1-  C@-T >R      \ get the destination   yy
                        4 2 DEL_B/I             \ delete bytes & insts
                        [ASMS8]
                        LD      R R> R R>       A;
                        POP_R1                  A;
                        [FORTH]
                        ?REOPT TRUE
                ELSE    FALSE
                THEN    [TARGET] ;

I: OPT_C!4      ( -- f1 )    \ optimize "reg c@ reg c@ c!"  pointer operation
                [FORTH]
                10 #?OPT
                10 ?PUSH_R1
                7 ?LD_R1_R
                5 ?PUSH_R1
                2 ?LD_R1_R
                IF      HERE-T 6 - C@-T >R      \ get the source        xx
                        HERE-T 1-  C@-T >R      \ get the destination   yy
                        10 4 DEL_B/I            \ delete bytes & insts
                        [ASMS8]
                        LD      @R R> R R>      A;
                        [FORTH]
                        ?REOPT TRUE
                ELSE    FALSE
                THEN    [TARGET] ;

I: OPT_C!4A     ( -- f1 )    \ optimize "number reg c@ c!"  pointer operation
                [FORTH]
                10 #?OPT
                10 ?PUSH_R1
                7 ?LD_R1_#
                5 ?PUSH_R1
                2 ?LD_R1_R
                IF      HERE-T 6 - C@-T >R      \ get the source        xx
                        HERE-T 1-  C@-T >R      \ get the destination   yy
                        10 4 DEL_B/I            \ delete bytes & insts
                        1 RPICK 0=              \ if setting to zero, use CLR
                        IF      [ASMS8]
                                CLR     @R R>           A;
                                [FORTH]
                                R>DROP
                        ELSE    [ASMS8]
                                LD      @R R> # R>      A;
                                [FORTH]
                        THEN    ?REOPT TRUE
                ELSE    FALSE
                THEN    [TARGET] ;

I: OPT_C!4B     ( -- f1 )    \ optimize "reg c@ c!"     pointer operation
                [FORTH]
                5 #?OPT
                5 ?PUSH_R1
                2 ?LD_R1_R
                IF      HERE-T 1-  C@-T >R      \ get the destination   yy
                        5 2 DEL_B/I             \ delete bytes & insts
                        [ASMS8]
                        LD      @R R> R1        A;
                        POP_R1                  A;
                        [FORTH]
                        ?REOPT TRUE
                ELSE    FALSE
                THEN    [TARGET] ;

                                \ working regs: r1
I: %REG-C!      ( c1 a1 -- )    \ store a byte into a register variable
                [FORTH]
                OPT_C!1                 ?EXIT
                OPT_C!1A
                IF      OPT_C!2         ?EXIT
                        OPT_C!2A        ?EXIT
                        OPT_C!3         ?EXIT
                        OPT_C!3A        ?EXIT
                        [ASMS8]
                        POP_R1          A;
                        [FORTH]
                ELSE    0 " MUST be preceeded by a literal register" "errmsg
                THEN    [TARGET] ;

TARGET  >LIBRARY

\ **********************************************************************

                                \ working regs: r1
MACRO REG-C!    ( c1 a1 -- )    \ store a byte into a register variable
                [FORTH]
                ( F['] ) %REG-C! ( EXECUTE )
                [TARGET]
                END-MACRO

' REG-C! >EXECUTE IS COMP_CSTORE      \ link to compiler

' NOTSUPPORTED IS COMP_CFETCHL                   \ link to compiler
' NOTSUPPORTED IS COMP_CSTOREL                   \ link to compiler

\ **********************************************************************
\ Logical operators
\ **********************************************************************

                                \ working regs: r1
MACRO NOT       ( <n1> -- <n2> ) \ n2 = complement of n1
                com             r1
                END-MACRO

TARGET ' NOT >EXECUTE IS COMP_NOT         \ link to compiler

\ **********************************************************************
\ Optimizer for add and subtract
\ **********************************************************************

FORTH   >FORTH

                                        \ f1=false for addition
                                        \ f1=true  for subtraction
I: OPT_+-       ( f1 -- true )          \ optimize double immediate
                ( f1 -- false )         \ don't optimize
                >R A; [FORTH]
                7 #?OPT
                7 ?LD_R1_#
                5 ?PUSH_R1
                2 ?LD_R1_#
                IF      HERE-T 1 - C@-T         \ get the second immediate
                        R@                      \ if non-zero, it's subtract
                        IF      NEGATE          \ so negate the value
                        THEN
                        HERE-T 6 -  C@-T +      \ get literal
                        DUP 255 >
                        IF      0 " Literal out of range for byte" "errmsg
                        THEN
                        HERE-T 6 - %C!-T        \ put new literal
                        5 2 DEL_B/I             \ delete bytes & insts
                        FALSE                   \ did optimize successfully
                        [FORTH]
                ELSE    TRUE                    \ can't optimize
                THEN    R>DROP
                ?REOPT [TARGET] ;

\ **********************************************************************
\ Memory optimizers
\ **********************************************************************

I: OPT_MEM      ( -- reg true  true )           \ optimize as immediate
                ( -- reg false true )           \ optimize as register
                ( -- false )                    \ don't optimize
                A; [FORTH]
                5 #?OPT
                5 ?PUSH_R1              \ optimizing
                2 ?LD_R1_#
                IF      HERE-T 1 - C@-T >R      \ get the register xx
                        5 2 DEL_B/I             \ delete bytes & insts
                        r> TRUE TRUE EXIT       \ **** EXIT HERE ****
                        [FORTH]
                THEN
                5 #?OPT
                5 ?PUSH_R1
                2 ?LD_R1_R
                IF      HERE-T 1 - C@-T         \ get the register xx
                        5 2 DEL_B/I             \ delete bytes & insts
                        FALSE TRUE
                ELSE    FALSE
                THEN    ?REOPT [TARGET]
                ;

I: OPT_MEM2     ( -- reg imm 1 true )   \ immediate
                ( -- reg imm 2 true )   \ immediate (no push)
                ( -- reg     3 true )   \ register
                ( -- reg imm 4 true )   \ register c@
                ( -- false )                    \ error, not optimizable
                A; [FORTH]
                10 #?OPT
                10 ?PUSH_R1             \ push number push number
                 7 ?LD_R1_#
                 5 ?PUSH_R1
                 2 ?LD_R1_#
                IF      HERE-T 1 - C@-T         \ get the register xx
                        HERE-T 6 - C@-T         \ get the immediate yy
                        10 4 DEL_B/I            \ delete bytes & insts
                        1 TRUE EXIT             \ **** EXIT HERE ****
                THEN
                7 #?OPT
                7 ?LD_R1_#              \ number push number
                5 ?PUSH_R1
                2 ?LD_R1_#
                IF      HERE-T 1 - C@-T         \ get the register xx
                        HERE-T 6 - C@-T         \ get the immediate yy
                        7 3 DEL_B/I             \ delete bytes & insts
                        2 TRUE EXIT             \ **** EXIT HERE ****
                THEN
                10 #?OPT
                10 ?PUSH_R1             \ push reg c@ push number
                 7 ?LD_R1_R
                 5 ?PUSH_R1
                 2 ?LD_R1_#
                IF      HERE-T 1 - C@-T         \ get the register xx
                        HERE-T 6 - C@-T         \ get the immediate yy
                        10 4 DEL_B/I            \ delete bytes & insts
                        4 TRUE EXIT             \ **** EXIT HERE ****
                THEN
                5 #?OPT
                5 ?PUSH_R1              \ push number
                2 ?LD_R1_#
                IF      HERE-T 1 - C@-T         \ get the register xx
                        5 2 DEL_B/I             \ delete bytes & insts
                        3 TRUE
                ELSE    0 " MUST be preceeded by a literal reg" "errmsg
                        FALSE
                THEN    ?REOPT [TARGET] ;

\ **********************************************************************
\       Optimizer for double C@ before comparison and IF
\ **********************************************************************

I: OPT_COMPARE  ( -- )  \ compile an optimized compare instruction
                [FORTH]
\ "REG C@ REG C@ COMPARE"
                10 #?OPT
                10 ?PUSH_R1
                 7 ?LD_R1_R
                 5 ?PUSH_R1
                 2 ?LD_R1_R
                IF      HERE-T 1 - C@-T >R      \ get the register xx
                        HERE-T 6 - C@-T >R      \ get the register xx
                        10 4 DEL_B/I            \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASMS8]
                        CP      R R> R R>       A;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
\ "REG C@ NUMBER COMPARE"
                10 #?OPT
                10 ?PUSH_R1
                 7 ?LD_R1_R
                 5 ?PUSH_R1
                 2 ?LD_R1_#
                IF      HERE-T 1 - C@-T >R      \ get the register xx
                        HERE-T 6 - C@-T >R      \ get the register xx
                        10 4 DEL_B/I            \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASMS8]
                        CP      R R> # R>       A;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
\ "REG C@ C@ NUMBER COMPARE"
                11 #?OPT
                11 ?PUSH_R1
                 8 ?LD_R1_@R
                 5 ?PUSH_R1
                 2 ?LD_R1_#
                IF      HERE-T 1 - C@-T >R      \ get the register #
                        HERE-T 7 - C@-T >R      \ get the register c@ c@
                        11 4 DEL_B/I            \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASMS8]
                        LD      R0 @R R>        A;
                        CP      R0 # R>         A;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
\ "REG C@ C@ REG C@ COMPARE"
                11 #?OPT
                11 ?PUSH_R1
                 8 ?LD_R1_@R
                 5 ?PUSH_R1
                 2 ?LD_R1_R
                IF      HERE-T 1 - C@-T >R      \ get the register xx
                        HERE-T 7 - C@-T >R      \ get the register xx
                        11 4 DEL_B/I            \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASMS8]
                        LD      R0 @R R>        A;
                        CP      R0 R R>         A;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
\ "DUP REG C@ COMPARE"                          \ 09/16/92 08:30 tjz added
                8 #?OPT
                8 ?PUSH_R1
                5 ?PUSH_R1
                2 ?LD_R1_R
                IF      HERE-T 1 - C@-T >R      \ get the register xx
                        8 3 DEL_B/I             \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASMS8]
                        CP      R1 R R>         A;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
\ "REG C@ COMPARE"
                5 #?OPT
                5 ?PUSH_R1
                2 ?LD_R1_R
                IF      HERE-T 1 - C@-T >R      \ get the register xx
                        5 2 DEL_B/I             \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASMS8]
                        CP      R1 R R>         A;
                        POP_R1                  A;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
\ "DUP NUMBER COMPARE"                          \ 09/16/92 08:30 tjz added
                8 #?OPT
                8 ?PUSH_R1
                5 ?PUSH_R1
                2 ?LD_R1_#
                IF      HERE-T 1 - C@-T >R      \ get the register xx
                        8 3 DEL_B/I             \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASMS8]
                        CP      R1 # R>         A;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
\ "NUMBER COMPARE"
                5 #?OPT
                5 ?PUSH_R1
                2 ?LD_R1_#
                IF      HERE-T 1 - C@-T >R      \ get the register xx
                        5 2 DEL_B/I             \ delete bytes & insts
                        branch_mark     \ mark start of a branch operation
                        [ASMS8]
                        CP      R1 # R>         A;
                        POP_R1                  A;
                        [FORTH]
                        EXIT                    \ ****** EXITS HERE
                THEN
\ sorry, no optimization possible
                [ASMS8]
                branch_mark     \ mark start of a branch operation
                POP_R0                  A;
                CP      R0 R1           A;
                POP_R1                  A;
                ?REOPT [TARGET] ;

TARGET  >LIBRARY

\ **********************************************************************
\ Logical stack operations
\ **********************************************************************

                                \ working regs: r1
MACRO AND       ( <n1> <n2> -- <n3> ) \ logical and function
                [forth]
                opt_mem
                if      if      >r
                                [asms8]
                                and     r1 # r>         a;
                                [forth]
                        else    >r
                                [asms8]
                                and     r1 r r>         a;
                                [forth]
                        then
                else    [asms8]
                        and     r1 @r psp       a;
                        dec     r psp           a;
                        [forth]
                then    [target]
                END-MACRO

' AND >EXECUTE IS COMP_AND         \ link to compiler

                                \ working regs: r1
MACRO OR        ( <n1> <n2> -- <n3> ) \ logical or function
                [forth]
                opt_mem
                if      if      >r
                                [asms8]
                                or      r1 # r>         a;
                                [forth]
                        else    >r
                                [asms8]
                                or      r1 r r>         a;
                                [forth]
                        then
                else    [asms8]
                        or      r1 @r psp       a;
                        dec     r psp           a;
                        [forth]
                then    [target]
                END-MACRO

' OR >EXECUTE IS COMP_OR        \ link to compiler

                                \ working regs: r1
MACRO XOR       ( <n1> <n2> -- <n3> ) \ logical xor function
                [forth]
                opt_mem
                if      if      >r
                                [asms8]
                                xor     r1 # r>         a;
                                [forth]
                        else    >r
                                [asms8]
                                xor     r1 r r>         a;
                                [forth]
                        then
                else    [asms8]
                        xor     r1 @r psp       a;
                        dec     r psp           a;
                        [forth]
                then    [target]
                END-MACRO

' XOR >EXECUTE IS COMP_XOR         \ link to compiler

\ **********************************************************************
\ Math opoerators
\ **********************************************************************


\ **********************************************************************

                                \ working regs: r1
MACRO +         ( <n1> <n2> -- <n3> )    \ n3 = n1 + n2
                [forth]
                0 opt_+-
        if      opt_mem
                if      if      dup 1 =                 \ if immediate one
                                if      drop            \ then use INC R1
                                        [asms8]
                                        inc     r1              a;
                                        [forth]
                                else    >r
                                        [asms8]
                                        add     r1 # r>         a;
                                        [forth]
                                then
                        else    >r
                                [asms8]
                                add     r1 r r>         a;
                                [forth]
                        then
                else    [asms8]
                        add     r1 @r psp       a;
                        dec     r psp           a;
                        [forth]
                then
        then    [target]
                END-MACRO

' + >EXECUTE IS COMP_+           \ link to compiler

                                \ working regs: r1
MACRO -         ( n1 n2 -- n1-n2 )
                [forth]
                -1 opt_+-
        if      opt_mem
                if      if      dup 1 =                 \ if immediate one
                                if      drop            \ use DEC R1
                                        [asms8]
                                        dec     r1              a;
                                        [forth]
                                else    >r
                                        [asms8]
                                        sub     r1 # r>         a;
                                        [forth]
                                then
                        else    >r
                                [asms8]
                                sub     r1 r r>         a;
                                [forth]
                        then
                else    [asms8]
                        pop_r0                  a;
                        sub     r0 r1           a;
                        ld      r1 r0           a;
                        [forth]
                then
        then    [target]
                END-MACRO

' - >EXECUTE IS COMP_-           \ link to compiler

                                \ working regs: r1, r2, r3
LCODE *         ( <n1> <n2> -- <n3> ) \ n3 = n1*n2
                pop_r2
                mult            rr2 r1
                ld              r1 r3
                ret
                END-LCODE

I: %*           ( -- )
                F['] * RES_COMP_CALL ;

' %* IS COMP_*           \ link to compiler

                                \ working regs: r0, r1, r2, r3
LCODE /         ( <unum> <udiv> -- <uquot> ) \ div
                pop_r3
                clr             r2
                div             rr2 r1
                ld              r1 r3
                ret
                END-LCODE

I: %/           ( -- )
                F['] / RES_COMP_CALL ;

' %/ IS COMP_/                           \ link to compiler

                                \ working regs: r0, r1, r2, r3
LCODE MOD       ( n1 n2 -- urem )         \ unsigned short modulous
                clr             r2              \  udiv <= 255
                div             rr2 r1
                ld              r1 r2           \  09/22/92 15:42 tjz added
\                ld              r1 r psp
\                ld              @r psp r2
                sub             r psp # 1       \  09/22/92 15:42 tjz added
                ret
                END-LCODE

I: %MOD         ( -- )
                F['] MOD RES_COMP_CALL ;

' %MOD IS COMP_MOD                       \ link to compiler

                                \ working regs: r1
MACRO NEGATE    ( <n1> -- <n2> )         \ n2 = -n1
                com             r1
                inc             r1
                END-MACRO

' NEGATE >EXECUTE IS COMP_NEGATE        \ link to compiler

' NOTSUPPORTED IS COMP_PC@         \ link to compiler

' NOTSUPPORTED IS COMP_PC!              \ link to compiler

\ **********************************************************************
\ Comparison words
\ **********************************************************************

                                \ working regs: r0, r1
CODE (=)        ( <n1> <n2> -- <flag> ) \ flag = true if n1 = n2
                pop_r0
                cp              r0 r1
                clr             r1
                jr              ne 0 $
                com             r1
           0 $: ret
                END-CODE

LMACRO =IF       ( -- )
                OPT_COMPARE
                F['] NE ,JUMP
                END-LMACRO

                                \ working regs: r0, r1
LMACRO =         ( <n1> -- <flag> ) \ return a true flag if n1 = 0
                F['] (=) F['] =IF COND!
                END-LMACRO

' = >EXECUTE IS COMP_=           \ link to compiler

                                \ working regs: r0, r1
CODE (<>)       ( <n1> <n2> -- <flag> ) \ flag = true if n1 <> n2
                pop_r0
                cp              r0 r1
                clr             r1
                jr              eq 0 $
                com             r1
           0 $: ret
                END-CODE

LMACRO <>IF      ( -- )
                OPT_COMPARE
                F['] EQ ,JUMP
                END-LMACRO

                                \ working regs: r0, r1
LMACRO <>        ( <n1> -- <flag> ) \ return a true flag if n1 = 0
                F['] (<>) F['] <>IF COND!
                END-LMACRO

' <> >EXECUTE IS COMP_<>          \ link to compiler

                                \ working regs: r0, r1
CODE (U<)       ( <n1> <n2> -- <flag> ) \ return a true flag if n1 u< n2
                pop_r0
                cp              r0 r1
                clr             r1
                jr              uge 0 $         \ jump if n1 u< n2 (high part)
                com             r1
           0 $: ret
                END-CODE

LMACRO U<IF      ( -- )
                OPT_COMPARE
                F['] UGE ,JUMP
                END-LMACRO

                                \ working regs: r0, r1
LMACRO U<        ( <n1> -- <flag> ) \ return a true flag if n1 = 0
                F['] (U<) F['] U<IF COND!
                END-LMACRO

' U< >EXECUTE IS COMP_<                  \ link to compiler

                                \ working regs: r0, r1
CODE (U>)       ( <n1> <n2> -- <flag> ) \ flag = true if n1 u> n2
                pop_r0
                cp              r0 r1
                clr             r1
                jr              ule 0 $      \ jump if n2 u< n1 (high part)
                com             r1
           0 $: ret
                END-CODE

LMACRO U>IF      ( -- )
                OPT_COMPARE
                F['] ULE ,JUMP
                END-LMACRO

                                \ working regs: r0, r1
LMACRO U>        ( <n1> -- <flag> ) \ return a true flag if n1 = 0
                F['] (U>) F['] U>IF COND!
                END-LMACRO

' U> >EXECUTE IS COMP_>                  \ link to compiler

: <=            ( n1 n2 -- f )
                f['] U>  >execute execute
                f['] NOT >execute execute ;

' <= IS COMP_<=                         \ link to compiler

: >=            ( n1 n2 -- f )
                f['] U<  >execute execute
                f['] NOT >execute execute ;

' >= IS COMP_>=                         \ link to compiler


