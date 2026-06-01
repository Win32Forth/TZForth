\ OPT5.SEQ      Library Optimizers for 6805 Target Compiler     A. McKewan

ONLY FORTH ASM6805 ALSO FORTH ALSO COMPILER ALSO TARGET ALSO

>FORTH

COMPILER DEFINITIONS

: TVER  ."  6805 Version 2.00" ;
' TVER IS TVERSION              \ install startup message

/HIGH-LOW                            \ this processor places words in
                                     \ memory with the high byte in low mem.

' NOOP IS DATA-SEG-FIX               \ not a segmented machine

: ?PAIRS        ( n1 n2 -- )         \ make sure n1=n2, or error
                <>
                if      0 " Conditional Branch UNBALANCED" "errmsg
                then    ;

WARNING OFF                     \ NO REDEFINITION WARNING IN LIBRARY
FORTH                           \ we want a Forth NOT a target variable
2VARIABLE IMM-HERE              \ Most recent place where immediate move
                                \ to BX was compiled
VARIABLE CALL-HERE              \ Most recent place where call subroutine
                                \ was compiled

\ ***************************************************************************
\ Adjust compiler for 6805 target

' NOOP IS DATA-SEG-FIX          \ No need to fixup data segment

: %%set_cold_entry  ( -- )
                here-t cold_start !-t ;

' %%set_cold_entry is set_cold_entry

: %%resolve_1   ( a1 -- )               \ resolve one reverence to HERE-T
                here-t swap !-T ;       \ use absolute addresses
' %%resolve_1 is resolve_1              \ link in default resolver


$050 dup dp-d ! =: data-start
$100 dup dp-t ! =: code-start

\ ***************************************************************************
\ Optimizer for exit.  If the exit is preceeded by a call instruction,
\ replace the call with a jump.  Otherwise compile a return instruction.
\ THIS PREVENTS US FROM USING INLINE WORDS WHICH ASSUME A TERMINATING RTS !!

: EXIT_OPT      ( -- )
                [FORTH]
                ?OPT
        IF
                HERE-T 3 -                      \ address of call instruction
                DUP C@-T $CD =                  \ JSR opcode
                OVER CALL-HERE @ = AND
                OVER OPT_LIMIT U> AND
                IF
                        $CC OVER C!-T           \ patch JMP opcode
                        =: LINESTRT             \ reset listing pointer
                        .INST                   \ show instruction
                ELSE
                        DROP                    \ discard address
                        [ASM6805]
                        RTS                     \ just compile rts
                        [FORTH]
                THEN
        ELSE
                ?REOPT
                [ASM6805]
                RTS                             \ just compile rts
                [FORTH]
        THEN    ;

\ ***************************************************************************
\ New function for END-CODE, needs to not use REVEAL

ASM6805 also forth also

: CEND-CODE     ( -- )
                ll-global? 0=
                if      ll-errs?        \ check for local label errors
                then
                ARUNSAVE IS RUN
                PREVIOUS A; ;

previous previous target

: %END-MACRO    ( -- )          \ complete assembly of a MACRO
                ?reopt
                [ASM6805]
                compile a;                      \ make sure ASM6805 is done
                compile llset-
                compile cend-code               \ pop ASM6805 vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-MACRO IS END-MACRO       \ install in END-MACRO

I: %END-LMACRO  ( -- )          \ complete assembly of a MACRO
                ?reopt
                [asm6805]
                compile a;                      \ make sure assembler is done
                compile cend-code               \ pop assembler vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-LMACRO IS END-LMACRO     \ install in END-LMACRO

: %END-LCODE    ( -- )          \ complete assembly of a LCODE
                ?reopt
                [ASM6805]
                compile a;                      \ make sure ASM6805 is done
                compile cend-code               \ pop ASM6805 vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-LCODE IS END-LCODE       \ install in END-LCODE

: %END-L:       ( -- )          \ complete a library CALL definition
                [ASM6805]
                compile setassem
\                compile rts
\                compile a;                      \ make sure ASM6805 is done
                COMPILE EXIT_OPT
                compile cend-code               \ pop ASM6805 vocabulary
                compile unnest ;                \ complete colon def

' %END-L: IS END-L:

: %END-LM:      ( -- )          \ complete a library MACRO : definition
                [ASM6805]
                compile setassem
                compile cend-code
                compile unnest ;                \ complete colon def

' %END-LM: IS END-LM:

: %END-T:       ( -- )          \ complete a target CALL definition
                [ASM6805]
                setassem                \ do ASM6805 setup
\                rts a;                  \ terminate with a RET instruction
                EXIT_OPT
                fend-code ;             \ do ASM6805 finishup

' %END-T: IS END-T:

' NOOP IS START-T:              \ no start needed in CALL threaded system

: %COMP_CALL    ( a1 -- )                       \ a1 = CFA of symbol
                ?REOPT
                HERE-T CALL-HERE !
                [ASM6805]
                $CD IC,                         \ compile JSR
                [FORTH]
                dup     >resaddr @ dup -1 <>    \ if resolved already
                if      [ASM6805]
                        OFFSET_16,              \ resolve this call
                        [FORTH]
                        >count incr             \ bump use count
                                        \ ELSE, add it to the chain of
                else    drop                    \ discard the "-1"
                                                \ references to be resolved.
                        dup >chain @ O,         \ link chain @ to here
                        here-t 2- over >chain ! \ link here into chain
                        >res                    \ add to resolution stack
                then    ;

' %COMP_CALL IS COMP_CALL

: %COMP_JMP_IMM ( a1 -- )                      \ a1 = actual address
                [ASM6805]
                $CC IC, OFFSET_16, ;

' %COMP_JMP_IMM IS COMP_JMP_IMM

: %SUB_RET      ( -- )
                -1 ALLOT-T ;            \ remove a one byte RET instruction
                                        \ preceeding us in memory

' %SUB_RET IS SUB_RET

: %TCODE-START  ( -- )
                setassem
                [assembler]
                llab-init ;

' %TCODE-START IS TCODE-START

: %LCODE-START  ( -- )
                compile tcode-start     \ initialize the ASM6805
                ASM6805 ;             \ and select ASM6805 vocabulary now!

' %LCODE-START IS LCODE-START

I: %%MACRO-START ( -- )
                llset+
                setassem
                [assembler]
                init_labels ;

I: %MACRO-START ( -- )
                compile %%macro-start     \ initialize the assembler
                asm6805 ;             \ and select assembler vocabulary now!

' %MACRO-START IS MACRO-START

I: %%LMACRO-START ( -- )
                setassem
                [assembler]
                init_labels ;

I: %LMACRO-START ( -- )
                compile %%lmacro-start     \ initialize the assembler
                asm6805 ;             \ and select assembler vocabulary now!

' %LMACRO-START IS LMACRO-START

\ I: %FIX-CREATE-DOES ( a1 -- a2 )        \ test and modify target address
\                 [FORTH]                 \ to the target data address if a1
\                                         \ points at a create does word
\                 dup     %c@-t $89 =             \ LD EA, # xx
\                 over 2+ %c@-t $52 = and         \ JPS yyyy
\                 if      1+ %c@-t                \ fetch the target data addr
\                 else    on> ?16-bit             \ if not creat does>
\                                                 \ then return word address
\                 then    ;
\
\ ' %FIX-CREATE-DOES IS FIX-CREATE-DOES   \ patch into compiler at FORDOES
\                                         \ in COMPILE2.SEQ

\ ***************************************************************************
\ Modified defining words

: VARIABLE  1 ARRAY ;


\ ***************************************************************************
\ Start of the set of functions supported in the target compiler.
\ These are mostely macros which will compile in-line assembly code.
\ Colon definitions are compiled as routines when defined, and are
\ accessed by a CALL when referenced.

ONLY FORTH ALSO COMPILER ALSO HOST ALSO TARGET ALSO DEFINITIONS
ASM6805 ALSO

>LIBRARY                        \ Select the Library versions of
                                \ defining words.

\ ***************************************************************************
\ Variables used by Forth Kernel:

8 ARRAY STACK           \ Data stack
4 ARRAY TEMP            \ Temps for code words
3 ARRAY %LOOP           \ FOR/NEXT loop stack

>FORTH
: SP0  STACK 8 + ;      \ Top of data stack
>LIBRARY

LMACRO IMAGE-INIT ( -- )        \ Target compiler runtime initialization
        0 $:    SEI
                RSP
                LDX # $50
        1 $:            CLR 0 X
                        INC X
                        BNE 1 $         \ clear ram
                LDX # SP0               \ RESET STACK
                JSR $1000 a;            \ CALL real program (gets patched)
                here-t 2- =: cold_start \ set patch pointer
                BRA 0 $
                END-LMACRO

FORTH DEFINITIONS >FORTH

: TARGET-INIT   ( -- )          \ initialize the terget compiler
                [FORTH]
                ?LIB ABORT" Can't use TARGET-INIT in a library routine"
                ONLY HOST ALSO
                FORTH TARGET ALSO DEFINITIONS
                FORTH ASM6805 ALSO
                0 !> >in_word
                $100      org
                $40      vorg
                $50      dorg
                >target-mem                     \ select compiling to target
                ['] tinterp is interpret
                ['] %.loadline is .loadline
                tcode-start
                >target         \ select target defining words
                target          \ Select the target vocabulary
                lihere !> linestrt
\+ xIC,         ['] xIC, is IC,                 \ install for indexer
\ \+ xCC,         ['] xCC, is CC,
\+ index!       othertype here-t index!         \ copy source starting marker
                [FORTH]
                0 SAVE!> CURFIL#                \ save and clear curfil#
                F['] IMAGE-INIT                 \ address of init routine

                DUP >COUNT INCR                 \ mark it used and
                        >EXECUTE EXECUTE        \ compile it
                RESTORE> CURFIL#                \ no source available here
                ; IMMEDIATE

' TARGET-INIT IS TARGET-INITIALIZE


\ ***************************************************************************
\                           OPTIMIZERS !!
\ ***************************************************************************
\ PUSH and POP macros

ASM6805 DEFINITIONS
: PUSH,         DEC X STA 0 X A; ;
: POP,          LDA 0 X INC X A; ;

COMPILER DEFINITIONS
: PUSH          ( -- )
                [ASM6805] PUSH, [COMPILER]
                ?REOPT ;

: PUSH_OPT      ( -- f )
                ?OPT
        IF      HERE-T 2- @-T $5AF7 =           \ X DEC,  0 ,X STA,
                OPT_LIMIT HERE-T 2- U< AND
                IF      -2 ALLOT-T              \ if it matches, discard
                                                \ previously compiled 2 bytes
                        LIHERE =: LINESTRT
                        2 #del_index            \ delete the previous inst(s)
                        TRUE                    \ return true flag
                ELSE    FALSE
                THEN
        ELSE    ?REOPT
                FALSE
        THEN    ;


: POP           ( -- )
                PUSH_OPT NOT
        IF      [ASM6805]
                POP,
                [COMPILER]
        THEN    ;


\ ***************************************************************************
\ Literal/Memory optimize.  If previous instrucion was a literal, remove
\ compiled code and return value and a flag of -1.  If previous instruction
\ was a memory fetch, remove compiled code and return address and a flag
\ of 1.  Otherwise return a zero flag.
\
\ LIT_OPT     looks for:        xxx # LDA,  X DEC,  0 ,X STA,
\
\ LIT/MEM_OPT looks for:        xxx # LDA,  X DEC,  0 ,X STA,
\                    or:        xxx ) LDA,  X DEC,  0 ,X STA,
\

COMPILER DEFINITIONS

: LIT_OPT       ( -- <xxxx> f1 )                \ literal optimize
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 4 - C@-T $A6   =         \ xx # LDA,
                HERE-T 2 -  @-T $5AF7 = AND     \ X DEC,  0 ,X STA,
                OPT_LIMIT HERE-T 4 - U< AND
                IF      HERE-T 3 - C@-T         \ get the value xx
                        -4 ALLOT-T              \ if it matches, discard
                                                \ previously compiled 4 bytes
                        LIHERE =: LINESTRT      \ and return value
                        3 #del_index            \ delete the previous inst(s)
                        TRUE                    \ return -1 for literal
                ELSE    FALSE
                THEN
        ELSE    ?REOPT
                FALSE
        THEN    ;

: LIT/MEM?      ( byte -- f )   \ true if lda immediate or direct
                $EF AND $A6 = ;

: LIT/MEM-FLAG  ( byte -- f )   \  -1 = literal, 1 = memory
                $A6 = 2* 1+ ;

: LIT/MEM_OPT   ( -- <xxxx> f1 )                \ literal/memory optimize
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 4 - C@-T LIT/MEM?        \ xx # LDA, or xx LDA,
                HERE-T 2 -  @-T $5AF7 = AND     \ X DEC,  0 ,X STA,
                OPT_LIMIT HERE-T 4 - U< AND
                IF      HERE-T 3 - C@-T         \ get the value xx
                        HERE-T 4 - C@-T LIT/MEM-FLAG    \ and flag
                        -4 ALLOT-T              \ if it matches, discard
                                                \ previously compiled 4 bytes
                        3 #del_index            \ delete the previous inst(s)
                        LIHERE =: LINESTRT      \ and return value
                ELSE
                        0
                THEN
        ELSE    ?REOPT
                0
        THEN    ;

: PUSH_LIT/MEM_OPT   ( -- <xxxx> f1 )   \ push then literal/memory optimize
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 6 -  @-T $5AF7 =         \ X DEC,  0 ,X STA,
                HERE-T 4 - C@-T LIT/MEM? AND    \ xx # LDA, -or- xx LDA,
                HERE-T 2 -  @-T $5AF7 = AND     \ X DEC,  0 ,X STA,
                OPT_LIMIT HERE-T 6 - U< AND
                IF      HERE-T 3 - C@-T         \ get the value xx
                        HERE-T 4 - C@-T LIT/MEM-FLAG    \ and flag
                        -6 ALLOT-T              \ if it matches, discard
                                                \ previously compiled 6 bytes
                        5 #del_index            \ delete the previous inst(s)
                        LIHERE =: LINESTRT      \ and return value
                ELSE
                        0
                THEN
        ELSE    ?REOPT
                0
        THEN    ;

: LIT_LIT_OPT   ( -- <xx yy> f1 )               \ double literal optimize
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 8 - C@-T $A6 =           \ xx # LDA,
                HERE-T 6 -  @-T $5AF7 = AND     \ X DEC,  0 ,X STA,
                HERE-T 4 - C@-T $A6   = AND     \ yy # LDA,
                HERE-T 2 -  @-T $5AF7 = AND     \ X DEC,  0 ,X STA,
                OPT_LIMIT HERE-T 8 - U< AND
                IF      HERE-T 7 - C@-T         \ get the value xx
                        HERE-T 3 - C@-T         \ get the value yy
                        -8 ALLOT-T              \ if it matches, discard
                                                \ previously compiled 4 bytes
                        LIHERE =: LINESTRT      \ and return value
                        6 #del_index            \ delete the previous inst(s)
                        TRUE
                ELSE
                        FALSE
                THEN
        ELSE    ?REOPT
                FALSE
        THEN    ;


\ ***************************************************************************
\ Optimizer for binary operators ( + - AND OR XOR )

FORTH VARIABLE %CFA

: BINARY        ( cfa opcode -- )
                [FORTH]
                >R  %CFA !
                LIT/MEM_OPT ?DUP
        IF      0<
                IF      LIT/MEM_OPT ?DUP
                        IF      0<
                                IF      R> DROP
                                        SWAP %CFA @ EXECUTE
                                        >R
                                        [ASM6805]
                                        ( xxx_op_yyy ) LDA # R> A;
                                        [FORTH]
                                        PUSH A;
                                ELSE    >R
                                        [ASM6805]
                                        LDA R> ( xxx ) A;
                                        ( yyy ) R> $A0 + C, C, ( # OP )
                                        [FORTH]
                                        PUSH A;
                                THEN
                        ELSE
                                [ASM6805]
                                LDA 0 X A;
                                ( xxx ) R> $A0 + C, C, ( # OP )
                                STA 0 X A;
                                [FORTH]
                        THEN
                ELSE    LIT/MEM_OPT ?DUP
                        IF      0<
                                IF      >R
                                        [ASM6805]
                                        LDA # R> ( xxx ) A;
                                        ( yyy ) R> $B0 + C, C, ( MEM OP )
                                        [FORTH]
                                        PUSH A;
                                ELSE    >R
                                        [ASM6805]
                                        ( xxx ) LDA R> A;
                                        ( yyy ) R> $B0 + C, C, ( MEM OP )
                                        [FORTH]
                                        PUSH A;
                                THEN
                        ELSE
                                [ASM6805]
                                LDA 0 X A;
                                ( xxx ) R> $B0 + C, C, ( MEM OP )
                                STA 0 X A;
                                [FORTH]
                        THEN
                THEN
        ELSE
                POP A;
                [ASM6805]
                R@ $F0 + C, ( 0 ,X OP )
                [FORTH]
          R> 0= IF      ( subtract )
                        [ASM6805]
                        NEG A A;
                        [FORTH]
                THEN
                [ASM6805]
                STA 0 X A;
                [FORTH]
        THEN    ;


\ **********************************************************************
\ Sam8 Version of listing program invocation function
\ **********************************************************************

: %make_listing ( -- )          \ build a listing file
                [ hidden ]
                closeall
                ."  Invoking .LST generator.. [press Ctrl-Break to cancel]"
                " ls5 "                 pad place       \ batch file
                listing.name >pathend"  pad +place      \ append file
                cr space pad count type cr
                pad $sys drop                           \ make listing
                at? at cr ;

' %make_listing is make_listing         \ link into compiler

TARGET DEFINITIONS

>LIBRARY

