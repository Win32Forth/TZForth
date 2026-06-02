\ OPTGEN.SEQ     Library linkage and optimizers for Target Compiler

ONLY FORTH ASMGEN ALSO FORTH ALSO COMPILER ALSO DEFINITIONS
HOST ALSO TARGET ALSO

>FORTH

' f." is L."    \ Aliases for this example target, to allow simply
' f." is T."    \ displaying messages for functions.

: ?1cr          ( -- )          \ a utility word for generic target
                #out @ 8 >
                if      cr
                then    ;

: ?2cr          ( -- )          \ a utility word for generic target
                #out @ 8 >
                if      cr cr
                then    ;

FORTH

/LOW-HIGH                       \ this target processor uses low byte of a
                                \ word in the low memory address of a pair.

: TVERX ."  GENERIC Version 0.0 " ;
' TVERX IS TVERSION

' NOOP IS DATA-SEG-FIX          \ not a segmented machine

WARNING OFF                     \ NO REDEFINITION WARNING IN LIBRARY
FORTH                           \ we want a Forth NOT a target variable

create GENERIC.ext ," BIN" 0 ,      \ define image file extension for generic

generic.ext count image.ext place   \ move into compilers .EXT array

\ ***************************************************************************

ASMGEN also forth also

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

previous previous target

: %END-MACRO    ( -- )          \ complete assembly of a MACRO
                ?reopt
                [ASMGEN]
                compile a;                      \ make sure ASM80 is done
                compile cend-code               \ pop ASM80 vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-MACRO IS END-MACRO       \ install in END-MACRO

: %END-LCODE    ( -- )          \ complete assembly of a LCODE
                ?reopt
                [ASMGEN]
                compile a;                      \ make sure ASM80 is done
                compile cend-code               \ pop ASM80 vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-LCODE IS END-LCODE       \ install in END-LCODE

: %END-L:       ( -- )          \ complete a library CALL definition
                [ASMGEN]
                compile setassem
                compile DO_RET
                compile a;                      \ make sure ASM80 is done
                compile cend-code               \ pop ASM80 vocabulary
                compile unnest ;

' %END-L: IS END-L:

: %END-LM:      ( -- )          \ complete a library MACRO : definition
                [ASMGEN]
                compile setassem
                compile cend-code
                compile unnest ;

' %END-LM: IS END-LM:

: %END-T:       ( -- )          \ complete a target CALL definition
                [ASMGEN]
                setassem                \ do ASMGEN setup
                DO_RET a;               \ terminate with a RET instruction
                fend-code ;             \ do ASMGEN  finishup

' %END-T: IS END-T:

: %COMP_CALL    ( a1 -- )                       \ a1 = CFA of symbol
                ?1cr 8 sp>col  dup >name ." Referencing: " .id 35 sp>col
                dup     >resaddr @ -1 <>        \ if resolved already
                if      >count incr             \ bump use count
                        ." compile resolved reference "
                else    >res                    \ ELSE, add it to the chain
                                                \ of forward references
                        ." a forward reference "
                then    ;

' %COMP_CALL IS COMP_CALL

: %RESOLVE_1    ( a1 -- )       \ resolve a forward reference to HERE-T
                cr ." Resolving one forward reference at "
                h. ." to HERE-T" ;

' %RESOLVE_1 IS RESOLVE_1             \ link into compiler

' DROP IS COMP_JMP_IMM

: %SUB_RET      ( -- )          \ subtract the previous UNNEST or RETURN
                cr ." Removing just compiled UNNEST or RETURN" ;

' %SUB_RET IS SUB_RET

: %START-T:     ( -- )
                ?2cr
                ." Defining-: " fhere count type ." , NESTING if needed" ;

' %START-T: IS START-T:

: %START-TCODE  ( -- )
                ?2cr
                ." Defining-CODE " fhere count type ;

' %START-TCODE IS TCODE-START

: T:.ID         ( a1 -- )
                ?2cr
                ." Including-: " .ID ;

: TCODE.ID      ( a1 -- )
                ?2cr
                ." Including-CODE " .ID ;

: TMACRO.ID     ( a1 -- )
                cr ." Performing-MACRO " .ID ;

: %START-L:     ( -- )
                COMPILE (LIT) LAST @ X, COMPILE T:.ID ;

' %START-L: IS START-L:
' %START-L: IS START-LM:

: %START-LCODE  ( -- )
                COMPILE (LIT) LAST @ X, COMPILE TCODE.ID ;

' %START-LCODE IS LCODE-START

: %START-MACRO  ( -- )
                COMPILE (LIT) LAST @ X, COMPILE TMACRO.ID ;

' %START-MACRO IS MACRO-START

\ ***************************************************************************

ONLY FORTH ALSO COMPILER ALSO HOST ALSO HTARGET ALSO TARGET ALSO DEFINITIONS
ASMGEN ALSO

>LIBRARY                        \ Select the Library versions of
                                \ defining words.


\ ***************************************************************************

MACRO IMAGE-INIT ( -- )         \ Target compiler runtime initialization
                [assembler]
                llab-init
                [ASMGEN]
        cr ." Compiling entry code and initialization as needed for this"
        cr ." target processors particular architecture."
        cr ." like: JMP COLD"         ( Low Level COLD Entry point )
        END-MACRO       \ ***** End of IMAGE-INIT *****

\ ***************************************************************************

FORTH >FORTH

: %COMP_HEADER  ( a1 -- )       \ compile a target header for string a1
                ?2cr
                cr ." Compiling a header for: " count type cr ;

' %COMP_HEADER IS COMP_HEADER                \ link into compiler

\ ***************************************************************************

FORTH DEFINITIONS

DEFER DEF-INIT                  \ default target initialization
DEFER NO-INIT                   \ default NO initialization

: TARGET-INIT   ( -- )          \ initialize the terget compiler
                ?LIB ABORT" Cant use TARGET-INIT in a library routine"
                ONLY  HOST      ALSO
                FORTH ASMGEN    ALSO
                      HOST      ALSO
                FORTH TARGET    ALSO DEFINITIONS
                0 !> >in_word   \ reset the WORD input pointer
                cr ." Setting the origin ADDRESS for target CODE"
                $100 ORG
                cr ." Setting the origin ADDRESS for target DATA"
                 $00 DORG
                >target-mem     \ select compiling to target memory
                >target         \ select target defining words
                [FORTH]
                0 SAVE!> CURFIL#                \ save and clear curfil#
                F['] IMAGE-INIT                 \ address of init routine
                DUP >COUNT INCR                 \ mark it used and
                        >EXECUTE EXECUTE        \ compile it
                RESTORE> CURFIL#                \ no source available here
                ; IMMEDIATE

' TARGET-INIT IS TARGET-INITIALIZE

: %TARGET-FINISH        ( -- )  \ finish up code after compile is done
                cr ." Performing cleanup after compile completion" ;

' %TARGET-FINISH IS TARGET-FINISH

: %SAVE-TARGET-IMAGE    ( -- )  \ save the compiled target program
                cr ." Saving the compiled target image" ;

' %SAVE-TARGET-IMAGE IS SAVE-IMAGE.COM        \ no image here

ASMGEN DEFINITIONS FORTH     >LIBRARY

\ ***************************************************************************
\                           OPTIMIZERS !!
\ ***************************************************************************

FORTH >LIBRARY

