\ BASOPT86.SEQ     Optimizers for BASIC Compiler

ONLY FORTH ASMS8 ALSO FORTH ALSO COMPILER ALSO DEFINITIONS
HOST ALSO TARGET ALSO

FORTH

0 VALUE ?16-BIT                      \ 16-bit literal specification

/LOW-HIGH                       \ this target processor uses low byte of a
                                \ word in the low memory address of a pair.

: TVER ."  SAM8 Version 0.01 " ;
' TVER IS TVERSION             \ install startup message

: ?PAIRS        ( n1 n2 -- )         \ make sure n1=n2, or error
                <>
                if      0 " Conditional Branch UNBALANCED" "errmsg
                then    ;

WARNING OFF                     \ NO REDEFINITION WARNING IN LIBRARY

2VARIABLE ENTRYSAVE

\ ***************************************************************************
\ New function for END-CODE, needs to not use REVEAL

TARGET DEFINITIONS

$C7 CONSTANT PSP        \ Forth stack pointer
$D9 CONSTANT SPL        \ stack pointer low
$DF CONSTANT PAG        \ the page register
$FE CONSTANT EMT        \ io/memory/data wait state setup
$D0 CONSTANT P0         \ port 0
$F0 CONSTANT P0M        \ port 0 address line select
$F1 CONSTANT PM         \ port 0 & 1 outputs open drain
$DE CONSTANT SYM        \ interrupt select
$E0 CONSTANT C0M        \ counter
$C0 CONSTANT FR0        \ Forth working register base
$D6 CONSTANT RP0        \ register pointer for R0-R7
$D7 CONSTANT RP1        \ register pointer for R8-R15

compiler definitions

asms8 also forth also

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

\ **********************************************************************

I: OPT_JR/JP    ( -- )
                [FORTH]
                HERE-T DUP 2- @-T - 4 126 BETWEEN
                IF   HERE-T 2- @-T >R
                        3 1 DEL_B/I             \ delete CALL instruction
                        branch_mark
                        [asms8]
                        JR      T R>    A;
                        [forth]
                ELSE    $8D HERE-T 3 - %C!-T    \ then change to JMP
                        1 #del_index            \ discard CALL index record
                        branchtype here-t 3 - index!
                        :insttype  here-t 3 - index!
                THEN    ;

I: tail_opt     ( -- )          \ handle tail optimization
                A; [FORTH]                      \ compile any previous inst
                ?OPT                            \ optimization enabled
                ?TAIL_OPT AND                   \ and tail optimizing
                PREV-CALL-ADDR HERE-T 3 - = AND \ and prev call addr matches
                HERE-T 3 - C@-T $F6 = AND       \ and preceeded by a CALL
                OPT_LIMIT HERE-T 3 - U< AND     \ and after optimize limit
                IF      OPT_JR/JP
                ELSE    [asms8]
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
                HERE-T 3 - C@-T $8D  = AND      \ JMP
                HERE-T 2- @-T HERE-T = AND      \ to me
                OPT_LIMIT HERE-T 3 - U< AND
                EXEC:ING? 0= AND                \ and NOT useing EXEC:
                IF      3 1 DEL_B/I             \ delete bytes & instructions
                        HERE-T OVER >RESADDR !  \ RE-resolve symbol
                        OPT_OFF1                \ disable optimization
                                                \ for one time
                        curfil#_save save!> curfil#   \ restore save curfil#
\+ index!               :othertype here-t index!
                        restore> curfil#
                THEN    DROP
                OFF> EXEC:ING? ;                \ clear EXEC: used flag

' %resolve_opt is resolve_opt   \ link into compiler

I: %END-L:      ( -- )          \ complete a library CALL definition
                compile tail_opt
                compile unnest ;                \ complete colon def

' %END-L: IS END-L:

I: %END-LM:     ( -- )          \ complete a library MACRO : definition
                [asms8]
                compile setassem
                compile cend-code
                compile unnest ;

' %END-LM: IS END-LM:

forth

  0 value hold-?translate
  0 value ?super8
  0 value ?int:                 \ are we finishing an interrupt : definition?
$24 value ref-strt              \ pointer to start of REF: space
  0 value ref-ptr               \ pointer to next REF: space to use
  0 value ref-len               \ length of REF: space initially zero
  0 value ?worksave             \ are we saving the working registers in INT?

: /super8    ( -- )             \ Super8 target initialization code
             -1 =: ?super8 ;

: /sam8      ( -- )             \ SAM8 target initialization code
              0 =: ?super8 ;

: /ref:      ( -<start>- )      \ define where ref: words go
             bl word number drop =: ref-strt ;

target

\ I: %START-T: ( -- )
\         [asms8]
\         ?translate =: hold-?translate
\         false =: ?translate ;
\
\ ' %start-t: is start-t:

I: %SET_COLD_ENTRY_S8 ( -- )
                here-t                  \ SAM8 is opposite byte order
                cold_start %!-t ;       \ store absolute address in JP inst

' %set_cold_entry_s8 is set_cold_entry

\ I: %END-T:      ( -- )          \ complete a target CALL definition
\                 [forth] true save!> state
\                 ?int:
\                 if      exec:ing2?
\                         if      0 " Can't use EXEC: in an INTERRUPT!" "errmsg
\                         then
\                         ?worksave
\                    IF   [asms8]
\                         pop pag a;
\                         pop rp0 a;
\                         [forth]
\                    THEN [asms8]
\                         branch_mark     \ start of branch operation
\                         IRET a;         \ terminate with a IRET instruction
\                         end-code
\                         [forth]
\                         off> ?int:      \ reset the interrupt colon flag
\                 else    ?OPT
\                         ?TAIL_OPT             AND
\                         PREV-CALL-ADDR
\                         HERE-T 3 -          = AND       \ preceeded by a CALL
\                         HERE-T 3 - C@-T $F6 = AND       \ CALL xxxx
\                         OPT_LIMIT HERE-T 3 - U< AND
\                         IF      OPT_JR/JP
\                         ELSE    exec:ing2? 0=   \ don't need RET inst
\                            IF   [asms8]
\                                 branch_mark     \ start of branch operation
\                                 setassem        \ do assembler setup
\                                 RET A;          \ terminate with a RET inst
\                                 end-code       \ do assembler finishup
\                                 [forth]
\                            THEN
\                         THEN
\                 then    restore> state
\                 OFF> EXEC:ING2?                 \ clear EXEC: flag
\                 ?REOPT
\                 hold-?translate =: ?translate ;
\
\ ' %END-T: IS END-T:

I: %COMP_CALL   ( a1 -- )                       \ a1 = CFA of symbol
                ?REOPT                          \ re-enable optimization
                exec:ing2? 0=           \ if not EXEC:, then compile opcode
                if      $10 here-t c!-e         \ compile ext byte
                        $0F6 CC,                \ compile sam8 call opcode
                else    wordtype here-t index!  \ a data word
                then
                dup     >resaddr @ dup -1 <>    \ if resolved already
                if      ASM,                    \ resolve this call
                        >count incr             \ bump use count
                                                \ ELSE, add to the chain of
                else    drop                    \ discard the "-1"
                                                \ references to be resolved.
                        dup >chain @ O,         \ link chain @ to here
                        here-t 2- over >chain ! \ link here into chain
                        >res                    \ add to resolution stack
                then    ;

' %COMP_CALL IS COMP_CALL

I: %resolve_1s8   ( a1 -- )                     \ resolve abs ref to HERE-T
                here-t swap %!-T ;

' %resolve_1s8 is resolve_1                     \ link in default resolver

I: %COMP_JMP_IMM ( a1 -- )                      \ a1 = actual address
                ?REOPT                          \ re-enable optimization
                $8D IC, ASM, ;                  \ JP T a1, HI/LO byte order

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

\ ' %TCODE-START IS TCODE-START

I: %LCODE-START ( -- )
                compile %tcode-start     \ initialize the assembler
                asms8 ;             \ and select assembler vocabulary now!

' %LCODE-START IS LCODE-START

I: %%MACRO-START ( -- )
                a; llset+
                setassem
                init_labels ;

I: %MACRO-START ( -- )
                compile %%macro-start   \ initialize the assembler
                asms8  ;                \ and select assembler vocabulary now!

' %MACRO-START IS MACRO-START

I: %%LMACRO-START ( -- )
                a; setassem
                init_labels ;           \ ********* 01/29/91

I: %LMACRO-START ( -- )
                compile %%lmacro-start  \ initialize the assembler
                asms8 ;                 \ and select assembler vocabulary now!

' %LMACRO-START IS LMACRO-START

\ **********************************************************************
\  A new definition for TABLE, to compile IMMEDIATELY into CODE space
\ **********************************************************************

\ H: CREATE       ( | <name> -- Wa1 )     \ Double for address
\                 [forth]
\                 fhere >r
\                 {2C} new_symbol
\                 here-t split swap ,     \ save constant word value LOW
\                 -1 ,                    \ clear dummy unresolved chain
\                 0 ,                     \ clear reference counter
\                 0 ,                     \ clear dummy data length
\                   ,                     \ save const value HIGH in >DINITIAL
\                 r> index_constant
\                 does>   body>
\                         dup  >count incr        \ bump usage
\                         dup  >resaddr  @
\                         swap >dinitial @ join ; \ return 16-bit value

\ ***************************************************************************
\ Start of the set of functions supported in the target compiler.
\ These are mostely macros which will compile in-line assembly code.
\ Colon definitions are compiled as routines when defined, and are
\ accessed by a CALL when referenced.

ONLY FORTH ALSO COMPILER ALSO HOST ALSO HTARGET ALSO TARGET ALSO DEFINITIONS
ASSEMBLER ALSO

FHERE FORTH !> LIB_BOTTOM ASSEMBLER

>LIBRARY                        \ Select the Library versions of
                                \ defining words.

COMPILER DEFINITIONS

MACRO JMP-TO-4TH-INIT ( -- )         \ jump to runtime initialization
   [asms8]
    jp      t $100 a; \ jump to initialization code at $100
END-MACRO

MACRO SUPER8-4TH-INIT ( -- )    \ Target compiler runtime initialization
   [asms8]
\ See note, below before changing this code !!!!
   di                           \ disable interupts
   sb0                          \ select register bank 0
   clr     r emt                \ norm i/o, fast mem, no prog or data mem wait
   clr     r p0                 \ clear port 0
   ld      r p0m # $ff          \ select address lines for port 0
   ld      r pm  # $38          \ port 0 out+open drain, port 1=out+open drain
   ld      r sym # $7e          \ fast int, level 7, no global int., en. fast.
   sb1                          \ select bank 1
   ld      r c0m # $f4          \ cntr 0: cascade, up/dn ctl, no capture/retry
   sb0                          \ select bank 0
   clr     r spl                \ set low byte of stack pointer to 0
   srp     # fr0                \ set working register pointers
   ld      r psp # $bf          \ set forth parameter stack pointer
   jp      t $1234 a;           \ enter application
   here-t 2- =: cold_start      \ set patch pointer
END-MACRO

MACRO SAM8-4TH-INIT ( -- )      \ Target compiler runtime initialization
   [asms8]
\ See note, below before changing this code !!!!
   di                           \ disable interupts
   sb0                          \ select register bank 0
   clr     r emt                \ norm i/o, fast mem, no prog or data mem wait
   clr     r spl                \ set low byte of stack pointer to 0
   srp     # fr0                \ set working register pointers
   ld      r psp # $bf          \ set forth parameter stack pointer
   jp      t $1234 a;           \ enter application
   here-t 2- =: cold_start      \ set patch pointer
END-MACRO

FORTH >FORTH

I: emit-4th-init ( -- )
        [FORTH]
        othertype here-t index!    \ copy source marker
        0 save!> curfil#             \ index file number to zero
        f['] jmp-to-4th-init         \ address of init routine
        dup >count incr              \ mark it used
        >execute
        execute                      \ compile forth initialization code
        $100 org
        ?super8
        if      f['] super8-4th-init \ address of init routine
        else    f[']   sam8-4th-init \ address of init routine
        then    dup >count incr      \ mark it used
        >execute execute             \ compile forth initialization code
        restore> curfil# ;

$20 constant sam8-org

I: TARGET-INIT  ( -- ) \ initialize the target compiler
                [FORTH]
                0 SAVE!> CURFIL#                \ CURFIL#=0 during init code
                ?LIB ABORT" Cant use TARGET-INIT in a library routine"
                ONLY HOST ALSO
                FORTH TARGET ALSO DEFINITIONS
                FORTH ASMS8  ALSO
                ext_init                        \ init extention bytes seg
                0 !> >in_word
                ref-strt =: ref-ptr             \ initialize REF: pointer
                sam8-org  org
                $40      vorg
                >target-mem                     \ select compiling to target
                >target                         \ select target defining words
                target                          \ select the target vocabulary
                inst-reset
                lihere !> linestrt
                ['] xic, is ic,                 \ install index functions
                ['] xcc, is cc,
                emit-4th-init   \ 12/16/91 14:09:24.70 tjz
                RESTORE> CURFIL#
                ;

' TARGET-INIT IS TARGET-INITIALIZE

I: TARGET-FINI  ( -- )
                othertype here-t index! \ other type index record at end
                ref-strt org            \ define where vectors start and
                wordtype  here-t index! \ mark start of REF: area
                ref-len %allot-t        \ allocate entire short call area
                end-cseg                \ finish up the segment
                othertype here-t index! \ other type index record at end
                ;

' TARGET-FINI IS TARGET-FINISH

\ **********************************************************************
\ Sam8 Version of listing program invocation function
\ **********************************************************************

: %make_listing ( -- )          \ build a listing file
                [ hidden ]
                closeall
                ."  Invoking .LST generator.. [press Ctrl-Break to cancel]"
                mypathhndl count        pad  place      \ path to program
                " ls8 "                 pad +place      \ batch file
                listing.name >pathend"  pad +place      \ append file
                ?withlib                                \ user wants lib?
        if      "  /lib"                pad +place      \ append "/LIB"
        then    ?nolib                                  \ user wants NO lib?
        if      "  /nolib"              pad +place      \ append "/nolib"
        then    cr space pad count type cr
                pad $sys drop   ;                       \ make listing

' %make_listing is make_listing         \ link into compiler



