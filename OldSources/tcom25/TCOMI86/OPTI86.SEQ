\ OPTI86.SEQ    Interface file for for 8086 Interpreted Target

ONLY FORTH ASSEMBLER ALSO FORTH ALSO COMPILER ALSO DEFINITIONS
HOST ALSO TARGET ALSO

>FORTH

FORTH

/LOW-HIGH                       \ this target processor uses low byte of a
                                \ word in the low memory address of a pair.

: TVER86 ."  I8086 Version 0.02 " ;
' TVER86 IS TVERSION

' NOOP IS DATA-SEG-FIX          \ not a segmented target

WARNING OFF                     \ NO REDEFINITION WARNING IN LIBRARY
FORTH                           \ we want a Forth NOT a target variable

\ ***************************************************************************
\ New function for END-CODE, needs to not use REVEAL

ASSEMBLER ALSO FORTH ALSO

: %SET_ENTRY    ( -- )          \ mark HERE-T as the cold entry point
                here-t cold_start !-t ;         \ Absolute addressing

' %SET_ENTRY IS SET_COLD_ENTRY

FORTH

DEFER DO_RET

: CEND-CODE     ( -- )
                ll-global? 0=
                if      ll-errs?        \ check for local label errors
                then
                ARUNSAVE IS RUN
                PREVIOUS A; ;

PREVIOUS PREVIOUS TARGET

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

: %END-L:       ( -- )          \ complete a library CALL definition
                [ASSEMBLER]
                compile setassem
                compile DO_RET
                compile a;                      \ make sure ASSEMBLER is done
                compile cend-code               \ pop ASSEMBLER vocabulary
                compile unnest ;

' %END-L: IS END-L:

: %END-LM:      ( -- )          \ complete a library MACRO : definition
                [ASSEMBLER]
                compile setassem
                compile cend-code
                compile unnest ;

' %END-LM: IS END-LM:

: %END-T:       ( -- )          \ complete a target CALL definition
                [ASSEMBLER]
                setassem                \ do ASSEMBLER setup
                DO_RET a;               \ terminate with a RET instruction
                fend-code ;             \ do ASSEMBLER finishup

' %END-T: IS END-T:

: %COMP_CALL    ( a1 -- )                       \ a1 = CFA of symbol
                codewordtype here-t index!
                dup     >resaddr @ dup -1 <>    \ if resolved already
                if      ,-T                     \ resolve this call
                        >count incr             \ bump use count
                                        \ ELSE, add it to the chain of
                else    drop                    \ discard the "-1"
                                                \ references to be resolved.
                        dup >chain @ ,-T        \ link chain @ to here
                        here-t 2- over >chain ! \ link here into chain
                        >res                    \ add to resolution stack
                then    ;

' %COMP_CALL IS COMP_CALL

: %RESOLVE_ONE  ( a1 -- )               \ resolve a forward reference
                here-t swap !-T ;       \ for absolute addresses

' %RESOLVE_ONE IS RESOLVE_1             \ link into compiler

' DROP IS COMP_JMP_IMM

: %SUB_RET      ( -- )
                -2 ALLOT-T ;

' SUB_RET IS SUB_RET

: %TCODE-START  ( -- )
                setassem                \ initialize the ASSEMBLER
                codewordtype here-t index!
                here-t 2+ ,-t           \ start code words pointing to body
                [assembler]
                llab-init ;             \ clear all labels

' %TCODE-START IS TCODE-START

: %LCODE-START  ( -- )
                compile %tcode-start   \ initialize the code word CFA
                ASSEMBLER ;                 \ and select ASSEMBLER vocabulary now!

' %LCODE-START IS LCODE-START

: %%MACRO-START ( -- )
                a; llset+
                setassem
                init_labels ;           \ ********* 01/29/91

I: %MACRO-START ( -- )
                compile %%macro-start   \ initialize the assembler
                assembler ;             \ and select assembler vocabulary now!

' %MACRO-START IS MACRO-START

: %%LMACRO-START ( -- )
                a; setassem
                init_labels ;           \ ********* 01/29/91

I: %LMACRO-START ( -- )
                compile %%lmacro-start  \ initialize the assembler
                assembler ;             \ and select assembler vocabulary now!

' %LMACRO-START IS LMACRO-START

\ ***************************************************************************

ONLY FORTH ALSO COMPILER ALSO HOST ALSO HTARGET ALSO TARGET ALSO DEFINITIONS
ASSEMBLER ALSO

>LIBRARY                        \ Select the Library versions of
                                \ defining words.


\ ***************************************************************************
\ Use great caution when changing any of the following constants, they
\ point into specific places in the initialization code that follows.

$100 FEQUATE  ORIGIN
[FORTH] DEFER RPZERO
[FORTH] DEFER SPZERO
[FORTH] DEFER TICKTIB
[FORTH] DEFER DPADDR
[FORTH] DEFER CONADDR
[FORTH] DEFER CURADDR
[FORTH] DEFER SSEGADDR
ASSEMBLER DEFINITIONS
$000 FEQUATE  2PUSH
$000 FEQUATE  1PUSH
$000 FEQUATE  >NEXT
$000 FEQUATE  >NEXT1
TARGET DEFINITIONS
$000 FEQUATE  NEST
$000 FEQUATE  DODOES
$000 FEQUATE  DOCREATE
$000 FEQUATE  DOCONSTANT
$000 FEQUATE  DODEFER

\ ***************************************************************************
\ Use great caution when changing any of this code, the constants above
\ point into the following code to specific routines.

MACRO IMAGE-INIT ( -- )         \ Target compiler runtime initialization
\                [assembler]
\                llab-init
\                [ASSEMBLER]
        JMP 3 $ WORD A;
        JMP $0000    A;         \ actually jump to the reboot address at $0000
        codewordtype here-t index!
        HERE-T 3 - ,-T
        codewordtype here-t index!
2 $:    HERE-T 2 - ,-T

HERE-T F['] 2PUSH >RESADDR [FORTH] ! [ASSEMBLER]
        PUSH DX A;      \ 2PUSH
HERE-T F['] 1PUSH >RESADDR [FORTH] ! [ASSEMBLER]
        PUSH AX A;      \ 1PUSH
HERE-T F['] >NEXT >RESADDR [FORTH] ! [ASSEMBLER]
        LODSW           \ >NEXT
        MOV BX, AX A;
HERE-T F['] >NEXT1 >RESADDR [FORTH] ! [ASSEMBLER]
        JMP 0 [BX] A;   \ >NEXT1
HERE-T F['] DOCREATE >RESADDR [FORTH] ! [ASSEMBLER]
        ADD BX, # 2                     \ DOCREATE
        PUSH BX         \ 11 cycles
        JMP >NEXT A;

\ Default set of VARIABLES for a target application
        $FF00   RPZERO  !-T
        $FE00   SPZERO  !-T
                TICKTIB DROP
                DPADDR  DROP
                CONADDR DROP
                CURADDR DROP
                SSEGADDR DROP

\ COLD ENTRY POINT      "ORIGIN"
3 $:    MOV AX, CS                      \ move CS to AX
        MOV DS, AX
        MOV SS, AX
        MOV SSEGADDR AX                     \ init Search SEGment
        MOV RP, RPZERO
        MOV AX, SPZERO
        MOV TICKTIB AX                  \ TIB = RP - 256 DECIMAL
        MOV SP, AX                      \ SP = TIB
        MOV IP, # 2 $                   \ address of exit routine
        XCHG RP, SP
        PUSH IP                         \ save exit address
        XCHG RP, SP
        MOV IP, # $0000 A;
                here-t 2- =: cold_start                 \ set patch pointer
        INC IP
        INC IP
        JMP >NEXT A;

HERE-T F['] NEST >RESADDR [FORTH] ! [ASSEMBLER]
        XCHG RP, SP     \  4 cycles     \ NEST
        PUSH IP         \ 11 cycles
        XCHG RP, SP     \  4 cycles
        ADD BX, # 2
        MOV IP, BX
        JMP >NEXT A;

HERE-T F['] DODOES >RESADDR [FORTH] ! [ASSEMBLER]
        XCHG RP, SP     \  4 cycles     \ DODOES
        PUSH IP         \ 11 cycles
        XCHG RP, SP     \  4 cycles
        POP IP
        JMP >NEXT A;

HERE-T F['] DOCONSTANT >RESADDR [FORTH] ! [ASSEMBLER]
        PUSH 2 [BX]     \ DOCONSTANT
        JMP >NEXT A;

HERE-T F['] DODEFER >RESADDR [FORTH] ! [ASSEMBLER]
        POP BX          \ DODEFER   ( -- )
        MOV BX, 0 [BX]
        JMP 0 [BX]  A;

END-MACRO       \ ***** End of IMAGE-INIT *****

\ ***************************************************************************

FORTH >FORTH

: %START-T:     ( -- )
                codewordtype here-t index!
                F['] NEST >RESADDR @ ,-T ;

' %START-T: IS START-T:
' %START-T: IS START-LM:

: %START-L:     ( -- )
                COMPILE %START-T: ;

' %START-L: IS START-L:

FORTH VARIABLE TLAST TLAST OFF
FORTH VARIABLE VLINK VLINK OFF

: %HEADER       ( A1 -- )       \ a1 = addr of counted name string
                [FORTH]
                codewordtype here-t index!
                HERE-T VLINK DUP @ ,-T !      \ make a chain of headers
                HERE-T 2- TLAST !             \ LINK of LAST for CONTEXT set
                :stringtype here-t index!
                DUP C@ 1+ S,-T                \ compile in header
                endtype here-t index! ;

[target] ' %HEADER [forth] IS COMP_HEADER     \ link into compiler

\ ***************************************************************************
\ Re-define VARIABLE and CONSTANT to work with this indirect threaded system

I: xTARRAY      ( n1 | <name> -- )      \ An array of data in target
                [forth]
                fhere >r
                {D}  new_symbol
                othertype here-t index!
                here-t ,                \ mark as resolved symbol
                F['] DOCREATE >resaddr @ ,-t
                -1 ,                    \ clear unresolved chain
                0 ,                     \ clear reference counter
                dup 0>
                if      wordtype here-t index!
                then
                dup , dup 1 >
                if      0 ,-t 2-
                then    allot-t         \ data size of a variable
                r> index_constant       \ include in sym tbl
                does>   body>
                        dup >count incr         \ bump usage
                            >resaddr @ 2+ ;     \ return address

SWITCH TARRAY xTARRAY

' %allot-t is allot-d           \ make ALLOT-D the same as ALLOT-T

: %xLARRAY      ( n1 a1 -- )
                [forth]
                swap >r
                F['] DOCREATE >resaddr @        \ addr of "docreate"
                here-t 2- !-t                   \ set CFA to DOCREATE
                here-t 2- swap >resaddr !       \ resolve to CFA
                wordtype here-t index!
                r> dup 1 >
                if      0 ,-t 2-                \ fill body with zero
                then    allot-t ;

: xLARRAY       ( n1 | <name> -- )
                fhere >r
                (L:)                            \ make header
                compile (lit) x,
                compile (lit) r> x,
                compile %xLARRAY
                compile %restore>
                compile state
                compile unnest
                does>   [forth]
                        body>
                        dup >resaddr @ -1 =
                        if  dup >execute execute
                        then
                        dup >count incr         \ bump usage
                            >resaddr @ 2+ ;     \ return address of var body

SWITCH LARRAY xLARRAY

: %CON          ( n1 a1 -- )
                F['] DOCONSTANT >resaddr @      \ addr of "doconstant"
                here-t 2- !-t                   \ set CFA to DOCONSTANT
                here-t 2- swap >resaddr !       \ resolve to CFA
                wordtype here-t index!
                ,-t   ;                         \ fill body with value

: CONSTANT      ( n1 | <name> -- )
                fhere >r
                (L:)                            \ make header
                compile (lit) x,
                compile (lit) r> x,
                compile %CON
                compile %restore>
                compile state
                compile unnest
                does>   [forth]
                        body>
                        dup >resaddr @ -1 =
                        if  dup >execute execute
                        then
                        dup >count incr         \ bump usage
                            >resaddr @ 2+ @-t ; \ return constant's value

: %DEF          ( a1 -- )
                F['] DODEFER >resaddr @         \ addr of "dodefer"
                here-t 2- !-t                   \ set CFA to DODEFER
                here-t 2- swap >resaddr !       \ resolve to body
                wordtype here-t index!
                0 ,-t   ;                       \ fill body with NULL

: DEFER         ( <name> -- )
                fhere >r
                (L:)                            \ make header
                compile (lit) r> x,
                compile %DEF
                compile %restore>
                compile state
                compile unnest
                does>   drop
                0 " Can't use target DEFERed words in interpret mode!"
                "errmsg abort ;

\ ***************************************************************************
\ Assure that the name following INCLUDEWORD is included in the target
\ wheather it is used of not. This is needed when building a full forth
\ kernel, to make sure all functions are included even if they aren't
\ referenced by COLD.

: INCLUDEWORD   ( | <name> -- )                 \ include function <name>
                [forth]                         \ FORTH needed for IF & THEN
                ' othertype here-t index!
                dup >resaddr @ -1 =     \ if NOT resolved
                if      dup >res                \ add to resolution stack
                        ido_resolve             \ and resolve it NOW
                then    drop ;

FORTH DEFINITIONS

DEFER DEF-INIT                  \ default target initialization
DEFER NO-INIT                   \ default NO initialization

: TARGET-INIT   ( -- )          \ initialize the terget compiler
                ?LIB ABORT" Cant use TARGET-INIT in a library routine"
                ONLY  HOST      ALSO
                FORTH ASSEMBLER ALSO
                      HOST      ALSO
                FORTH TARGET    ALSO DEFINITIONS
                0 !> >in_word   \ reset the WORD input pointer
                $100 ORG
                 $00 DORG
                >target-mem     \ select compiling to target memory
                >target         \ select target defining words
\+ xIC,         ['] xIC, is IC,                 \ install for indexer
\+ xCC,         ['] xCC, is CC,
                othertype here-t index!         \ copy source starting marker
                endtype   here-t index!
                [FORTH]
                0 SAVE!> CURFIL#                \ save and clear curfil#
                F['] IMAGE-INIT                 \ address of init routine
                DUP >COUNT INCR                 \ mark it used and
                        >EXECUTE EXECUTE        \ compile it
                RESTORE> CURFIL#                \ no source available here
                ; IMMEDIATE

' TARGET-INIT IS TARGET-INITIALIZE

: TARGET-DONE   ( -- )
                othertype here-t index!         \ copy source ending marker
                [FORTH]
                TLAST @ CONADDR !-T     \ link last header
                HERE-T  DPADDR  !-T     \ initialize starting DP
                ;

' TARGET-DONE IS TARGET-FINISH

\ **********************************************************************
\ 8086 Indirect Threaded Target Listing program invocation function
\ **********************************************************************

: %make_listing ( -- )          \ build a listing file
                [forth]
                closeall
                ."  Invoking .LST generator.. [press Ctrl-Break to cancel]"
                mypathhndl count        pad  place      \ program path
                " lsi86 "               pad +place      \ batch file
                listing.name >pathend"  pad +place      \ append file
                ?withlib                                \ user wants lib?
        if      "  /lib"                pad +place      \ append "/LIB"
        then    ?nolib                                  \ user wants NO lib?
        if      "  /nolib"              pad +place      \ append "/nolib"
        then    cr space pad count type cr
                [ hidden ]
                pad $sys drop   ;                       \ make listing

' %make_listing is make_listing         \ link into compiler

ASSEMBLER DEFINITIONS FORTH     >LIBRARY

\ ***************************************************************************
\                           OPTIMIZERS !!
\ ***************************************************************************

FORTH   >FORTH

>LIBRARY

