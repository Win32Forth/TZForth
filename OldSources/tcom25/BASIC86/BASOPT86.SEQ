\ BASOPT86.SEQ     Optimizers for BASIC Compiler

ONLY FORTH ASSEMBLER ALSO FORTH ALSO COMPILER ALSO DEFINITIONS
HOST ALSO TARGET ALSO

FORTH

/LOW-HIGH                       \ this target processor uses low byte of a
                                \ word in the low memory address of a pair.

: TVER ."  8086 Version 1.00 " ;
' TVER IS TVERSION             \ install startup message

: ?PAIRS        ( n1 n2 -- )         \ make sure n1=n2, or error
                <>
                if      0 " Conditional Branch UNBALANCED" "errmsg
                then    ;

WARNING OFF                     \ NO REDEFINITION WARNING IN LIBRARY
FORTH                           \ we want a Forth NOT a target variable
VARIABLE IMM-HERE               \ Most recent place where immediate move
                                \ to BX was compiled

2VARIABLE ENTRYSAVE

\ ***************************************************************************
\ New function for END-CODE, needs to not use REVEAL

assembler also forth also

I: CEND-CODE    ( -- )
                ll-global? 0=
                if      ll-errs?        \ check for local label errors
                then
                ARUNSAVE IS RUN
                PREVIOUS A; ;

previous previous target

I: %END-AMACRO  ( -- )
                a; llset-
                ?reopt cend-code ;

I: %END-MACRO   ( -- )          \ complete assembly of a MACRO
                compile %end-amacro
                [compile] FOR; ;                \ complete colon def

' %END-MACRO IS END-MACRO       \ install in END-MACRO

I: %%END-LMACRO ( -- )
                a;
                ?reopt cend-code ;

I: %END-LMACRO  ( -- )          \ complete assembly of a LCODE
                compile %%end-lmacro
                [compile] FOR; ;                \ complete colon def

' %END-LMACRO IS END-LMACRO     \ install in END-LMACRO
' %END-LMACRO IS END-LCODE      \ install in END-LCODE

' drop is resolve_opt   \ link into compiler

I: %END-L:      ( -- )          \ complete a library CALL definition
                compile comp_ret
                compile unnest ;                \ complete colon def

' %END-L: IS END-L:

I: %END-LM:     ( -- )          \ complete a library MACRO : definition
                [assembler]
                compile setassem
                compile cend-code
                compile unnest ;                \ complete colon def

' %END-LM: IS END-LM:

I: %COMP_CALL   ( a1 -- )                       \ a1 = CFA of symbol
                ?REOPT                          \ re-enable optimization
                232 CC,                         \ compile CALL
                dup     >resaddr @ dup -1 <>    \ if resolved already
                if      here-t 2+ - O,          \ resolve this call
                        >count incr             \ bump use count
                                        \ ELSE, add it to the chain of
                else    drop                    \ discard the "-1"
                                                \ references to be resolved.
                        dup >chain @ O,         \ link chain @ to here
                        here-t 2- over >chain ! \ link here into chain
                        >res                    \ add to resolution stack
                then    ;

' %COMP_CALL IS COMP_CALL

I: %COMP_JMP    ( a1 -- )                       \ a1 = CFA of symbol
                ?REOPT                          \ re-enable optimization
                233 CC,                         \ compile CALL
                dup     >resaddr @ dup -1 <>    \ if resolved already
                if      here-t 2+ - O,          \ resolve this call
                        >count incr             \ bump use count
                                        \ ELSE, add it to the chain of
                else    drop                    \ discard the "-1"
                                                \ references to be resolved.
                        dup >chain @ O,         \ link chain @ to here
                        here-t 2- over >chain ! \ link here into chain
                        >res                    \ add to resolution stack
                then    ;

' %COMP_JMP IS COMP_JMP

I: %COMP_JMP_IMM ( a1 -- )                      \ a1 = actual address
                233 IC, HERE-T 2+ - O, ;

' %COMP_JMP_IMM IS COMP_JMP_IMM

I: %COMP_RET    ( -- )
                [assembler]
                ret a;                  \ terminate with a RET instruction
                ;

' %COMP_RET IS COMP_RET

' noop IS SUB_RET

I: %TCODE-START ( -- )
                OPT_OFF1                \ ********* 08/29/91
                setassem
                init_labels ;           \ ********* 01/29/91

\ ' %TCODE-START IS TCODE-START         \ ????

I: %LCODE-START ( -- )
                compile %tcode-start    \ initialize the assembler
                assembler ;             \ and select assembler vocabulary now!

' %LCODE-START IS LCODE-START

I: %%MACRO-START ( -- )
                a; llset+
                setassem
                init_labels ;           \ ********* 01/29/91

I: %MACRO-START ( -- )
                compile %%macro-start   \ initialize the assembler
                assembler ;             \ and select assembler vocabulary now!

' %MACRO-START IS MACRO-START

I: %%LMACRO-START ( -- )
                a; setassem
                init_labels ;           \ ********* 01/29/91

I: %LMACRO-START ( -- )
                compile %%lmacro-start  \ initialize the assembler
                assembler ;             \ and select assembler vocabulary now!

' %LMACRO-START IS LMACRO-START

\ ***************************************************************************
\ Start of the set of functions supported in the target compiler.
\ These are mostely macros which will compile in-line assembly code.
\ Colon definitions are compiled as routines when defined, and are
\ accessed by a CALL when referenced.

ONLY FORTH ALSO COMPILER ALSO HOST ALSO HTARGET ALSO TARGET ALSO DEFINITIONS
ASSEMBLER ALSO

FHERE FORTH !> LIB_BOTTOM ASSEMBLER

\ ***************************************************************************
\ DONOT CHANGE the first three instructions of SYSINIT. The ADD instruction
\ must be HOT patched by the image save routine so DS will be set properly
\ when the image loads in. The $E4F6 value is verified by the patch routine
\ to make sure the code has not changed. It is then replaced with the proper
\ value to add to AX so DS will be correct.

\  LVARIABLE DP                   \ DP is really a variable that always exists,
\                                 \ and is always at address DATA-START.

\  LVARIABLE RP0
\  LVARIABLE SP0

MACRO IMAGE-INIT ( -- )         \ Target compiler runtime initialization
                [ASSEMBLER]

\   **********   DON'T CHANGE THE NEXT EIGHT LINES  **********

                MOV AX, CS              \ get a copy of the CODE segment
                ADD AX, # $E4F6 a;      \ patched later to adjust for
                                        \ where the data really is.
                here-t 2- =: data-seg+  \ set patch pointer
                MOV DS, AX      a;      \ Set the data segment
                                        \ down 256 bytes from call stack

                MOV SS, AX              \ set hardware stack segment to DS
                MOV ES, AX              \ and extra register to DS
                mov bx, # $FFF0 rpsize -
                mov si, bx              \ set stack pointer
                add bx, # rpsize        \ adjust to end of return stack
                mov sp, bx              \ set return stack
\ **********************************************************************
\ Finish initialization and CALL application
                MOV BX, # 0             \ and top of stack register with zero
                MOV BP, BX              \ !!!!!BP WILL ALWAYS BE ZERO!!!!!
 ( *** )        CALL 1 $ a;             \ CALL real program (gets patched)
                here-t 2- =: cold_start \ set patch pointer
\ Finally, EXIT back to DOS
                here-t    =: final_exit \ set program exit pointer for BYE
                MOV AX, # $4C00
                INT $21                 \ terminate back to DOS
          1 $:  END-MACRO               \ 1 $: marks the end of the init code

MACRO ENTRYPOINT ( -- )         \ a do nothing macro, creates a symbol
                END-MACRO

FORTH DEFINITIONS

: TARGET-INIT   ( -- )          \ initialize the terget compiler
                ?LIB ABORT" Cant use TARGET-INIT in a library routine"
                ONLY  HOST      ALSO
                FORTH ASSEMBLER ALSO
                      HOST      ALSO
                FORTH TARGET    ALSO DEFINITIONS
                0 !> >in_word   \ reset the WORD input pointer
                                \ ************ 01/29/91
                $100 org        \ 8086 code starts at $0100 in code segment
                $00 dorg        \ 8086 data starts at $0000 in data segment
                                \ but DP is there, and more are at $0002
                >target-mem     \ select compiling to target memory
                >target         \ select target defining words
                target          \ Select the target vocabulary
\+ xIC,         ['] xIC, is IC,                 \ install for indexer
\+ xCC,         ['] xCC, is CC,
\+ index!       othertype here-t index!         \ copy source starting marker
                ?long_set                       \ set the ?LONG value
                2 allot-d                       \ use extra couple of bytes
                0 SAVE!> CURFIL#                \ save and clear curfil#
                F['] IMAGE-INIT                 \ address of init routine
                DUP >COUNT INCR                 \ mark it used and
                    >EXECUTE EXECUTE            \ compile it
                here-t
                F['] ENTRYPOINT                 \ mark the program entry point
                >resaddr !
                filepointer 2@
                outbuf c@ 0 d- 0.0 dmax
                >in_word @ 0 d+ entrysave 2!    \ src offset
                RESTORE> CURFIL#                \ no source available here
                ?sym_inc                        \ if including a symbol tbl
                IF      symorg      org         \ switch to append address
                        symvorg     dorg        \ after compiling init code
                THEN
                ; IMMEDIATE

' TARGET-INIT IS TARGET-INITIALIZE

: TARGET-FINSH  ( -- )
                save> curfil#
                F['] entrypoint                 \ get the entry point word
                {S} over >dtype c!              \ change type to function
                 0  over >dsize !
                 1 !> curfil#
                    symwrite drop               \ write the symbol
                restore> curfil#
                othertype here-t index! ;       \ copy source ending marker

' TARGET-FINSH IS TARGET-FINISH

ASSEMBLER DEFINITIONS FORTH

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

: STORE_OPT    ( -- )          \ The ! MACRO
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 7 -  @-T $4E4E =         \ DEC SI
                                                \ DEC SI
                HERE-T 5 -  @-T $1C89 = AND     \ MOV 0 [SI], BX
                HERE-T 3 - C@-T $BB   = AND     \ MOV BX, # xxxx
                7 #?OPT                 AND
                IF      HERE-T 2- @-T           \ get the address xxxx
                        7 4 DEL_B/I             \ delete bytes & instructions
                        [ASSEMBLER]
                        MOV ( xxxx ) BX A;      \ uses xxxx from above
                        [FORTH]
                ELSE                            \ cant optimize, so
                        [ASSEMBLER]             \ just compile the
                        LODSW  A;               \ original code
                        MOV 0 [BX], AX A;
                        [FORTH]
                THEN
        ELSE    ?REOPT
                [ASSEMBLER]
                LODSW A;
                MOV 0 [BX], AX A;
                [FORTH]
        THEN
                [TARGET]
                ;

: CSTORE_OPT   ( -- )          \ The C! MACRO
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 7 -  @-T $4E4E =         \ DEC SI
                                                \ DEC SI
                HERE-T 5 -  @-T $1C89 = AND     \ MOV 0 [SI], BX
                HERE-T 3 - C@-T $BB   = AND     \ MOV BX, # xxxx
                7 #?OPT                 AND
                IF      HERE-T 2- @-T           \ get the address xxxx
                        7 4 DEL_B/I             \ delete bytes & instructions
                        [ASSEMBLER]
                        MOV ( xxxx ) BL A;      \ uses xxxx from above
                        [FORTH]
                ELSE                            \ cant optimize, so
                        [ASSEMBLER]             \ just compile the
                        LODSW  A;               \ original code
                        MOV 0 [BX], AL A;
                        [FORTH]
                THEN
        ELSE    ?REOPT
                [ASSEMBLER]
                LODSW A;
                MOV 0 [BX], AL A;
                [FORTH]
        THEN
                [TARGET]
                ;

\ ***************************************************************************
\ A second optimizer for the ! (store) MACRO. Looks for the following
\ instruction sequence:
\
\               DEC SI                                          3 cycles
\               DEC SI                                          3 cycles
\               MOV 0 [SI], BX          \ save BX              14 cycles
\               MOV BX, # xxxx          \ LIT xxxx              4 cycles
\               MOV yyyy BX             \ memory yyyy store     9 cycles
\
\ When these instructions are found preceeding a store instruction, they
\ are changed to:
\
\               MOV yyyy # xxxx WORD                            10 cycles
\
\ This provides a savings of 8 bytes and 27 cycles per occurance.

: STORE_OPT2   ( -- )          \ double optimize store immediates
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 14 -  @-T $4E4E =        \ 4E           DEC SI
                                                \ 4E           DEC SI
                HERE-T 12 -  @-T $1C89 = AND    \ 89 1C        MOV 0 [SI], BX
                HERE-T 10 - C@-T $BB   = AND    \ BB xx xx     MOV BX, # xxxx
                HERE-T  7 -  @-T $1E89 = AND    \ 89 1E yy yy  MOV yyyy BX
                                                \ AD           LODSW
                                                \ 8B D8        MOV BX, AX
                14 #?OPT                 AND
                IF      HERE-T 5 - @-T          \ get the address yyyy
                        HERE-T 9 - @-T          \ get the value xxxx
                        14 7 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        MOV #  WORD     A;      \ MOV yyyy # xxxx WORD
                        [FORTH]
                THEN
        THEN
                [TARGET]
                ;

: STORE_OPT2A  ( -- )          \ second optimize store immediates
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 10 - C@-T $BB   =        \ BB xx xx     MOV BX, # xxxx
                HERE-T  7 -  @-T $1E89 = AND    \ 89 1E yy yy  MOV yyyy BX
                                                \ AD           LODSW
                                                \ 8B D8        MOV BX, AX
                10 #?OPT                 AND
                IF      HERE-T 5 - @-T          \ get the address yyyy
                        HERE-T 9 - @-T          \ get the value xxxx
                        10 4 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        MOV #  WORD     A;      \ MOV yyyy # xxxx WORD
                        LODSW           A;
                        MOV BX, AX      A;
                        [FORTH]
                THEN
        THEN
                [TARGET]
                ;

: STORE_OPT2B  ( -- )          \ second optimize store immediates
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T  9 - C@-T $BB   =        \ BB xx xx     MOV BX, # xxxx
                                                \ AD           LODSW
                HERE-T  5 - @-T $0789 = AND     \ 89 07        MOV 0 [BX], AX
                                                \ AD           LODSW
                                                \ 8B D8        MOV BX, AX
                14 #?OPT                AND
                IF      HERE-T 8 - @-T          \ get the value xxxx
                        9 5 DEL_B/I             \ delete bytes & instructions
                        [ASSEMBLER]
                        LODSW           A;
                        MOV ( xxxx ) AX A;
                        LODSW           A;
                        MOV BX, AX      A;
                        [FORTH]
                THEN
        THEN
                [TARGET]
                ;

: STORE_OPT3   ( -- )          \ triple optimize store fetch combos
                A; [FORTH]
                ?OPT            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 15 -  @-T $4E4E =        \ 4E           DEC SI
                                                \ 4E           DEC SI
                HERE-T 13 -  @-T $1C89 = AND    \ 89 1C        MOV 0 [SI], BX
                HERE-T 11 -  @-T $1E8B = AND    \ 8B 1E xx xx  MOV BX, xxxx
                HERE-T  7 -  @-T $1E89 = AND    \ 89 1E yy yy  MOV yyyy BX
                                                \ AD           LODSW
                                                \ 8B D8        MOV BX, AX
                15 #?OPT                 AND
                IF      HERE-T 5 - @-T          \ get the address yyyy
                        HERE-T 9 - @-T          \ get the value xxxx
                        15 7 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        MOV CX, ( xxxx) A;
                        MOV ( yyyy) CX  A;
                        [FORTH]
                THEN
        THEN
                [TARGET]
                ;

: IMM/ABS_OPT  ( -- <xxxx> f1 )                \ Immediate optimize
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T  7 -  @-T $4E4E =        \ DEC SI
                                                \ DEC SI
                HERE-T  5 -  @-T $1C89 = AND    \ MOV 0 [SI], BX
                HERE-T  3 - C@-T $BB   = AND    \ MOV BX, # xxxx
                7 #?OPT                  AND
                IF      HERE-T 2 - @-T          \ get the address xxxx
                        7 4 DEL_B/I             \ delete bytes & instructions
                        -1              \ return -1 for immediate
                ELSE
                        HERE-T  8 -  @-T $4E4E =     \ DEC SI
                                                     \ DEC SI
                        HERE-T  6 -  @-T $1C89 = AND \ MOV 0 [SI], BX
                        HERE-T  4 -  @-T $1E8B = AND \ MOV BX, xxxx
                        IF      HERE-T 2 - @-T       \ get the address xxxx
                                8 4 DEL_B/I     \ delete bytes & instructions
                                1       \ return 1 for absolute
                        ELSE    0       \ else return 0
                        THEN
                THEN
        ELSE    0
        THEN
                [TARGET]
                ;

: %IMM_BEFORE   ( -- <xxxx> f1 )                \ Immediate optimize
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T  3 - C@-T $BB   =        \ MOV BX, # xxxx
                HERE-T  3 - IMM-HERE @ = AND    \ matches our info
                3 #?OPT                  AND
                IF      HERE-T 2 - @-T          \ get the address xxxx
                        3 1 DEL_B/I             \ delete bytes & instructions
                        TRUE
                ELSE    FALSE
                THEN
        ELSE    FALSE
        THEN
                [TARGET]
                ;

' %imm_before is imm_before

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

: AT_OPT       ( -- )          \ The @ MACRO
                A; [FORTH]
                ?OPT            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 3 - C@-T $BB   =         \ MOV BX, # xxxx
                3 #?OPT                 AND
                IF      HERE-T 2- @-T           \ get the address xxxx
                        3 1 DEL_B/I             \ delete bytes & instructions
                        [ASSEMBLER]
                        MOV BX, ( xxxx ) A;     \ uses xxxx from above
                        [FORTH]
                ELSE                            \ cant optimize, so
                        [ASSEMBLER]             \ just compile the
                        MOV BX, 0 [BX] A;
                        [FORTH]
                THEN
        ELSE    ?REOPT
                [ASSEMBLER]
                MOV BX, 0 [BX] A;
                [FORTH]
        THEN
                [TARGET]
                ;

: CAT_OPT      ( -- )          \ The @ MACRO
                A; [FORTH]
                ?OPT            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 3 - C@-T $BB   =         \ MOV BX, # xxxx
                3 #?OPT                 AND
                IF      HERE-T 2- @-T           \ get the address xxxx
                        3 1 DEL_B/I             \ delete bytes & instructions
                        [ASSEMBLER]
                        MOV BL, ( xxxx ) A;     \ uses xxxx from above
                        [FORTH]
                ELSE                            \ cant optimize, so
                        [ASSEMBLER]             \ just compile the
                        MOV BL, 0 [BX] A;
                        [FORTH]
                THEN
        ELSE    ?REOPT
                [ASSEMBLER]
                MOV BL, 0 [BX] A;
                [FORTH]
        THEN
                [TARGET]
                ;

\ ***************************************************************************
\ MACRO to move BX to the stack
\ ***************************************************************************

: SAVE_BX       ( -- )          \ macro to SAVE BX
                A; [FORTH]
                ?OPT            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 3 - C@-T $AD   =         \ LODSW
                HERE-T 2 -  @-T $D88B = AND     \ MOV BX, AX
                3 #?OPT                 AND
                IF      3 2 DEL_B/I             \ delete bytes & instructions
                                        \ discards any previously compiled
                                        \ LODSW and MOV BX, AX pair
                                        \ of instructions, since we were
                                        \ about to push BX back on the
                                        \ stack anyway
                        [FORTH]
                ELSE
                        [ASSEMBLER]        \ just compile them
                        DEC SI          A;
                        DEC SI          A;
                        MOV 0 [SI], BX  A;
                        [FORTH]
                THEN
        ELSE    ?REOPT
                [ASSEMBLER]
                DEC SI          A;
                DEC SI          A;
                MOV 0 [SI], BX  A;
                [FORTH]
        THEN
                [TARGET]
                ;

: LOAD_BX       ( -- )          \ macro to LOAD BX, not an optimizer
                A;
                [ASSEMBLER]
                LODSW           A;
                MOV BX, AX      A;
                [TARGET]
                ;


