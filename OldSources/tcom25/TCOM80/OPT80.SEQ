\ OPT80.SEQ     Library Optimizers for Target Compiler

ONLY FORTH ASM80 ALSO FORTH ALSO COMPILER ALSO DEFINITIONS
HOST ALSO TARGET ALSO

>FORTH

FORTH

/LOW-HIGH                       \ this target processor uses low byte of a
                                \ word in the low memory address of a pair.

: TVER80 ."  8080 Version 0.75 " ;
' TVER80 IS TVERSION

' NOOP IS DATA-SEG-FIX          \ not a segmented machine

WARNING OFF                     \ NO REDEFINITION WARNING IN LIBRARY
FORTH                           \ we want a Forth NOT a target variable

create cpm.ext ," CPM" 0 ,      \ define image file extension for 8080

cpm.ext count image.ext place   \ move into compilers .EXT array

\ ***************************************************************************
\ New function for END-CODE, needs to not use REVEAL

ASM80 also forth also

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
                [ASM80]
                compile a;                      \ make sure ASM80 is done
                compile cend-code               \ pop ASM80 vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-MACRO IS END-MACRO       \ install in END-MACRO

: %END-LCODE    ( -- )          \ complete assembly of a LCODE
                ?reopt
                [ASM80]
                compile a;                      \ make sure ASM80 is done
                compile cend-code               \ pop ASM80 vocabulary
                [compile] FOR; ;                \ complete colon def

' %END-LCODE IS END-LCODE       \ install in END-LCODE

: %END-L:       ( -- )          \ complete a library CALL definition
                [ASM80]
                compile setassem
                compile DO_RET
                compile a;                      \ make sure ASM80 is done
                compile cend-code               \ pop ASM80 vocabulary
                compile unnest ;

' %END-L: IS END-L:

: %END-LM:      ( -- )          \ complete a library MACRO : definition
                [ASM80]
                compile setassem
                compile cend-code
                compile unnest ;

' %END-LM: IS END-LM:

: %END-T:       ( -- )          \ complete a target CALL definition
                [ASM80]
                setassem                \ do ASM80 setup
                DO_RET a;               \ terminate with a RET instruction
                fend-code ;             \ do ASM80 finishup

' %END-T: IS END-T:

: %COMP_CALL    ( a1 -- )                       \ a1 = CFA of symbol
                :calltype here-t index!         \
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
                setassem                \ initialize the ASM80
                othertype here-t index!
                here-t 2+ ,-t           \ start code words pointing to body
                [assembler]
                llab-init ;             \ clear all labels

' %TCODE-START IS TCODE-START

: %MACRO-START  ( -- )
                compile setassem        \ initialize the ASM80
                ASM80 ;                 \ and select ASM80 vocabulary now!

' %MACRO-START IS MACRO-START

: %LCODE-START  ( -- )
                compile %tcode-start   \ initialize the code word CFA
                ASM80 ;                 \ and select ASM80 vocabulary now!

' %LCODE-START IS LCODE-START


\ ***************************************************************************

ONLY FORTH ALSO COMPILER ALSO HOST ALSO HTARGET ALSO TARGET ALSO DEFINITIONS
ASM80 ALSO

>LIBRARY                        \ Select the Library versions of
                                \ defining words.


\ ***************************************************************************
\ Use great caution when changing any of the following constants, they
\ point into specific places in the initialization code that follows.

$100 CONSTANT ORIGIN
$108 CONSTANT DPUSH
$109 CONSTANT HPUSH
$10A CONSTANT >NEXT
$110 CONSTANT >NEXT1
$115 CONSTANT NEST
$126 CONSTANT DODOES
$137 CONSTANT DOCREATE
$13C CONSTANT DOCONSTANT
$145 CONSTANT DODEFER
$14E CONSTANT RPZERO
$150 CONSTANT RP               \ Not enough registers on an 8080
$152 CONSTANT SPZERO

\ ***************************************************************************
\ Use great caution when changing any of this code, the constants above
\ point into the following code to specific routines.

MACRO IMAGE-INIT ( -- )         \ Target compiler runtime initialization
                [assembler]
                llab-init
                [ASM80]
\ LABEL ORIGIN
        NOP  0 $ JMP    ( Low Level COLD Entry point )
        NOP   -1 JMP    ( Low Level WARM Entry point )

\ LABEL DPUSH
        D PUSH

\ LABEL HPUSH
        H PUSH

\ LABEL >NEXT
        IP LDAX   IP INX    A L MOV   IP LDAX   IP INX   A H MOV

\ LABEL >NEXT1
        M E MOV   H INX   M D MOV   XCHG   PCHL

\ LABEL NEST
        RP LHLD  H DCX  H DCX  RP SHLD   C M MOV  H INX  B M MOV
        D INX  E C MOV  D B MOV  >NEXT JMP ( predecrement RP (mjm)

\ LABEL DODOES
        RP LHLD  H DCX  H DCX  RP SHLD   C M MOV  H INX  B M MOV
        B POP   D INX   D PUSH   >NEXT JMP

\ LABEL DOCREATE
        D INX  D PUSH   >NEXT JMP

\ LABEL DOCONSTANT
        D INX  XCHG  M E MOV  H INX  M D MOV  D PUSH  >NEXT JMP

\ LABEL DODEFER   ( -- )
        D INX  XCHG M E MOV  H INX  M D MOV  XCHG  >NEXT1 JMP

\ LABEL RPZERO          A special location to hold RP0
        $C000 ,-T

\ LABEL RP              A special location to hold RP
        $C000 ,-T

\ LABEL SPZERO          A special location to hold SP0
        $BF00 ,-T

\ COLD ENTRY POINT
0 $:
      $C000 H LXI
          RP SHLD                                       \ RP  at $C000
      RPZERO SHLD                                       \ RP0 at $C000
      $-100 D LXI
            D DAD
      SPZERO SHLD                                       \ SP0 at $BF00
             SPHL                                       \ SP  at $BF00
      $0000 H LXI                                       \ entry point
                here-t 2- =: cold_start                 \ set patch pointer
       >NEXT1 JMP

END-MACRO       \ ***** End of IMAGE-INIT *****

\ ***************************************************************************

FORTH >FORTH

: %START-T:     ( -- )
                othertype here-t index!
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
                :othertype here-t index!      \ actually a header type
                HERE-T VLINK DUP @ ,-T !      \ make a chain of headers
                HERE-T 2- TLAST !             \ LINK of LAST for CONTEXT set
                DUP C@ OVER + $80 SWAP CSET   \ set MSB of last char byte
                DUP C@ 1+ S,-T  ;             \ compile in header

[target] ' %HEADER [forth] IS COMP_HEADER     \ link into compiler

\ ***************************************************************************
\ Re-define VARIABLE and CONSTANT to work with this indirect threaded system

: %VAR          ( a1 -- )
                F['] DOCREATE >resaddr @        \ addr of "docreate"
                here-t 2- !-t                   \ set CFA to DOCREATE
                here-t 2- swap >resaddr !       \ resolve to CFA
                0 ,-t   ;                       \ fill body with zero

: VARIABLE      ( | <name> -- )
                fhere >r
                (L:)                            \ make header
                compile (lit) r> x,
                compile %var
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

: %CON          ( n1 a1 -- )
                F['] DOCONSTANT >resaddr @      \ addr of "doconstant"
                here-t 2- !-t                   \ set CFA to DOCONSTANT
                here-t 2- swap >resaddr !       \ resolve to CFA
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
                '       dup >resaddr @ -1 =     \ if NOT resolved
                if      dup >res                \ add to resolution stack
                        ido_resolve             \ and resolve it NOW
                then    drop ;

FORTH DEFINITIONS

DEFER DEF-INIT                  \ default target initialization
DEFER NO-INIT                   \ default NO initialization

: TARGET-INIT   ( -- )          \ initialize the terget compiler
                ?LIB ABORT" Cant use TARGET-INIT in a library routine"
                ONLY  HOST      ALSO
                FORTH ASM80     ALSO
                      HOST      ALSO
                FORTH TARGET    ALSO DEFINITIONS
                0 !> >in_word   \ reset the WORD input pointer
                $100 ORG
                 $00 DORG
                >target-mem     \ select compiling to target memory
                >target         \ select target defining words
\+ xIC,         ['] xIC, is IC,                 \ install for indexer
\+ xCC,         ['] xCC, is CC,
\ \+ index!       othertype here-t index!         \ copy source starting marker
                [FORTH]
                0 SAVE!> CURFIL#                \ save and clear curfil#
                F['] IMAGE-INIT                 \ address of init routine
                DUP >COUNT INCR                 \ mark it used and
                        >EXECUTE EXECUTE        \ compile it
                RESTORE> CURFIL#                \ no source available here
                ; IMMEDIATE

' TARGET-INIT IS TARGET-INITIALIZE

: TARGET-DONE   ( -- )
\ \+ index!       othertype here-t index!         \ copy source ending marker
                [FORTH]
                " CONTEXT" ">$ ?UPPERCASE  FIND         \ if used HEADERS
                IF      DUP >RESADDR @ DUP 0< 0=        \ and has resaddr
                        IF      TLAST @ OVER 2+ !-T     \ link last header
                        THEN    DROP                    \ into CONTEXT
                THEN    DROP
                " DP" ">$ ?UPPERCASE  FIND              \ if used HEADERS
                IF      DUP >RESADDR @ DUP 0< 0=        \ and has resaddr
                        IF      HERE-T OVER 2+ !-T      \ link HERE
                        THEN    DROP                    \ into DP
                THEN    DROP    ;

' TARGET-DONE IS TARGET-FINISH

ASM80 DEFINITIONS FORTH     >LIBRARY

\ ***************************************************************************
\                           OPTIMIZERS !!
\ ***************************************************************************

FORTH   >FORTH

>LIBRARY

