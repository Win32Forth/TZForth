\ OPTIMIZ.SEQ     Library Optimizers for Target Compiler

ONLY FORTH ASM96 ALSO FORTH ALSO COMPILER ALSO DEFINITIONS
HOST ALSO TARGET ALSO

>FORTH

: TVER ." \2 80196 Version 1.01 \2" ;
' TVER IS TVERSION              \ install startup message

' NOOP IS DATA-SEG-FIX          \ not a segmented machine
' NOOP IS SET_COLD_ENTRY        \ no automatic entry vector

WARNING OFF                     \ NO REDEFINITION WARNING IN LIBRARY
FORTH                           \ we want a Forth NOT a target variable
VARIABLE IMM-HERE               \ Most recent place where immediate move
                                \ to BX was compiled

\ ***************************************************************************
\ New function for END-CODE, needs to not use REVEAL

ASM96 also forth also

: CEND-CODE     ( -- )
                ll-global? 0=
                if      ll-errs?        \ check for local label errors
                then
                ARUNSAVE IS RUN
                PREVIOUS A; ;

previous previous target

: %END-MACRO    ( -- )          \ complete assembly of a MACRO
                ?reopt
                [ASM96]
                compile a;                      \ make sure ASM96 is done
                compile cend-code               \ pop ASM96 vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-MACRO IS END-MACRO       \ install in END-MACRO

: %END-LCODE    ( -- )          \ complete assembly of a LCODE
                ?reopt
                [ASM96]
                compile a;                      \ make sure ASM96 is done
                compile cend-code               \ pop ASM96 vocabulary
                compile ido_resolve             \ resolve forward references
                [compile] FOR; ;                \ complete colon def

' %END-LCODE IS END-LCODE       \ install in END-LCODE

: %END-L:       ( -- )          \ complete a library CALL definition
                [ASM96]
                compile setassem
                compile ret
                compile a;                      \ make sure ASM96 is done
                compile cend-code               \ pop ASM96 vocabulary
                compile unnest ;

' %END-L: IS END-L:

: %END-LM:      ( -- )          \ complete a library MACRO : definition
                [ASM96]
                compile setassem
                compile cend-code
                compile unnest ;

' %END-LM: IS END-LM:

' NOOP IS START-T:

: %END-T: ( -- ) \ complete a target CALL definition
        [forth]
        true save!> state
\        [ASM96]
\        setassem                \ do ASM96 setup
        $0F0 IC,                        \ compile RET
\        ret a;                  \ terminate with a RET instruction
        [forth]
        restore> state
        ;
\        fend-code ;             \ do ASM96 finishup

' %END-T: IS END-T:

: %COMP_CALL ( a1 -- )  \ compile a target CALL
                        \ a1 = CFA of symbol
        $0EF CC,                        \ compile CALL
        dup     >resaddr @ dup -1 <>    \ if resolved already
        if      here-t 2+ - O,          \ resolve this call
                        >count incr             \ bump use count
                                        \ ELSE, add it to the chain of
        else    drop                    \ discard the "-1"
                                                \ references to be resolved.
                        dup >chain @ O,         \ link chain @ to here
                        here-t 2- over >chain ! \ link here into chain
                        >res                    \ add to resolution stack
        then
        ;

' %COMP_CALL IS COMP_CALL

: %COMP_JMP_IMM ( a1 -- )                      \ a1 = actual address
        233 IC, HERE-T 2+ - O, ;

' %COMP_JMP_IMM IS COMP_JMP_IMM

: %SUB_RET      ( -- )
                -1 ALLOT-T              \ discard previously compiled RET
                LIHERE =: LINESTRT
                1 #del_index    ;       \ delete the previous inst

' SUB_RET IS SUB_RET

: %TCODE-START  ( -- )
                setassem
                [assembler]
                llab-init ;

' %TCODE-START IS TCODE-START

: %LCODE-START  ( -- )
                compile tcode-start     \ initialize the ASM96
                ASM96 ;             \ and select ASM96 vocabulary now!

' %LCODE-START IS LCODE-START

: %MACRO-START  ( -- )
                compile setassem        \ initialize the ASM96
                ASM96 ;             \ and select ASM96 vocabulary now!

' %MACRO-START IS MACRO-START

ASM96 ALSO              \ words for defining ram space
: DCB  tlabel 0 OC,     [compile] end-code ;
: DCW  tlabel 0 O,      [compile] end-code ;
: DCL  tlabel 0 O, 0 O, [compile] end-code ;


\ ***************************************************************************
\ Start of the set of functions supported in the target compiler.
\ These are mostely macros which will compile in-line assembly code.
\ Colon definitions are compiled as routines when defined, and are
\ accessed by a CALL when referenced.

ONLY FORTH ALSO COMPILER ALSO host also HTARGET ALSO TARGET ALSO DEFINITIONS
ASM96 ALSO

>LIBRARY                        \ Select the Library versions of
                                \ defining words.

\ ***************************************************************************

hex
1A      constant        psp
1C      constant        w0
1D      constant        w1
1E      constant        w2
1F      constant        w3
20      constant        ttos
21      constant        ttosh
        ' ttosh alias   ttos1
22      constant        ttos2
23      constant        ttos3

24 Dseg registers
decimal

comment:
hex                             \ kernel registers
1A      constant        ROW_COUNTER
1C      constant        DPOINT          \ pointers and counters
20      constant        DCOUNT          \ for display block move

22      constant        SP_FLAGS        \ serial port status image

2E      constant        psp
30      constant        w0
31      constant        w1
32      constant        w2
33      constant        w3
34      constant        ttos
ttos 1+ constant        ttosh
                                \ application registers
36      constant        tlcdx
38      constant        tlcdy
3A      constant        tcolor

decimal
comment;

MACRO IMAGE-INIT ( -- )         \ Target compiler runtime initialization
                [ASM96]

       END-MACRO

FORTH DEFINITIONS               >FORTH


: TARGET-INIT   ( -- )          \ initialize the terget compiler
                ?LIB ABORT" Cant use TARGET-INIT in a library routine"
                ONLY  HOST      ALSO
                FORTH ASM96     ALSO
                      HOST      ALSO
                FORTH TARGET    ALSO DEFINITIONS
                0 !> >in_word   \ reset the WORD input pointer
                $2080 org
                ( $1A ) $24 dorg
                >target-mem     \ select compiling to target memory
                >target         \ select target defining words
                target          \ Select the target vocabulary
\+ xIC,         ['] xIC, is IC,                 \ install for indexer
\+ xCC,         ['] xCC, is CC,
\+ index!       othertype here-t index!         \ copy source starting marker
                ;  IMMEDIATE

' TARGET-INIT IS TARGET-INITIALIZE

ASM96 DEFINITIONS FORTH     >LIBRARY

\ ***************************************************************************
\                           OPTIMIZERS !!
\ ***************************************************************************
\ Optimizer for the ! (store) MACRO. Looks for the following instruction
\ sequence:
\               DEC SI
\               DEC SI
\               MOV 0 [SI], BX
\               MOV BX, # xxxx
\               LODSW
\               MOV 0 [BX], AX
\
\ When these instructions are found preceeding a store instruction, they
\ are changed to:
\               MOV AX, BX
\               MOV xxxx ax
\
\ This provides a substantial savings in both space and time.

FORTH   >FORTH



\ ***************************************************************************
\ A second optimizer for the ! (store) MACRO. Looks for the following
\ instruction sequence:
\
\               DEC SI                                          3 cycles
\               DEC SI                                          3 cycles
\               MOV 0 [SI], BX          \ save BX              14 cycles
\               MOV BX, # xxxx          \ LIT xxxx              4 cycles
\               MOV yyyy BX             \ memory yyyy store     9 cycles
\               LODSW                   \ load BX              12 cycles
\               MOV BX, AX                                      2 cycles
\
\ When these instructions are found preceeding a store instruction, they
\ are changed to:
\
\               MOV yyyy # xxxx WORD                            10 cycles
\
\ This provides a savings of 8 bytes and 37 cycles per occurance.


>LIBRARY

\ ***************************************************************************
\ Optimizer for the @ (fetch) MACRO. Looks for this instruction sequence
\ to preceed it:
\               MOV BX, # xxxx
\
\ When these instructions are found preceeding a store instruction, they
\ are changed to:
\               MOV bx, xxxx
\
\ This provides a savings in both space and time.

FORTH   >FORTH


>LIBRARY

\ ***************************************************************************
\ MACRO to move TTOS to the stack and vice versa
\ ***************************************************************************

FORTH   >FORTH


: SAVE_TTOS     ( -- )          \ macro to SAVE TTOS, not an optimizer
                A;
                [ASM96]
                SUB  PSP # 2        A;
                ST   TTOS [] PSP    A;
                [TARGET]
                ;

: LOAD_TTOS     ( -- )          \ macro to LOAD TTOS, not an optimizer
                A;
                [ASM96]
                LD  TTOS []+ PSP    A;
                [TARGET]
                ;

\ **********************************************************************
\ Sam8 Version of listing program invocation function
\ **********************************************************************

: %make_listing ( -- )          \ build a listing file
                [ hidden ]
                closeall
                ."  Invoking .LST generator.. [press Ctrl-Break to cancel]"
                " ls96 "                pad place       \ batch file
                listing.name >pathend"  pad +place      \ append file
                ?withlib                                \ user wants lib?
        if      "  /lib"                pad +place      \ append "/LIB"
        then    ?nolib                                  \ user wants NO lib?
        if      "  /nolib"              pad +place      \ append "/nolib"
        then    cr space pad count type cr
                pad $sys drop   ;                       \ make listing

' %make_listing is make_listing         \ link into compiler

>LIBRARY

