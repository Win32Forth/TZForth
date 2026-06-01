\\ OPTIMIZ.SEQ     Library Optimizers for Target Compiler

Change History:


 11/23/92 10:14 tjz
        Started modifying OPTS8B.SEQ to OPT1600.SEQ.

{

ONLY FORTH ASM1600 ALSO FORTH ALSO COMPILER ALSO DEFINITIONS
HOST ALSO TARGET ALSO

>FORTH

0 VALUE ?16-BIT                      \ 16-bit literal specification

/DATA_IN_ROM                         \ strings are in CODE space

/HIGH-LOW                            \ this processor places words in
                                     \ memory with the high byte in low mem.

: TVER ."  1600 Version 0.000 " ;
' TVER IS TVERSION                   \ install startup message

' NOOP IS DATA-SEG-FIX               \ not a segmented machine

: ?PAIRS        ( n1 n2 -- )         \ make sure n1=n2, or error
                <>
                if      0 " Conditional Branch UNBALANCED" "errmsg
                then    ;

WARNING OFF                          \ no redefinition warning in library

\ ***************************************************************************

TARGET DEFINITIONS


compiler definitions

asm1600 also forth also

I: CEND-CODE    ( -- )
                ll-global? 0=
                if      ll-errs?        \ check for local label errors
                then
                ARUNSAVE IS RUN
                PREVIOUS A; ;

previous previous target

I: %%END-MACRO  ( -- )
                A; llset-
                ?reopt CEND-CODE ;

I: %END-MACRO   ( -- )          \ complete assembly of a MACRO
                [asm1600]
                compile %%end-macro             \ pop assembler vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-MACRO IS END-MACRO       \ install in END-MACRO

I: %%END-LMACRO ( -- )
                A;
                ?reopt CEND-CODE ;

I: %END-LMACRO  ( -- )          \ complete assembly of a MACRO
                [asm1600]
                compile %%end-lmacro            \ pop assembler vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-LMACRO IS END-LMACRO     \ install in END-MACRO
' %END-LMACRO IS END-LCODE      \ install in END-LCODE

\ **********************************************************************

I: tail_opt     ( -- )          \ handle tail optimization
                A; [FORTH]                      \ compile any previous inst
                ?OPT                            \ optimization enabled
                ?TAIL_OPT AND                   \ and tail optimizing
                PREV-CALL-ADDR HERE-T 2- = AND  \ and prev call addr matches
                HERE-T 2- @-T $FE00 AND $4800 = AND \ and preceeded by a CALL
                OPT_LIMIT HERE-T 2- U< AND      \ and after optimize limit
                IF      HERE-T 2- DUP @-T $1FF AND $4800 OR SWAP %!-T
                                                \ then change to JMP
                        1 #del_index            \ discard CALL index record
                        branchtype here-t 2- index!
                        :insttype  here-t 2- index!
                ELSE    [asm1600]
                        branch_mark             \ start of branch operation
                        setassem                \ do assembler setup
                        ret a;                  \ terminate with a RET instruction
                        cend-code               \ pop assembler vocabulary
                        [forth]
                        ?reopt
                THEN    ;

0 VALUE EXEC:ING?               \ did we use EXEC: in this definition?
0 VALUE EXEC:ING2?              \ did we use EXEC: in this definition?

: %RESOLVE_OPT  ( a1 -- )       \ tail resolution optimization for
                                \ forward referenced tail CALLs
                A; [FORTH]                      \ preceeded by a
                DUP >COUNT @ 2 =                \ usage count is exactly 1
                                                \ although the count is 2
                ?OPT AND                        \ optimization is on?
                HERE-T 4 - @-T $FE00 AND $4C00 = AND    \ JMP to
                HERE-T 2-  @-T HERE-T = AND             \ just after itself
                OPT_LIMIT HERE-T 3 - U< AND
                EXEC:ING? 0= AND                \ and NOT useing EXEC:
                IF      2 1 DEL_B/I             \ delete words & instructions
                        HERE-T OVER >RESADDR !  \ RE-resolve symbol
                        OPT_OFF1                \ disable optimization
                                                \ for one time
                        curfil#_save save!> curfil#   \ restore save curfil#
                        :othertype here-t index!
                        restore> curfil#
                THEN    DROP
                OFF> EXEC:ING? ;                \ clear EXEC: used flag

' %resolve_opt is resolve_opt   \ link into compiler

I: %END-L:      ( -- )          \ complete a library CALL definition
                compile tail_opt
                compile unnest ;                \ complete colon def

' %END-L: IS END-L:

I: %END-LM:     ( -- )          \ complete a library MACRO : definition
                [asm1600]
                compile setassem
                compile cend-code
                compile unnest ;

' %END-LM: IS END-LM:

I: %START-T: ( -- )
                ;

' %start-t: is start-t:

I: %SET_COLD_ENTRY_1600 ( -- )
                here-t                  \ 1600 is opposite byte order?????
                cold_start %!-t ;       \ store absolute address in JP inst

' %set_cold_entry_1600 is set_cold_entry

I: %END-T:      ( -- )          \ complete a target CALL definition
                [forth] true save!> state
                ?OPT
                ?TAIL_OPT             AND
                PREV-CALL-ADDR HERE-T 2- = AND  \ and prev call addr matches
                HERE-T 2- @-T $FE00 AND $4800 = AND \ and preceeded by a CALL
                OPT_LIMIT HERE-T 2- U< AND      \ and after optimize limit
                IF      HERE-T 2- DUP @-T $1FF AND $4800 OR SWAP %!-T
                                                \ then change to JMP
                        1 #del_index            \ discard CALL index record
                        branchtype here-t 2- index!
                        :insttype  here-t 2- index!
                ELSE    [asm1600]
                        branch_mark     \ start of branch operation
                        setassem        \ do assembler setup
                        RET A;          \ terminate with a RET inst
                        fend-code       \ do assembler finishup
                        [forth]
                THEN    restore> state
                ?REOPT
                ;

' %END-T: IS END-T:

I: %COMP_CALL   ( a1 -- )                       \ a1 = CFA of symbol
                ?REOPT                          \ re-enable optimization
\                $10 here-t c!-e                 \ compile ext byte
                $4800 ASM,                      \ compile sam8 call opcode
                dup     >resaddr @ dup -1 <>    \ if resolved already
                if      ASM,                    \ resolve this call
                        >count incr             \ bump use count
                                                \ ELSE, add to the chain of
                else    drop                    \ discard the "-1"
                                                \ references to be resolved.
                        dup >chain @ ASM,       \ link chain @ to here
                        here-t 2- over >chain ! \ link here into chain
                        >res                    \ add to resolution stack
                then    ;

' %COMP_CALL IS COMP_CALL

I: %resolve_11600 ( a1 -- )                     \ resolve abs ref to HERE-T
                here-t swap %!-T ;

' %resolve_11600 is resolve_1                   \ link in default resolver

I: %COMP_JMP_IMM ( a1 -- )                      \ a1 = actual address
                ?REOPT                          \ re-enable optimization
                $4C00 ASM, ASM, ;               \ JP always a1

' %COMP_JMP_IMM IS COMP_JMP_IMM

I: %EXT>0       ( n1 -- )       \ clear n1 EXTENTION bytes to zero
                0
                ?do     0 here-t i + c!-e
                loop    ;

' %EXT>0 IS EXT>0       \ insert into TCOMNDX.SEQ function

I: %SUB_RET     ( -- )              \ remove a one byte return instruction
                -1 ALLOT-T          \ preceeding us in memory
                 1 EXT>0
                LIHERE =: LINESTRT
                1 #DEL_INDEX ;      \ delete the previous one


' %SUB_RET IS SUB_RET

I: %TCODE-START ( -- )
                setassem
                [assembler]
                init_labels ;

' %TCODE-START IS TCODE-START

I: %LCODE-START ( -- )
                compile tcode-start     \ initialize the assembler
                asm1600 ;             \ and select assembler vocabulary now!

' %LCODE-START IS LCODE-START

I: %%MACRO-START ( -- )
                a; llset+
                setassem
                init_labels ;

I: %MACRO-START ( -- )
                compile %%macro-start   \ initialize the assembler
                asm1600  ;                \ and select assembler vocabulary now!

' %MACRO-START IS MACRO-START

: %%LMACRO-START ( -- )
                a;
                setassem
                init_labels ;           \ ********* 01/29/91

I: %LMACRO-START ( -- )
                compile %%lmacro-start  \ initialize the assembler
                asm1600 ;               \ and select assembler vocabulary now!

' %LMACRO-START IS LMACRO-START

\ **********************************************************************
\  A new definition for TABLE, to compile IMMEDIATELY into CODE space
\ **********************************************************************

I: xTABLE       ( | <name> -- Wa1 )     \ Double for address
                [forth]
                fhere >r
                {2C} new_symbol
                here-t split swap ,     \ save constant word value LOW
                -1 ,                    \ clear dummy unresolved chain
                0 ,                     \ clear reference counter
                0 ,                     \ clear dummy data length
                  ,                     \ save const value HIGH in >DINITIAL
                r> index_constant
                does>   body>
                        dup  >count incr        \ bump usage
                        dup  >resaddr  @
                        swap >dinitial @ join ; \ return 16-bit value

SWITCH TABLE xTABLE

I: xEND-TABLE   ( -- )                  \ complete the definition of a table
                target ;                \ reselect target vocabulary

SWITCH END-TABLE xEND-TABLE

I: xCREATE      ( | <name> -- )         \ a data pointer to HERE-D
                state @                         \ if used in ":" definition
                if      do_defining             \ switch to defining word
                else    table                   \ else just an array
                then    ;

SWITCH CREATE xCREATE

host definitions

' CONSTANT ALIAS EQUATE         \ EQUATE also defines symbols to CODE space

compiler definitions

\ ***************************************************************************
\ Start of the set of functions supported in the target compiler.
\ These are mostly macros which will compile in-line assembly code.
\ Colon definitions are compiled as routines when defined, and are
\ accessed by a CALL when referenced.

ONLY FORTH ALSO COMPILER ALSO HOST ALSO HTARGET ALSO TARGET ALSO DEFINITIONS
asm1600 ALSO

FHERE FORTH !> LIB_BOTTOM asm1600

>FORTH

I: x::          ( | <name> -- )         \ make a new defining word
        >FORTH
        [FORTH]
        ?FNDDOES> OFF
        (:)                             \ make a : def
        STATE ON
        BEGIN   ?STACK  TDEFINED ?DUP
                IF      >R
                        CASE
                        [TARGET]
                        F['] CREATE OF  COMPILE (T:)
                                        COMPILE STATE   \ marker to index gen
                                        COMPILE ON      \ to mark as : def
                                        COMPILE HERE-T
                                        COMPILE (LIT)
                                        10 X,           \ 10 byte CFA size
                                        COMPILE +
                                        COMPILE COMP_SINGLE
                                        HERE-T [COMPILE] LITERAL
                                        COMPILE COMP_JMP_IMM
                                                                 ENDOF
                        F['] DOES>  OF  COMPILE STATE
                                        COMPILE OFF
                                        [COMPILE] ; ?FNDDOES> ON ENDOF
                        F['] ,      OF  COMPILE ,-T              ENDOF
                        F['] C,     OF  COMPILE C,-T             ENDOF
                        F['] ALLOT  OF  ABORT" Can't use ALLOT"  ENDOF
                        [FORTH]
                             R@ 0>  IF  EXECUTE   ELSE   X,   THEN
                        ENDCASE R>DROP
                ELSE    NUMBER  DOUBLE?
                        IF           [COMPILE] DLITERAL
                        ELSE    DROP [COMPILE] LITERAL
                        THEN
                THEN    TRUE    DONE?
        UNTIL   ?FNDDOES> @ [FORTH] 0=
        IF      0 " No DOES> portion specified" "errmsg abort
        THEN    [TARGET] >TARGET TDOES> ;

SWITCH :: X::                   \ MAKE THIS THE :: HANDLER

>LIBRARY                        \ Select the Library versions of
                                \ defining words.

COMPILER DEFINITIONS

MACRO JMP-TO-4TH-INIT ( -- )    \ jump to runtime initialization
   [asm1600]
    $0000 ,-t                   \ fill in reset vector to point to zero
END-MACRO

MACRO 1600-4TH-INIT ( -- )      \ Target compiler runtime initialization
        [asm1600]

        ldi     r7 $00FF a;             \ initialize data stack
        bra always $1234  a;             \ enter application
        here-t 2- =: cold_start         \ set patch pointer
END-MACRO

FORTH >FORTH

defer EMIT-4TH-INIT

I: %emit-4th-init ( -- )
        [FORTH]
\+ index! othertype here-t index!       \ copy source marker
        0 save!> curfil#                \ index file number to zero
        f['] jmp-to-4th-init            \ address of init routine
        dup >count incr                 \ mark it used
        >execute execute                \ compile forth initialization code
        $0000 org
        f[']  1600-4th-init             \ address of init routine
        dup >count incr                 \ mark it used
        >execute execute                \ compile forth initialization code
        restore> curfil#
        ['] noop is emit-4th-init ;     \ do is only once

$FFFC constant 1600-org

I: TARGET-INIT  ( -- ) \ initialize the target compiler
                [FORTH]
                0 SAVE!> CURFIL#                \ CURFIL#=0 during init code
                ?LIB ABORT" Cant use TARGET-INIT in a library routine"
                me@ me$ dup count rot >pathend" nip -
                1- 0max fpath$ place            \ put program dir in pathbufr
                fpath$ dup count rot >pathend" nip - nip fpath$ c!
                                                \ remove deepest path name
                " DATA\" fpath$ +place          \ append data directory name
                ONLY HOST ALSO
                FORTH TARGET ALSO DEFINITIONS
                FORTH asm1600  ALSO
                ext_init                        \ init extention bytes seg
                0 !> >in_word
                1600-org  org
                $0000    vorg
                >target-mem                     \ select compiling to target
                ['] tinterp is interpret
                ['] %.loadline is .loadline
                tcode-start
                >target                         \ select target defining words
                target                          \ select the target vocabulary
                inst-reset
                lihere !> linestrt
                ['] %emit-4th-init is emit-4th-init
\                ['] xic, is ic,                 \ install index functions
\                ['] xcc, is cc,
                emit-4th-init
                RESTORE> CURFIL#
                ;  IMMEDIATE

' TARGET-INIT IS TARGET-INITIALIZE

I: TARGET-FINI  ( -- )
                othertype here-t index! \ other type index record at end
                end-cseg                \ finish up the segment
                othertype here-t index! \ other type index record at end
                ;

' TARGET-FINI IS TARGET-FINISH

H: RAMRANGE   ( n1 n2 -- )    \ range of valid ram variables
                2drop ;                 \ a dummy in TCOM

H: .FORTH-INIT  ( -- )
                ;       \ 12/16/91 14:09:56.12 tjz
                        \ Forth init is automatic, no manual init needed

\ **********************************************************************
\ Sam8 Version of listing program invocation function
\ **********************************************************************

: %make_listing ( -- )          \ build a listing file
                [ hidden ]
                closeall
                ."  Invoking .LST generator.. [press Ctrl-Break to cancel]"
                mypathhndl count        pad  place      \ path to program
                " ls1600 "              pad +place      \ batch file
                listing.name count      pad +place      \ append file
                ?withlib                                \ user wants lib?
        if      "  /lib"                pad +place      \ append "/LIB"
        then    ?nolib                                  \ user wants NO lib?
        if      "  /nolib"              pad +place      \ append "/nolib"
        then    cr space pad count type cr
                pad $sys drop   ;                       \ make listing

' %make_listing is make_listing         \ link into compiler

