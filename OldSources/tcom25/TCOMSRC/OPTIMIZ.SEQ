\ OPTIMIZ.SEQ     Library Optimizers for Target Compiler

ONLY FORTH ASSEMBLER ALSO FORTH ALSO COMPILER ALSO DEFINITIONS
HOST ALSO TARGET ALSO

>FORTH

FORTH

/LOW-HIGH                       \ this target processor uses low byte of a
                                \ word in the low memory address of a pair.

: xcommas>blanks ( -- )
                ;

switch commas>blanks xcommas>blanks     \ disable comma conversion

: TVER ."  8086 Version 2.40 " ;
' TVER IS TVERSION             \ install startup message

: ?PAIRS        ( n1 n2 -- )         \ make sure n1=n2, or error
                <>
                if      0 " Conditional Branch UNBALANCED" "errmsg
                then    ;

WARNING OFF                     \ NO REDEFINITION WARNING IN LIBRARY
FORTH                           \ we want a Forth NOT a target variable
VARIABLE IMM-HERE               \ Most recent place where immediate move
                                \ to BX was compiled

\- #del_index           ' drop alias #del_index

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
                [forth]
                off> ?macro
                [compile] FOR; ;                \ complete colon def

' %END-MACRO IS END-MACRO       \ install in END-MACRO

I: %%END-LMACRO ( -- )
                a;
                ?reopt cend-code ;

I: %END-LMACRO  ( -- )          \ complete assembly of a LCODE
                compile %%end-lmacro
                [forth]
                off> ?macro
                [compile] FOR; ;                \ complete colon def

' %END-LMACRO IS END-LMACRO     \ install in END-LMACRO
' %END-LMACRO IS END-LCODE      \ install in END-LCODE

}
  ***************************************************************************
   08/29/91 Notes on Tail Optimization by Tom Zimmer

          Tail optimization can save one byte at the end of every
        function that contains a call to another function as the last
        operation of the definition.  This is done by omitting the RET
        instruction, and changing the previous CALL to a JMP.  Some
        problems occur when trying to do this however. If the definition
        being changed to a JMP contains code like this:

                : RESTCURSOR    ( -- )
                                R>          \ pull off the return address
                                AT? 2>R     \ save cursor position
                                >R ;        \ restore return address

          Where information is saved on the return stack under under the
        routines return address, then you MUST use a CALL to access the
        routine, and MAY NOT use a JMP.  There is no way for the compiler
        to know which words might fall into this catagory however, so you
        must either not do this, or make sure this type of word is not
        the last word of a definition before the ';'.  In the case of
        RESTCURSOR above, I have included in the library an extra line to
        turn off optimization for one step after RESTCURSOR is used, to
        prevent tail optimization from messing with the CALL to
        RESTCURSOR.

          Another problem that comes up with tail optimization, is empty
        routines, like NOOP.

                : NOOP  ;

          NOOP will compile simply a RET instruction with optimization
        turned off. With optimization is turned on, then the tail
        optimizer looks before the RET to see if it can omit the REt and
        change a previous CALL to a JMP. Here is an example of where this
        would be a problem:

                        ... 2DUP ;
                : NOOP ;

          Tail Optimization will omit the RET after the 2DUP, and change
        the CALL to 2DUP into a JMP.  Then the tail optimizer for NOOP
        looks back, and sees what it thinks is a CALL to 2DUP, and
        discards the RET from NOOP.  True the CALL has already been
        changed into a JMP, and this is what must be tested to make tail
        optimization fail for the NOOP case.

          All this is why the tests for tail optimization are so
        extensive, to assure it is only used when it is proper to do so.

  ***************************************************************************
{

I: TAIL_OPT     ( -- )          \ handle tail optimization
                A; [FORTH]                      \ compile any previous inst
                ?OPT                            \ optimization enabled
                ?TAIL_OPT AND                   \ and tail optimizing
                PREV-CALL-ADDR HERE-T 3 - = AND \ and prev call addr matches
                HERE-T 3 - C@-T       $E8 = AND \ and preceeded by a CALL
                3 #?OPT                     AND \ and after optimize limit
                IF      $E9 HERE-T 3 - %C!-T    \ then change to JMP
                ELSE    [assembler]
                        setassem                \ do assembler setup
                        ret a;                  \ terminate with a RET instruction
                        cend-code               \ pop assembler vocabulary
                        [forth]
                        ?reopt
                THEN    ;
}
***************************************************************************
 08/29/91 Notes on extended tail optimization by Tom Zimmer

          A coincidence of having a forward reference to a function occur
        at the end of a definition, and having tail optimization occur,
        is that the last CALL in some definitions ends up getting changed
        into a JMP to the next byte where the referenced function gets
        compiled.  This happens because TCOM resolves functions in the
        revers order in which they are referenced, so the following code
        can happen:

        source  -->                     .. 2dup ;
        compiles-->             JMP 2DUP
        resolves-->     2DUP    ...the code for 2DUP...

          The obvious optimization here, is to discard the "JMP 2DUP",
        and let the function fall into 2DUP which gets compiled three
        bytes earlier than it would have, and use the RET at the end of
        2DUP to return to its caller. This optimization is easy to
        implement, but has its own pitfalls. Since 2DUP must be resolved
        before compiling it, (to detect if the forward reference is
        really a forward reference to 2DUP) it is not possible to correct
        any previous CALL to 2DUP in the same routine (as it has already
        been resolved to an address where 2DUP won't exist). Consequently
        we must only use this form of optimization when the forward
        referenced word has only been used once in the previous routine.

***************************************************************************
{

0 VALUE EXEC:ING?               \ did we use EXEC: in this definition?

: %RESOLVE_OPT  ( a1 -- )       \ tail resolution optimization for
                                \ forward referenced tail CALLs
                A; [FORTH]                      \ preceeded by a
                DUP >COUNT @ 2 =                \ usage count is exactly 1
                                                \ although the count is 2
                ?OPT AND                        \ optimization is on?
                HERE-T 3 - C@-T $E9 =   AND     \ JMP
                HERE-T 2- @-T 0=        AND     \ to me
                3 #?OPT                 AND
                EXEC:ING? 0= AND                \ and NOT useing EXEC:
                IF      3 1 DEL_B/I             \ delete bytes & instructions
                        HERE-T OVER >RESADDR !  \ RE-resolve symbol
                        curfil#_save save!> curfil#   \ restore save curfil#
\+ index!               :othertype here-t index!
                        restore> curfil#
                THEN    DROP
                OPT_OFF1                \ disable optimization for one time
                OFF> EXEC:ING? ;        \ clear EXEC: used flag

' %resolve_opt is resolve_opt   \ link into compiler

I: %END-L:      ( -- )          \ complete a library CALL definition
                compile tail_opt
                compile unnest ;                \ complete colon def

' %END-L: IS END-L:

I: %END-LM:     ( -- )          \ complete a library MACRO : definition
                [assembler]
                compile setassem
                compile cend-code
                compile unnest ;                \ complete colon def

' %END-LM: IS END-LM:

\ TAIL recursion handler. If definition ends in a CALL, then change the
\ CALL to a JMP and don't bother compiling a RET.

TRUE VALUE RETING?

I: %END-T:      ( -- )          \ complete a target CALL definition
                A; [FORTH]                      \ preceeded by a
                ?OPT
                ?TAIL_OPT AND
                PREV-CALL-ADDR HERE-T 3 - = AND \ preceeded by a CALL
                HERE-T 3 - C@-T $E8 =       AND \ CALL
                3 #?OPT                     AND
                IF      $E9 HERE-T 3 - %C!-T    \ change to JMP
                ELSE    true save!> state
                        setassem                \ do assembler setup
                        reting?
                        IF      [ASSEMBLER]
                                ret a;          \ terminate with a RET inst
                                [FORTH]
                        THEN    fend-code       \ do assembler finishup
                        restore> state
                        ?REOPT
                THEN    [FORTH] on> reting? ;

' %END-T: IS END-T:

' NOOP    IS START-T:         \ no start needed in CALL threaded system

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

I: %TGOTO       ( -<name>- )    \ compile a JMP to a function instead of CALL
                [FORTH] ' DUP RES_COMP_JMP >DTYPE C@ {S} <>
                ABORT" is NOT a subroutine, Can ONLY ['] subroutines!" ;
' %TGOTO IS TGOTO

I: %LGOTO       ( | <name> -- a1 )
                COMPILE RES_COMP_JPP [FORTH] ' DUP  X,
                >DTYPE C@ {S} <>
                ABORT" is NOT a subroutine, Can ONLY ['] subroutines!" ;
' %LGOTO IS LGOTO

I: %SUB_RET     ( -- )          \ INLINE unoptimizer, removes tail recursion
                                \ in the case of INLINE
                A; [FORTH]                      \ preceeded by a
                HERE-T 1- C@-T $C3 =            \ RET
                OPT_LIMIT HERE-T 1- U< AND
                IF      1 1 DEL_B/I             \ delete bytes & instructions
                ELSE    HERE-T 3 - C@-T $E9 =           \ JMP preceeds?
                        IF      $E8 HERE-T 3 - %C!-T    \ change to CALL
                        ELSE                            \ else a big problem
                                0 " INLINE: Failure, no RET" "errmsg
                        THEN
                THEN    ;

' %SUB_RET IS SUB_RET

I: %TCODE-START ( -- )
                OPT_OFF1                \ ********* 08/29/91
                setassem
                init_labels ;           \ ********* 01/29/91

' %TCODE-START IS TCODE-START

I: %LCODE-START ( -- )
                compile tcode-start     \ initialize the assembler
                assembler ;             \ and select assembler vocabulary now!

' %LCODE-START IS LCODE-START

I: %%MACRO-START ( -- )
                a; llset+
                setassem
                init_labels ;           \ ********* 01/29/91

I: %MACRO-START ( -- )
                compile %%macro-start   \ initialize the assembler
                [forth]
                on> ?macro
                assembler ;             \ and select assembler vocabulary now!

' %MACRO-START IS MACRO-START

I: %%LMACRO-START ( -- )
                a;
                setassem
                init_labels ;           \ ********* 01/29/91

I: %LMACRO-START ( -- )
                compile %%lmacro-start  \ initialize the assembler
                [forth]
                on> ?macro
                assembler ;             \ and select assembler vocabulary now!

' %LMACRO-START IS LMACRO-START

I: %FIX-CREATE-DOES ( a1 -- a2 )        \ test and modify target address
                                        \ to the target data address if a1
                                        \ points at a create does word
                dup      %c@-t $B8 =            \ MOV AX, # $xxxx
                over 3 + %c@-t $E9 = and        \ JMP zzzz
                if      1+ %@-t                 \ fetch the target data addr
                then    ;

' %FIX-CREATE-DOES IS FIX-CREATE-DOES   \ patch into compiler at FORDOES
                                        \ in COMPILE2.SEQ

0 VALUE :RUNSAVE

H: asm[         ( -- )
                [forth]
                @> RUN !> :RUNSAVE
                ['] <RUN> IS RUN
                state off %%macro-start /nostack1 ; immediate

H: ]asm         ( -- )
                %end-amacro
                :RUNSAVE IS RUN
                T] ; immediate

\ ***************************************************************************
\ MACRO arguments for TCOM
\ ***************************************************************************

FORTH

CREATE ARGUMENTS 128 allot

H: GET_ARGS     ( -- )          \ parse out the arguments from input line
                assembler
                arguments 128 erase
                arguments
                begin   bl word dup c@ over 1+ c@ '\' <> and
                while   ?uppercase  find
                        if      over ! 2+
                        else    drop
                        then
                repeat  2drop >in @ =: >in-t ;

H: @ARG         ( n1 -- )
                dup 1 <
                if      0 " Arguments start with 1" "errmsg
                then
                1- 0max 4 min 2* arguments + @ ?dup
                if      execute
                then    ;

H: ;-           ( -- )
                [FORTH]
                ?lib abort" ;- can ONLY be used by a target applicaition!"
                off> reting?
                [HOST] [COMPILE] ; ; immediate

\ ***************************************************************************
\ Start of the set of functions supported in the target compiler.
\ These are mostely macros which will compile in-line assembly code.
\ Colon definitions are compiled as routines when defined, and are
\ accessed by a CALL when referenced.

ONLY FORTH ALSO COMPILER ALSO HOST ALSO HTARGET ALSO TARGET ALSO DEFINITIONS
ASSEMBLER ALSO

FHERE 1- FORTH !> LIB_BOTTOM ASSEMBLER

>LIBRARY                        \ Select the Library versions of
                                \ defining words.

\ ***************************************************************************
\ DONOT CHANGE the first three instructions of SYSINIT. The ADD instruction
\ must be HOT patched by the image save routine so DS will be set properly
\ when the image loads in. The $E4F6 value is verified by the patch routine
\ to make sure the code has not changed. It is then replaced with the proper
\ value to add to AX so DS will be correct.

VARIABLE DP                     \ DP is really a variable that always exists,
                                \ and is always at address DATA-START.

 VARIABLE RP0
 VARIABLE SP0
 VARIABLE 'TIB
 VARIABLE MEMEND                \ end of available data memory
 VARIABLE BROKEN
2VARIABLE BIOSBKSAVE
 VARIABLE CTRLBKSAVE
 VARIABLE HADCRITICAL           \ non-zero if critcal error has happened

LMACRO IMAGE-INIT ( -- )         \ Target compiler runtime initialization
                [FORTH]
                ?driver                 \ we are compiling a device driver
                ?custom or
                if      %%end-lmacro
                        EXIT            \ ***** EXITS HERE *****
                then
                [ASSEMBLER]
\   **********   DON'T CHANGE THE NEXT EIGHT LINES  **********

                MOV AX, CS              \ get a copy of the CODE segment
        0 $:    ADD AX, # $E4F6 a;      \ patched later to adjust for
                                        \ where the data really is.
                here-t 2- =: data-seg+  \ set patch pointer
                MOV DS, AX      a;      \ Set the data segment
                                        \ down 256 bytes from call stack

\   **********************************************************

                [FORTH]                 \ *******************************
                ?0init                  \ if 0INIT, !! ** STOP HERE ** !!
                                        \ *******************************
        if      [ASSEMBLER]
                MOV SS, AX              \ set hardware stack segment to DS
                mov bx, sp              \ get current end of dictionary
                mov rp0 bx              \ set return stack TOP
                sub bx, # $200          \ adjust up to location of data stack
                mov si, bx              \ set stack pointer
                mov sp0 bx              \ set data stack top pointer
                mov bp, # $00           \ init BP to $0000
                push bp         a;      \ push return to address $0000
                [FORTH]
                %%end-lmacro
                EXIT                    \ ********* LEAVES HERE *********
        then    ram-seg -1 <>           \ is this a romable system
                IF                      \ if it is, include the code to
                                        \ move rom data into ram
                        [ASSEMBLER]
                        MOV CX, DATA-START      \ DATA-START = HERE
                        MOV AX, # RAM-SEG
                        MOV ES, AX              \ ES = RAM-SEG
                        SUB SI, SI
                        SUB DI, DI              \ clear DI, and SI
                        MOVSB   REP             \ move ROM into RAM
                        MOV AX, ES
                        MOV DS, AX              \ reset DS to ES=RAM
                        [FORTH]
                THEN
                [ASSEMBLER]
                MOV SS, AX              \ set hardware stack segment to DS
                MOV ES, AX              \ and extra register to DS
                mov bx, DP              \ get current end of dictionary
                add bx, # spsize        \ adjust up to location of data stack
                mov si, bx              \ set stack pointer
                mov sp0 bx              \ set data stack top pointer
                add bx, # 2
                mov 'tib bx             \ set terminal input buffer pointer
                mov 0 [bx], # 0 word    \ clear TIB to a nul
                add bx, # rpsize        \ adjust to end of return stack
                mov sp, bx              \ set return stack
                mov rp0 bx              \ set return stack TOP
                add bx, # 2             \ adjust past return stack
                mov dp bx               \ re adjust DP to end of stacks
                mov memend # $FFF0 word \ default end of available data memory
                mov broken # $0000 word \ default to NOT broken with ^break
\ save control break vector and status flag
                PUSH ES
                MOV AX, # $351B         \ Get the interupt vector for
                INT $21                 \ BIOS control break vector
                MOV BIOSBKSAVE BX
                MOV BIOSBKSAVE 2+ ES    \ Save old vector
                POP ES
                MOV AX, # $3300         \ Control BREAK flag status
                INT $21
                SUB DH, DH
                MOV CTRLBKSAVE DX       \ Save it away for later restoral
\ Setup the Control Break vector to our routine
                push ds                 \ save data segment
                mov ax, cs
                mov ds, ax              \ set DS to CS
                MOV DX, # 2 $           \ BIOSBK
                MOV AX, # $251B         \ BIOS Break
                INT $21
                MOV DX, # 3 $           \ DOSBK
                MOV AX, # $2523         \ DOS Break
                INT $21
                MOV DX, # 0
                MOV AX, # $3301         \ DISABLE DOS Break
                INT $21
\ Install critical error handler
                mov ax, cs
                mov ds, ax              \ set DS to CS
                MOV DX, # 4 $           \ get new hndlr addr
                MOV AX, # $2524         \ set critical error int vector
                INT $21
                pop ds                  \ recover the data segment
\ Finish initialization and CALL application
                MOV BX, # 0             \ and top of stack register with zero
                MOV BP, BX              \ !!!!!BP WILL ALWAYS BE ZERO!!!!!
                CALL 1 $ a;             \ CALL default initialization program
                CALL 1 $ a;             \ CALL real program (gets patched)
                here-t 2- =: cold_start \ set patch pointer
\ Restore the Control Break BIOS and DOS handlers
                here-t    =: final_exit \ set program exit pointer for BYE
                MOV AX, CS              \ get CS
                ADD AX, CS: 0 $ 1+ \ $0103 \ get the data seg relative offset
                MOV DS, AX              \ DS now points at our data segment
                PUSH DS
                MOV DX, BIOSBKSAVE
                MOV DS, BIOSBKSAVE 2+
                MOV AX, # $251B
                INT $21
                POP DS
                MOV DX, CTRLBKSAVE
                MOV AX, # $3301         \ Control BREAK flag status
                INT $21
\ Finally, EXIT back to DOS
                MOV AX, # $4C00
                INT $21                 \ terminate back to DOS
\ **********************************************************************
\ Application terminates here. Following are Control Break handler rtns
\ **********************************************************************
\ Control Break interrupt routine
\ **********************************************************************
2 $: ( BIOSBK ) PUSH AX                 \ save the registers we need
                PUSH DS
                MOV AX, CS              \ get CS
                ADD AX, CS: 0 $ 1+ \ $0103 \ get the data seg relative offset
                MOV DS, AX              \ DS now points at our data segment
                MOV BROKEN # $FFFF WORD \ turn broken flag on
                POP DS
                POP AX
                IRET
\ DOS Control Break handler
3 $: ( DOSBK )  PUSH AX
                MOV AH, # 0             \ throw away BREAK KEY
                INT $16
                POP AX
                CLC
                RETF
\ Critical error handler
4 $: ( criticl) STI                     \ re-enable interrupts
                INC DS: HADCRITICAL WORD
                                        \ increment when critical errors occur
                MOV AL, # 0             \ tell DOS to ignore the error
                IRET                    \ return from interrupt
          1 $:  END-LMACRO              \ 1 $: marks the end of the init code

FORTH DEFINITIONS               >FORTH

DEFER DEF-INIT                  \ default target initialization
DEFER NO-INIT                   \ default NO initialization

: TARGET-INIT   ( -- )          \ initialize the terget compiler
                ?LIB ABORT" Cant use TARGET-INIT in a library routine"
                ONLY  HOST      ALSO
                FORTH TARGET    ALSO DEFINITIONS
                0 !> >in_word   \ reset the WORD input pointer
                ?driver
                if       0 org  \ device drivers start at zero
                else  $100 org  \ 8086 code starts at $0100 in code segment
                then   $00 dorg \ 8086 data starts at $0000 in data segment
                                \ but DP is there, and more are at $0002
                >target-mem     \ select compiling to target memory
                >target         \ select target defining words
                target          \ Select the target vocabulary
\+ xIC,         ['] xIC, is IC,                 \ install for indexer
\+ xCC,         ['] xCC, is CC,
\+ index!       othertype here-t index!         \ copy source starting marker
                ?long_set                       \ set the ?LONG value
                [TARGET]
                F['] DP
                DUP >COUNT INCR                 \ mark it used and
                        EXECUTE DROP            \ compile it & clean stack
                [FORTH]
                0 SAVE!> CURFIL#                \ save and clear curfil#
                F['] IMAGE-INIT                 \ address of init routine
                DUP >COUNT INCR                 \ mark it used and
                        >EXECUTE EXECUTE        \ compile it
                RESTORE> CURFIL#                \ no source available here
                ?0INIT 0=
        IF      ?DEFINIT
                IF      DEF-INIT
                ELSE    NO-INIT
                THEN    ?sym_inc                \ if including a symbol tbl
                IF      symorg      org         \ switch to append address
                        symvorg     dorg        \ after compiling init code
                THEN
        THEN    ; IMMEDIATE

' TARGET-INIT IS TARGET-INITIALIZE

: TARGET-FINSH  ( -- )
\+ index!       othertype here-t index!         \ copy source ending marker
                ;

' TARGET-FINSH IS TARGET-FINISH

ASSEMBLER DEFINITIONS FORTH     >LIBRARY

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


I: STORE_OPT    ( -- )          \ The ! MACRO
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

I: CSTORE_OPT   ( -- )          \ The C! MACRO
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

I: CSTORE_OPT2  ( -- )          \ double optimize CSTORE immediates
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 14 -  @-T $4E4E =        \ 4E           DEC SI
                                                \ 4E           DEC SI
                HERE-T 12 -  @-T $1C89 = AND    \ 89 1C        MOV 0 [SI], BX
                HERE-T 10 - C@-T $BB   = AND    \ BB xx xx     MOV BX, # xxxx
                HERE-T  7 -  @-T $1E88 = AND    \ 88 1E yy yy  MOV yyyy BL
                                                \ AD           LODSW
                                                \ 8B D8        MOV BX, AX
                14 #?OPT                 AND
                IF      HERE-T 5 - @-T          \ get the address yyyy
                        HERE-T 9 - @-T          \ get the value xxxx
                        14 7 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        MOV #  BYTE     A;      \ MOV yyyy # xxxx BYTE
                        [FORTH]
                THEN
        THEN    [TARGET]
                ;

I: CSTORE_OPT2A ( -- )          \ second optimize CSTORE immediates
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 12 -  @-T $1E8B <>       \ not a        MOV BX, xxxx
                HERE-T 10 - C@-T $BB   = AND    \ BB xx xx     MOV BX, # xxxx
                HERE-T  7 -  @-T $1E88 = AND    \ 88 1E yy yy  MOV yyyy BL
                                                \ AD           LODSW
                                                \ 8B D8        MOV BX, AX
                10 #?OPT                 AND
                IF      HERE-T 5 - @-T          \ get the address yyyy
                        HERE-T 9 - @-T          \ get the value xxxx
                        10 4 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        MOV #  BYTE     A;      \ MOV yyyy # xxxx BYTE
                        LODSW           A;
                        MOV BX, AX      A;
                        [FORTH]
                THEN
        THEN    [TARGET]
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

I: STORE_OPT2   ( -- )          \ double optimize store immediates
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
        THEN    [TARGET]
                ;

I: STORE_OPT2A' ( -- )          \ second optimize store immediates
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 12 -  @-T $1E8B =        \ 8B 1E xx xx  MOV BX, xx xx
                HERE-T  8 - C@-T $43   = AND    \ INC BX
                HERE-T  7 -  @-T $1E89 = AND    \ 89 1E yy yy  MOV yyyy BX
                HERE-T 10 -  @-T                \ the source addr and
                HERE-T  5 -  @-T = AND          \ destination addr match
                                                \ AD           LODSW
                                                \ 8B D8        MOV BX, AX
                12 #?OPT                 AND
                IF      HERE-T 5 - @-T          \ get the address yyyy
                        12 5 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        INC WORD        A;      \ INC yyyy WORD
                        LODSW           A;
                        MOV BX, AX      A;
                        [FORTH]
                THEN
        THEN    [TARGET]
                ;

I: STORE_OPT2A  ( -- )          \ second optimize store immediates
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 12 -  @-T $1E8B <>       \ not a        MOV BX, xxxx
                HERE-T 10 - C@-T $BB   = AND    \ BB xx xx     MOV BX, # xxxx
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
        THEN    [TARGET]
                ;

I: STORE_OPT2B  ( -- )          \ second optimize store immediates
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
        THEN    [TARGET]
                ;

I: STORE_OPT3   ( -- )          \ triple optimize store fetch combos
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
        THEN    [TARGET]
                ;

I: IMM/ABS_OPT  ( -- <xxxx> f1 )                \ Immediate optimize
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T  7 -  @-T $4E4E =        \ DEC SI
                                                \ DEC SI
                HERE-T  5 -  @-T $1C89 = AND    \ MOV 0 [SI], BX
                HERE-T  3 - C@-T $BB   = AND    \ MOV BX, # xxxx
                7 #?OPT                  AND
                IF      HERE-T 2 - @-T          \ get the immediate xxxx
                        7 4 DEL_B/I             \ delete bytes & instructions
                        HERE-T 3 - C@-T $BB =   \ preceeded by another IMM
                        3 #?OPT and             \ and optimizable
                        IF      -2              \ return -2 for 2 immediates
                        ELSE    -1              \ return -1 for immediate
                        THEN
                ELSE
                        HERE-T  8 -  @-T $4E4E =     \ DEC SI
                                                     \ DEC SI
                        HERE-T  6 -  @-T $1C89 = AND \ MOV 0 [SI], BX
                        HERE-T  4 -  @-T $1E8B = AND \ MOV BX, xxxx
                        IF      HERE-T 2 - @-T       \ get the address xxxx
                                8 4 DEL_B/I     \ delete bytes & instructions
                                1       \ return 1 for !ABSOLUTE!
                        ELSE    0       \ else return 0
                        THEN
                THEN
        ELSE    0
        THEN    [TARGET]
                ;

I: IMM_BEFORE   ( -- <xxxx> f1 )                \ Immediate optimize
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
        ELSE    ?REOPT FALSE
        THEN    [TARGET]
                ;

I: OVER_OPT     ( -- f1 )       \ Preceeded by an OVER
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T  7 -  @-T $4E4E =        \ DEC SI
                                                \ DEC SI
                HERE-T  5 -  @-T $1C89 = AND    \ MOV 0 [SI], BX
                HERE-T  3 -  @-T $5C8B = AND    \ MOV BX, 2 [SI]
                HERE-T  1-  C@-T $02   = AND
                7 #?OPT                  AND
                IF      7 4 DEL_B/I             \ delete bytes & instructions
                        TRUE
                ELSE    FALSE
                THEN
        ELSE    FALSE
        THEN    [TARGET]
                ;

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

I: AT_OPT       ( -- )          \ The @ MACRO
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

I: CAT_OPT      ( -- )          \ The @ MACRO
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

>LIBRARY

\ ***************************************************************************
\ optimizer recognizes IF preceeded by 0=, and removes 0=, sends flag to IF
\ to use 0=IF
\ ***************************************************************************

FORTH   >FORTH

: ?0=IF_OPT     ( -- f1 )       \ optimize IF preceeded by 0=
                A; [FORTH]
                ?OPT            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 5 -  @-T $EB83 =         \ SUB BX, # 1
                HERE-T 2 -  @-T $DB19 = AND     \ SBB BX, BX
                5 #?OPT                 AND
                IF      HERE-T 3 - C@-T 1 =     \ if subtract by one
                        IF      5 2 DEL_B/I     \ delete bytes & instructions
                        ELSE    HERE-T 3 - C@-T 1-      \ else just
                                HERE-T 3 - C!-T         \ reduce count by one
                                2 1 DEL_B/I             \ and delete one inst
                        THEN    TRUE            \ return true, optimized
                ELSE                            \ can't optimize, so
                        FALSE                   \ return false, not optimized
                THEN
        ELSE    ?REOPT
                FALSE
        THEN    [ASSEMBLER]                     \ follow with a compare
                LODSW
                XCHG BX, AX
                CMP AX, BP
                [TARGET] ;

: MEMORY_IF_OPT ( f1 -- f1 )    \ optimize IF preceeded by a MEMORY reference
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 12 - @-T $4E4E =         \ 4E           DEC SI
                                                \ 4E           DEC SI
                                                \ 89 1C        MOV 0 [SI], BX
                HERE-T  8 - @-T $1E8B = AND     \ 8B 1E xx xx  MOV BX, xxxx
                                                \ AD           LODSW
                                                \ 93           XCHG BX, AX
                                                \ 39 E8        CMP AX, BP
                12 #?OPT                AND
                IF      HERE-T 6 - @-T          \ get address xxxx
                        12 7 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        CMP BP, ( xxxx ) a;
                        [FORTH]
                THEN
        THEN    [TARGET]
                ;

: DUP_IF_OPT    ( f1 -- f1 )    \ optimize IF preceeded by a DUP
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 8 - @-T $4E4E =          \ 4E           DEC SI
                                                \ 4E           DEC SI
                                                \ 89 1C        MOV 0 [SI], BX
                HERE-T 4 - @-T $93AD = AND      \ AD           LODSW
                                                \ 93           XCHG BX, AX
                HERE-T 2 - @-T $E839 = AND      \ 39 E8        CMP AX, BP
                8 #?OPT AND
                IF      8 6 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        CMP BP, BX a;
                        [FORTH]
                THEN
        THEN    [TARGET]
                ;

: #=IF_OPT      ( f1 -- f1 )    \ optimize IF preceeded by a immediate compare
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF      ( test BYTE immediate )         \ instructions before ?
                HERE-T 11 - @-T $4E4E =         \ 4E           DEC SI
                                                \ 4E           DEC SI
                                                \ 89 1C        MOV 0 [SI], BX
                HERE-T  7 - @-T $EB83 = AND     \ 83 EB xx     SUB BX, # xx
                                                \ AD           LODSW
                                                \ 93           XCHG BX, AX
                HERE-T  2 - @-T $E839 = AND     \ 39 E8        CMP AX, BP
                11 #?OPT                AND
                IF      HERE-T 5 - C@-T         \ get byte immediate
                        DUP $80 AND IF $FF00 OR THEN
                        11 7 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        CMP BX, #    ( xx ) a;
                        [FORTH]
                        EXIT                    \ leave definition here
                THEN
                ( test WORD immediate )
                HERE-T 12 - @-T $4E4E =         \ 4E           DEC SI
                                                \ 4E           DEC SI
                                                \ 89 1C        MOV 0 [SI], BX
                HERE-T  8 - @-T $EB81 = AND     \ 81 EB xx xx  SUB BX, # xx
                                                \ AD           LODSW
                                                \ 93           XCHG BX, AX
                HERE-T  2 - @-T $E839 = AND     \ 39 E8        CMP AX, BP
                OPT_LIMIT HERE-T 11 - U< AND
                IF      HERE-T 6 - @-T          \ get address xxxx
                        12 7 DEL_B/I            \ delete bytes & instructions
                        [ASSEMBLER]
                        CMP BX, # ( xx ) a;
                        [FORTH]
                THEN
        THEN    [TARGET]
                ;

: PREV_RET?     ( -- f1 )    \ preceeded by a RET instruction?
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
                ?TAIL_OPT AND                   \ and tail optimizing
        IF      HERE-T 1- C@-T $C3 =            \ C3=RET before?
                HERE-T 1- OPT_LIMIT = AND DUP   \ matches prev instruction
           IF   PREV-CALL-ADDR HERE-T 4 - =     \ and prev call addr matches
                HERE-T 4 - C@-T       $E8 = AND \ and preceeded by a CALL
                IF      $E9 HERE-T 4 - %C!-T    \ then change to JMP
                        1 1 DEL_B/I             \ delete byte & instruction
                THEN
           THEN
        ELSE    FALSE
        THEN    [TARGET]
                ;

>LIBRARY

\ ***************************************************************************
\ MACRO to move BX to the stack
\ ***************************************************************************

FORTH   >FORTH

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

\ Defining words place the pointer to the data area in AX, so we must
\ push BX and load BX from AX before performing the body of the
\ defining word. See also "TDOES>" in COMPILE2.SEQ.

: AX_TO_BX      ( -- )          \ macro to save BX and recover AX to BX
                [ASSEMBLER]
                DEC SI          A;
                DEC SI          A;
                MOV 0 [SI], BX  A;
                MOV BX, AX      A;
                [TARGET]
                ;

' AX_TO_BX IS COMP_STACK_LOAD   \ link into compiler

: LOAD_BX       ( -- )          \ macro to LOAD BX
                A; [FORTH]
                ?OPT                            \ Are we optimizing?
        IF                                      \ instructions before ?
                HERE-T 5 -  @-T $4E4E =         \ DEC SI
                                                \ DEC SI
                HERE-T 3 -  @-T $1C89 = AND     \ MOV 0 [SI], BX
                HERE-T 1-  C@-T $5B   = AND     \ POP BX
                3 #?OPT                 AND
                IF      5 4 DEL_B/I             \ delete bytes & instructions
                        [ASSEMBLER]
                        INC SP          A;      \ just discard a return
                        INC SP          A;      \ stack value
                        [FORTH]
                ELSE    \ tjz 11/26/93 16:47 added for immediate before drop
                        HERE-T 7 -  @-T $4E4E =         \ DEC SI
                                                        \ DEC SI
                        HERE-T 5 -  @-T $1C89 = AND     \ MOV 0 [SI], BX
                        HERE-T 3 - C@-T $BB   = AND     \ MOV BX, # xxxx
                        7 #?OPT                 AND
                        IF      7 4 DEL_B/I             \ delete bytes & instructions
                        ELSE    [ASSEMBLER]
                                LODSW           A;
                                MOV BX, AX      A;
                                [FORTH]
                        THEN
                THEN
        ELSE    ?REOPT
                [ASSEMBLER]
                LODSW           A;
                MOV BX, AX      A;
                [FORTH]
        THEN    [TARGET]
                ;

>LIBRARY

