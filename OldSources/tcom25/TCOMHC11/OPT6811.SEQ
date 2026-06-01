\ OPT6811.SEQ   Library Optimizers for 6811 Target Compiler     T. Zimmer
\ based on:
\ OPT5.SEQ      Library Optimizers for 6805 Target Compiler     A. McKewan

ONLY FORTH ASM6811 ALSO FORTH ALSO COMPILER ALSO TARGET ALSO

>FORTH

COMPILER DEFINITIONS

: TVER  ."  6811 Version .02" ;
' TVER IS TVERSION              \ install startup message

/HIGH-LOW                            \ this processor places words in
                                     \ memory with the high byte in low mem.

' NOOP IS DATA-SEG-FIX               \ not a segmented machine

: ?PAIRS        ( n1 n2 -- )         \ make sure n1=n2, or error
                <>
                if      0 " Conditional Branch UNBALANCED" "errmsg
                then    ;

makedefer commas>blanks fcommas>blanks

' noop is commas>blanks         \ disable comma conversion

makedefer ?sizecheck f?sizecheck

' noop is ?sizecheck            \ disable code size checking

WARNING OFF                     \ NO REDEFINITION WARNING IN LIBRARY
FORTH                           \ we want a Forth NOT a target variable
2VARIABLE IMM-HERE              \ Most recent place where immediate move
                                \ to BX was compiled
VARIABLE CALL-HERE              \ Most recent place where call subroutine
                                \ was compiled

\ ***************************************************************************
\ Adjust compiler for 6811 target

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
                DUP C@-T $BD =                  \ JSR opcode
                OVER CALL-HERE @ = AND
                OVER OPT_LIMIT U>  AND
                IF      $7E OVER C!-T   \ patch JMP opcode
                        =: LINESTRT     \ reset listing pointer
                        .INST           \ show instruction
                ELSE
                        DROP                    \ discard address
                        [ASM6811]
                        RTS                     \ just compile rts
                        [FORTH]
                THEN
        ELSE
                ?REOPT
                [ASM6811]
                RTS                             \ just compile rts
                [FORTH]
        THEN    ;

: %RESOLVE_OPT  ( a1 -- )       \ tail resolution optimization for
                                \ forward referenced tail CALLs
                A; [FORTH]                      \ preceeded by a
                DUP >COUNT @ 2 =                \ usage count is exactly 1
                                                \ although the count is 2
                ?OPT AND                        \ optimization is on?
                HERE-T 3 - C@-T    $7E =  AND   \ JMP
                HERE-T 2-   @-T HERE-T =  AND   \ to me
                3 #?OPT                   AND
                IF      3 1 DEL_B/I             \ delete bytes & instructions
                        HERE-T OVER >RESADDR !  \ RE-resolve symbol
                        curfil#_save save!> curfil#   \ restore save curfil#
\+ index!               :othertype here-t index!
                        restore> curfil#
                THEN    DROP
                OPT_OFF1  ;             \ disable optimization for one time

' %resolve_opt is resolve_opt   \ link into compiler

\ ***************************************************************************
\ New function for END-CODE, needs to not use REVEAL

ASM6811 also forth also

: CEND-CODE     ( -- )
                ll-global? 0=
                if      ll-errs?        \ check for local label errors
                then
                ARUNSAVE IS RUN
                PREVIOUS A; ;

previous previous target

: %END-MACRO    ( -- )          \ complete assembly of a MACRO
                ?reopt
                [ASM6811]
                compile a;                      \ make sure ASM6811 is done
                compile llset-
                compile cend-code               \ pop ASM6811 vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-MACRO IS END-MACRO       \ install in END-MACRO

I: %END-LMACRO  ( -- )          \ complete assembly of a MACRO
                ?reopt
                [asm6811]
                compile a;                      \ make sure assembler is done
                compile cend-code               \ pop assembler vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-LMACRO IS END-LMACRO     \ install in END-LMACRO

: %END-LCODE    ( -- )          \ complete assembly of a LCODE
                ?reopt
                [ASM6811]
                compile a;                      \ make sure ASM6811 is done
                compile cend-code               \ pop ASM6811 vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-LCODE IS END-LCODE       \ install in END-LCODE

: %END-L:       ( -- )          \ complete a library CALL definition
                [ASM6811]
                compile setassem
                COMPILE EXIT_OPT
                compile cend-code               \ pop ASM6811 vocabulary
                compile unnest ;                \ complete colon def

' %END-L: IS END-L:

: %END-LM:      ( -- )          \ complete a library MACRO : definition
                [ASM6811]
                compile setassem
                compile cend-code
                compile unnest ;                \ complete colon def

' %END-LM: IS END-LM:

: %END-T:       ( -- )          \ complete a target CALL definition
                [ASM6811]
                setassem                \ do ASM6811 setup
                EXIT_OPT
                fend-code ;             \ do ASM6811 finishup

' %END-T: IS END-T:

' NOOP IS START-T:              \ no start needed in CALL threaded system

: %COMP_CALL    ( a1 -- )                       \ a1 = CFA of symbol
                ?REOPT
                HERE-T CALL-HERE !
                [ASM6811]
                $BD IC,                         \ compile JSR
                [FORTH]
                dup     >resaddr @ dup -1 <>    \ if resolved already
                if      [ASM6811]
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
                [ASM6811]
                $7E IC, OFFSET_16, ;

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
                compile tcode-start     \ initialize the ASM6811
                ASM6811 ;             \ and select ASM6811 vocabulary now!

' %LCODE-START IS LCODE-START

I: %%MACRO-START ( -- )
                llset+
                setassem
                [assembler]
                init_labels ;

I: %MACRO-START ( -- )
                compile %%macro-start     \ initialize the assembler
                asm6811 ;             \ and select assembler vocabulary now!

' %MACRO-START IS MACRO-START

I: %%LMACRO-START ( -- )
                setassem
                [assembler]
                init_labels ;

I: %LMACRO-START ( -- )
                compile %%lmacro-start     \ initialize the assembler
                asm6811 ;             \ and select assembler vocabulary now!

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

\ keep a list of the most recent 10 instructions opcode bytes and their
\ target addresses in a memory array, so we can easily recover then for
\ optimization testing.

FORTH

20 CONSTANT #OPS

CREATE OPLIST #OPS 1+ 3 * ALLOT \ a list of addresses of opcode bytes
                                \ and opcodes themselves

: OPLIST+       ( n1 a1 -- n1 ) \ add opcode n1 at address a1 to opcode list
                [FORTH]
                OPLIST DUP 3 + #OPS 3 * CMOVE>  \ make a hole for entry
                OPLIST !                        \ add the address
                DUP OPLIST 2+ C! ;              \ add the opcode

: OPLIST-       ( n1 -- )       \ remove n1 items from OPLIST
                [FORTH]
                3 * OPLIST + OPLIST #OPS 3 * CMOVE ;

: OP@           ( n1 -- n2 )    \ get opcode byte n1
                [FORTH]
                3 * OPLIST + 2+ C@ ;

: OP&           ( n1 -- a1 )    \ get opcode target address
                [FORTH]
                3 * OPLIST + @ ;

: DEL_OP        ( n1 -- )       \ delete n1 instructions from EVERYWHERE!
                >R HERE-T R@ 1- OP& - R@ DEL_B/I
                R> OPLIST- ;

: ?OP_OPT       ( n1 -- f1 )    \ can n1 instructions be optimized?
                [forth]
                HERE-T SWAP 1- OP& - #?OPT ;

: 68xIC,        ( n1 -- )       \ compile an instruction first byte
                HERE-T OPLIST+ xIC, ;

\ ***************************************************************************
\ Start of the set of functions supported in the target compiler.
\ These are mostely macros which will compile in-line assembly code.
\ Colon definitions are compiled as routines when defined, and are
\ accessed by a CALL when referenced.

ONLY FORTH ALSO COMPILER ALSO HOST ALSO TARGET ALSO DEFINITIONS
ASM6811 ALSO

>LIBRARY                        \ Select the Library versions of
                                \ defining words.

\ ***************************************************************************
\ Variables used by Forth Kernel:

80h CONSTANT SP0

LMACRO IMAGE-INIT ( -- )        \ Target compiler runtime initialization
        0 $:    SEI
                LDS # $FE               \ init the return stack
                LDX # SP0               \ init the data stack
                JSR $1000 a;            \ CALL real program (gets patched)
                here-t 2- =: cold_start \ set patch pointer
                BRA 0 $
                END-LMACRO

FORTH DEFINITIONS >FORTH

: TARGET-INIT   ( -- )          \ initialize the terget compiler
                [FORTH]
                ?LIB ABORT" Can't use TARGET-INIT in a library routine"
                ONLY  HOST    ALSO
                FORTH TARGET  ALSO DEFINITIONS
                FORTH ASM6811 ALSO
                0 !> >in_word
                $FFFE     org                   \ Reset vector is here I think
                $0100     ,-T                   \ point at program start
                $0100     org                   \ code starts here
                $0010    dorg                   \ data starts here?
                >target-mem                     \ select compiling to target
                ['] tinterp is interpret
                ['] %.loadline is .loadline
                tcode-start
                >target         \ select target defining words
                target          \ Select the target vocabulary
                lihere !> linestrt
                ['] 68xIC, is IC,               \ install for indexer
                othertype here-t index!         \ copy source starting marker
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

ASM6811 DEFINITIONS
: PUSH,         DEX
                STAA 0 X
                A; ;

: POP,          LDAA 0 X
                INX
                A; ;

COMPILER DEFINITIONS

\    67  0142  A6 00               LDAA $00,X
\    68  0144  08                  INX

: PUSH          ( -- )
                [FORTH]
                1 OP@ $A6 =                  \ LDAA 0,X   look for POP
                0 OP@ $08 = AND              \ INX
                2 ?OP_OPT   AND
                IF      2 DEL_OP             \ delete bytes and instructions
                ELSE
                        0 OP@ $08 =          \ INX        look for NIP
                        1 ?OP_OPT   AND
                        IF      1 DEL_OP     \ delete bytes and instructions
                                [ASM6811]
                                STAA 0 X A;
                                [FORTH]
                        ELSE
                                [ASM6811]
                                PUSH, A;
                                [FORTH]
                        THEN
                THEN    [COMPILER]
                ?REOPT ;

\    69  0145  09                  DEX
\    70  0146  A7 00               STAA $00,X

: POP           ( -- )
                [FORTH]
                1 OP@ $09 =             \ DEX
                0 OP@ $A7 = AND         \ STAA 0,X
                2 ?OP_OPT   AND
                IF      2 DEL_OP     \ delete bytes and instructions
                ELSE    [ASM6811]
                        POP,
                        [FORTH]
                THEN    [COMPILER] ;

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
        IF      2 OP@ $09 =                     \ DEX
                1 OP@ $A7 = AND                 \ STAA 0,X
                0 OP@ $86 = AND                 \ LDAA # xx
                3 ?OP_OPT   AND
                IF      0 OP& 1+ C@-T           \ get the value xx
                        3 DEL_OP             \ delete bytes & instructions
                        TRUE                    \ return -1 for literal
                ELSE    FALSE
                THEN
        ELSE    ?REOPT
                FALSE
        THEN    ;

: IMM_OPT       ( -- <xxxx> f1 )                \ immediate optimize
                ?OPT                            \ Are we optimizing?
        IF      0 OP@ $86 =                     \ LDAA # xx
                1 ?OP_OPT   AND
                IF      0 OP& 1+ C@-T           \ get the value xx
                        1 DEL_OP             \ delete bytes & instructions
                        TRUE                    \ return -1 for literal
                ELSE    FALSE
                THEN
        ELSE    ?REOPT
                FALSE
        THEN    ;

: LIT/MEM?      ( byte -- f )   \ true if lda immediate or direct
                DUP $86 = SWAP $96 = OR ;

: LIT/MEM-FLAG  ( byte -- f )   \  -1 = literal, 1 = memory
                $86 = 2* 1+ ;

: LIT/MEM_OPT   ( -- <xxxx> f1 )                \ literal/memory optimize
                ?OPT                            \ Are we optimizing?
        IF      2 OP@ $09 =                     \ DEX
                1 OP@ $A7 =         AND         \ STAA 0,X
                0 OP& C@-T LIT/MEM? AND         \ xx # LDA, or xx LDA,
                3 ?OP_OPT           AND
                IF      0 OP& 1+ C@-T           \ get the value xx
                        0 OP&    C@-T LIT/MEM-FLAG  \ and flag
                        3 DEL_OP             \ delete bytes & instructions
                ELSE    0
                THEN
        ELSE    ?REOPT
                0
        THEN    ;

: LIT_LIT_OPT   ( -- <xx yy> f1 )               \ double literal optimize
                ?OPT                            \ Are we optimizing?
        IF      5 OP@ $09 =                     \ DEX
                4 OP@ $A7 = AND                 \ STAA 0,X
                3 OP@ $86 = AND                 \ LDAA # xx
                2 OP@ $09 = AND                 \ DEX
                1 OP@ $A7 = AND                 \ STAA 0,X
                0 OP@ $86 = AND                 \ LDAA # yy
                6 ?OP_OPT   AND
                IF      3 OP& 1+ C@-T           \ get the value xx
                        0 OP& 1+ C@-T           \ get the value yy
                        6 DEL_OP            \ delete bytes & instructions
                        TRUE
                ELSE    FALSE
                THEN
        ELSE    ?REOPT
                FALSE
        THEN    ;

: DROP_OPT      ( -- f1 )       \ looking for preseeding SWAP
                ?OPT                            \ Are we optimizing?
        IF      2 OP@ $16 =                     \ TAB
                1 OP@ $A6 = AND                 \ LDAA 0,X
                0 OP@ $E7 = AND                 \ STAB 0,X
                3 ?OP_OPT   AND
                IF      3 DEL_OP            \ delete bytes & instructions
                        TRUE
                ELSE    FALSE
                THEN
        ELSE    ?REOPT
                FALSE
        THEN    ;

\ **********************************************************************
\ 6811 Version of listing program invocation function
\ **********************************************************************

: %make_listing ( -- )          \ build a listing file
                [ hidden ]
                closeall
                ."  Invoking .LST generator.. [press Ctrl-Break to cancel]"
                " ls11 "                pad place       \ batch file
                listing.name >pathend"  pad +place      \ append file
                cr space pad count type cr
                pad $sys drop                           \ make listing
                at? at cr ;

' %make_listing is make_listing         \ link into compiler

TARGET DEFINITIONS

\ ***************************************************************************
\ Modified defining words

: VARIABLE      ( -<name>- )            \ BYTE Variable Data
                ?library
                if      1 larray
                else    1 tarray
                then    ;

: WVARIABLE     ( -<name>- )            \ WORD Variable Data
                ?library
                if      2 larray
                else    2 tarray
                then    ;

>LIBRARY

