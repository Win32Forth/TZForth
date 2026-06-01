\ COMPILE2.SEQ          A true Code compiler for Forth      by Tom Zimmer

comment:

          An optimizing target compiler for the Public Domain Forth
        system F-PC by Tom Zimmer.

          Released to the Public Domain this date 10/11/89 by the
        author Tom Zimmer.


comment;

\ ***************************************************************************
\ Library code routines, used for CODE definitions that are accessed by
\ CALL rather than MACRO. An LCODE routine is only included in the
\ target if it is referenced.

DEFER LCODE-START

I: LCODE        ( | <name> -- )         \ Library CODE routine
                !csp
                fhere >r                \ save here for later
                -1 add_symbol           \ make a symbol not yet used
                compile (lit)           \ compile (lit)
                r> x,                   \ followed by addr of symbol
                compile res_symbol      \ resolve usage of symbol
                on> ?lib
                lcode-start
                ]  ;                    \ compile remaining portion

I: END-LCODE    ( -- )                  \ end a library code word
                DOES>  PERFORM OFF> ?LIB ; IMMEDIATE
END-LCODE                               \ execute once to allocate space

' CRASH IS END-LCODE                    \ give it a dummy function

I: LLABEL       ( | <name> -- )         \ Library LABEL routine
                fhere >r
                LCODE
                r> cdoes> body>
                dup >resaddr @ -1 =
                if      dup >chain @ swap       \ link chain @ to here
                        here-t 1+ over >chain ! \ link here+1 into chain
                        >res                    \ add to resolution stack
                        here-t 3 + +            \ compensate for relative
                                                \ instruction adjustment
                else    >resaddr @
                then    ;

\ ***************************************************************************
\ Library and Target compiler functions. These words either compile actual
\ code into the target "TARG_COMPILE", or compiler functions into the library
\ "LIB_COMPILE" that will LATER compile code into the target.

I: LIB_COMPILE  ( a1 -- )
                dup >dtype c@   \ body contains TYPE byte
                case
( Macro )       {M}  of  >execute x,                            endof
( Constant )    {C}  of  compile res_comp_lit    x,             endof
( 2Constant )  {2C}  of  compile res_comp_dbl    x,             endof
( FConstant )   {F}  of  compile res_comp_fcn    x,             endof
( Data )        {D}  of  compile res_comp_lit    x,             endof
( Value )       {V}  of  compile res_comp_val    x,             endof
( Subroutine )  {S}  of  compile res_comp_cll    x,             endof
( dEfer )       {E}  of  compile res_comp_def    x,             endof
( Table )       {T}  of  compile res_comp_tbl    x,             endof
                  ( elseof )
                        drop
                        " is NOT a target symbol! " "errmsg
                endcase ;

I: TARG_COMPILE ( a1 -- )       \ Compile a target symbol
                                \ body contains TYPE byte
                dup >dtype c@ {M} {T} between           \ and valid type byte
                over lib_bottom u> and                  \ above lib_bottom
                if      dup >dtype c@
                        EXEC:
( Macro )               res_comp_macro
( Constant)             res_comp_single
( 2Constant )           res_comp_double
( FConstant )           res_comp_fconst
( Data )                res_comp_single
( Value )               res_comp_value
( Subroutine)           res_comp_call
( dEfer )               res_comp_defer
( Table )               res_comp_table
                else    " is an invalid symbol! " "errmsg
                then    ;

\ ***************************************************************************
\ Lookup a word from input stream, with auto TIB refill if needed.

I: TDEFINED     ( | <name> -- a1 f1 )   \ get a word from input stream
                begin   @> >in =: >in-t
                        bl word dup c@ 0=       \ if nothing in line
                        ?fillbuff               \ optionally refill buffer
                while   drop a;
                        line-done
                        0 >in !
                        filltib                 \ refill the buffer
                        #tib @ 0=
                        if      0 " End of file reached while compiling!"
                                "errmsg abort
                        then
                        expand_tib
                        spinner                 \ something to watch
                repeat  skip'c' ?uppercase find ;

\ ***************************************************************************
\ Library COLON definitions. L: words are only included in the target
\ dictionary if they are referenced They are accessed with a CALL.
\ No forward references are allowed while creating Library definitions.
\ When L: words are later referenced, they are auto-resolving.

DEFER START-T:  ' NOOP IS START-T:
DEFER START-L:  ' NOOP IS START-L:
DEFER START-LM: ' NOOP IS START-LM:

I: (L:)         ( | <name> .. ;F -- )   \ define a function in host
                ?exec
                !csp
                on> ?lib                \ librarying
                fhere >r                \ save here for later
                -1 add_symbol           \ make a symbol not yet used
                compile (lit)           \ compile (lit)
                r> x,                   \ followed by addr of symbol
                compile res_symbol      \ resolve usage of symbol
                compile (lit) -1 x,
                compile %save!>
                compile state
                start-l:                \ needed for indirect threaded code
                spinner2                \ something to look at
                ;

I: (LM:)        ( | <name> .. ;F -- )   \ define a function in host
                ?exec
                !csp
                on> ?lib                \ librarying
                -1 add_symbol           \ make a symbol not yet used
                compile (lit) -1 x,
                compile %save!>
                compile state
                start-l:                \ needed for indirect threaded code
                spinner2                \ something to look at
                ;

I: L]         ( -- )
                state on
                begin   ?stack  tdefined ?dup
                        if      0>
                                if      execute     \ execute immediate words
                                else    lib_compile \ compile into library
                                then
                        else    number  double?
                                if      swap dup
                                        compile comp_lit x,
                                then    drop
                                        compile comp_lit x,
                        then    true    done?
                until   ;

I: LLITERAL     ( n1 -- )       \ compile a literal into a library definition
                compile comp_lit x, ;

DEFER END-L:                    \ See the library for this definition
DEFER END-LM:
DEFER END-L;

I: L;           ( --- )                 \ finish-up library compile
                compile %restore>
                compile state
                state @ 0=
                if      0 " Not Compiling!" "errmsg
                then    ?tcomcsp END-L; off> ?lib [compile] [  ; immediate

I: L:           ( | <name> -- )
                ['] END-L: IS END-L;
                (L:) L] ; immediate

I: LM:          ( | <name> -- )
                ['] END-LM: IS END-L;
                fhere >r
                (LM:) L]
                {M} r> >dtype c! ;      \ data type is macro

I: LALLOT       ( n1 -- )
                drop
                0 " Can't use ALLOT in the library!" "errmsg ;

I: LASCII       ( | <letter> -- )       \ compile inline an ascii letter
                bl word 1+ c@
                compile comp_lit x, ; immediate

\ ***************************************************************************
\ A couple of variables used to determine how to resolve LOOPing branches
\ in the compiler.

VARIABLE ?DOING         ?DOING   OFF
VARIABLE ?LEAVING       ?LEAVING OFF

\ ***************************************************************************
\ Forward store and fetch words

defer for_does>

I: forval       ( a1 n2 -- )    \ forward handler for values
                ?lib
                if      compile res_comp_&val  x, @ x,
                else    state @                         \ if compiling
                        if      res_comp_&value perform
                        else    swap 2+ @
                            case
                                1 of    res_comp_&value         endof
                                2 of    res_comp_&value !-D     endof
                                        2drop 0
                                        " Use this word in a ':' definition"
                                        "errmsg
                            endcase
                        then
                then    ;

I: forvd        ( a1 n2 -- )    \ forward handler for variables & defered
                ?lib
                if      compile res_comp_lit   x, @ x,
                else    state @                         \ if compiling
\                        ?macro 0= and
                        if      res_comp_single perform
                        else    swap 2+ @
                            case
                                1 of    ?dresolve
                                        dup >count incr >resaddr @      endof
                                2 of    ?dresolve
                                        dup >count incr >resaddr @ !-D  endof
                                        2drop 0
                                        " Use this word in a ':' definition"
                                        "errmsg
                            endcase
                        then
                then    ;

I: &>only       ( a1 -- )       \ check to be sure only &> or addrof> is used
                @ ['] noop <>
                if      0
                        " Only &> or addrof> can be used on functions"
                        "errmsg
                then    ;

I: forsub       ( a1 n2 -- <n1> )       \ forward handler for subroutines
                ?lib
                if      compile res_comp_sub x, &>only
                else    state @                         \ if compiling
                        if      res_comp_subroutine &>only
                        else    0
                                " Use this word in a ':' definition" "errmsg
                                nip >resaddr @ fix-create-does
                        then
                then    ;

I: %for_does>   ( a1 -- )       \ forward handler for var, val, defered
                                \ and subroutines
                ' dup >dtype c@
                case
                        {V} of  forval  endof
                        {D} of  forvd   endof
                        {E} of  forvd   endof
                        {S} of  forsub  endof
                                2drop
                        " Attempt to use !> type operator on an invalid symbol"
                        "errmsg
                endcase ;

' %for_does> is for_does>

I: for>word     ( a1 | <name> -- )
                create , , immediate
                does> for_does> ;

\ ***************************************************************************
\ Directs TCOM to compile the definition following as if it were a MACRO,
\ in the current colon definition being built. [MACRO:] only works when
\ preceeding references to LIBRARY definitions.
\ ***************************************************************************

H: [MACRO:]     ( | <name> -- )
                ?lib state @ and                \ if compiling a macro
                if      0 " Cannot use [MACRO:] inside a MACRO!" "errmsg
                        exit
                then
                ' DUP >DTYPE C@ {S} =
                IF      ON> ?INLINE             \ make it compile inline
                        >EXECUTE EXECUTE        \ compile it inline
                        SUB_RET
                        OFF> ?INLINE            \ restore NON-inline
                ELSE    " [MACRO:] must be followed by a function!" "errmsg
                THEN    ; IMMEDIATE

\ Use NO_INLINE at the beginning of LIBRARY words that have multiple
\ exits. Note that NO_INLINE will only work in CODE words, NOT IN ICODE
\ words. Make sure that your ICODE words DON'T HAVE MULTIPLE EXITS!

I: %NO_INLINE   ( -- )
                ?INLINE
                IF      0 " This word cannot be used INLINE!" "errmsg
                THEN    ;

H: NO_INLINE    ( -- )
                COMPILE %NO_INLINE ; IMMEDIATE

I: NO_TINLINE   ( -- )
                0 " ONLY Library words can be INLINE" "errmsg ;

\ ***************************************************************************
\ New target CODE to create the proper target header and symbol.

I: %TLABEL      ( | <name> -- )         \ define an unresolved local label
                >in @
                bl word pad dup>r 32 cmove \ save the name at here to pad
                >in !
                save> context
                {S}  new_symbol
                restore> context
                -1 ,                    \ not yet resolved
                -1 ,                    \ clear dummy unresolved chain
                0 ,                     \ clear reference counter
                0 ,                     \ data size is 0
                +lab# dup ,             \ save the label number
                                        \ in ">DINITIAL" field
                r> here 32 cmove        \ get the name back
                [assembler]
                $                       \ an unresolved local label
                [compiler]
                does> body>
                      dup >count incr         \ bump usage
                          >dinitial @
                [assembler]
                $                       \ an unresolved local label
                [compiler]
                ;

: ?ASSEMBLING   ( -- f1 )               \ are we currently assembling an inst
                [assembler] aprior @ [forth] ['] drop =
                if      0 " Undefined symbol" "errmsg
                        false                   \ not assembling, give error
                else    true                    \ we are assembling, its ok
                then    [compiler] ;

: ?redefined    ( a1 -- a1 )
                dup >resaddr @ -1 <>
                over lib_top u< or
                ?noredef and
                if      dup lib_top u<
                        if      dup " Attempt to REDEFINE a LIBRARY symbol!"
                        else    dup " Attempt to REDEFINE a symbol! "
                        then    "errmsg
                then
                dup >count @ 0>         \ if count shows it has been used
                ?noredef 0= and         \ and redefinition is permitted
                if      dup " Redefining a word ALREADY USED!" "warnmsg
                then    ;

DEFER TCODE-START
0 VALUE INTERPSAVE
0 VALUE ?TCODING

I: commas>blanks ( -- )
                ?tcoding 0= ?exit
                tib #tib @
                begin   ',' scan ?dup
                while   over bl swap c!
                repeat  drop ;

\ TINTERP is not really RECURSIVE, but I needed to get to the CFA
\ to get the address of DOCOL for MACRO verification.

I: TINTERP      ( -- )
                commas>blanks
        begin   ?stack
                @> >in !> >in-t
                defined
                if      execute
                else    %number
                        if      double? 0=
                                if      drop
                                then
                        else    2drop           \ discard double zero
                                ?assembling             \ are we assembling
                                                        \ an instruction?
                                if      >in-t !> >in    \ reset >IN
                                        fhere >r
                                        %tlabel         \ add label to syms
                                        r> >count incr
                                then
                        then
                then    false done?
        until   a; line-done ;

I: _TCODE       ( a1 f1 -- )           \ a target CODE word
                on> ?tcoding
                0=                     \ if not already defined
                if      drop                    \ cleanup stack
                        fhere >r
                        >in-t !> >in
                        do_symbol
                else    ?redefined              \ check for redefiniton
                        dup>r
                        res_symbol
                        {S} r@ >dtype c!        \ function type is subroutine
                        r@ >name dup yc@ $BF and swap yc!
                                                \ clear any immediate flag
                then    ['] no_tinline >body @ r@ >execute >body !
                                                \ no target inline allowed
                                                \ relink to error routine
                @> interpret !> interpsave
                ['] tinterp is interpret
                tcode-start
                                        \ above we mark this
                                        \ header as "LAST" wheather it makes
                                        \ a new header, or uses one that is
                                        \ already defined as in a forward
                                        \ reference resolution.
                r> cdoes> body> >resaddr @ ;

I: TCODE        ( | <name> -- )         \ a target CODE word
                tdefined _TCODE ;

I: TEND-CODE    ( -- )                  \ finish a target code definition
                ?tcoding 0= abort" Code words must start with CODE or LABEL"
                [assembler]
                END-ASMSTUFF
                ARUNSAVE IS RUN
                PREVIOUS A;
                [forth]
                off> ?tcoding
                interpsave ?dup if !> interpret then ;

I: _TLABEL      ( a1 f1 -- )         \ Define a new code label
                ?tcoding 0=          \ if not in a code word, then use CODE
                if      _TCODE exit
                then    0=
                if      >in-t =: >in            \ reset >IN
                        fhere >r
                        save> context
                        {S}  new_symbol
                        restore> context
                        here-t ,
                        -1 ,                    \ clear dummy unresolved chain
                        0 ,                     \ clear reference counter
                        0 ,                     \ data size is 0
                        +lab# dup ,             \ save the label number
                                                \ in ">DINITIAL" field
                        [assembler]
                        $:                      \ define a local label
                        [compiler]
                else    ?redefined              \ check for redefiniton
                        dup>r
                        here-t over >resaddr !  \ resolve to HERE
                                                \ word was already defined,
                        dup >dinitial @
                        true save!> ?long       \ backward branch is allowed
                                                \ to be long is $E9 type JMP
                        [assembler]
                        $:                      \ else resolve local label
                        [compiler]
                        restore> ?long
                then    out_symbol              \ display the symbol
                r> cdoes>   body>
                        dup >count incr         \ bump usage
                            >dinitial @
                        [assembler]
                        $                       \ reference local label
                        [compiler] ;

I: TLABEL       ( | <name> -- )      \ Define a new code label
                tdefined _TLABEL ;

ASSEMBLER
DEFER DB,       ' OC, IS DB,
DEFER DW,       ' O,  IS DW,
COMPILER

I: COFFSET_8,   ( a1 -- )
                dup $00 $FF between 0=
                if      0 "  BYTE out of range" "errmsg
                then
                [assembler]
                here 3 asm!lref                         \ res type 3
                db, ;                                   \ 8bit OFFSET

I: COFFSET_16,  ( a1 -- )
                [assembler]
                here 4 asm!lref                         \ res type 4
                dw, ;                                   \ 16bit OFFSET

I: 16MIF        ( a1 -- )               \ for DW and DB in CODE space
                C@
                IF      [assembler]
                        COFFSET_16,
                        [forth]
                ELSE    [assembler]
                        COFFSET_8,
                        [forth]
                THEN    [assembler]
                RESET   ;

I: H:16MI       ( f1 -<name>- )
                save> current
                host definitions current @ lastcurrent !
                CREATE
                restore> current
                C,
                [assembler]
                DOES> ['] 16MIF ISETUP! TINTERP ;

$00 H:16MI DB
$01 H:16MI DW

\ **********************************************************************
\ A function defining words, allows specification of a symbol to an
\ exact known address.
\ **********************************************************************

H: FEQUATE      ( n1 | <name> -- )      \ Literal Data
                >r
                {S}  new_symbol
                compile unnest          \ undefined, so NOOP it
                -1 ,                    \ mark as unresolved
                -1 ,                    \ clear dummy unresolved chain
                0 ,                     \ clear reference counter
                0 ,                     \ size zero
                r> ,                    \ save addr in dinitial field
                does>   body>
                        dup >resaddr @ -1 =
                        if      dup >dinitial @         \ get resolution addr
                               over >resaddr !          \ resolve symbol
                                dup out_symbol
                        then    dup >count incr         \ bump usage
                                    >resaddr @ ;

\ **********************************************************************
\ Immediately compile either the CODE word or the MACRO being defined
\ after these words ICODE, or IMACRO. If the CODE word or MACRO being
\ defined contains no references to external symbols, then we can compile
\ the function now and simply move the compiled code into the target when
\ it is referenced rather than waiting until it is referenced and then
\ compiling it into the target. Use of these words makes the target
\ compiler somewhat faster and smaller. Again, the ICODE and IMACRO words
\ MUST CONTAIN ONLY STRAIGHT ASSEMBLY, WITH NO EXTERNAL REFERENCES!!

\ NOTE#1: The sequence "$FAEB fhere 5 - !" below is a short jump from the
\       second CFA of the ICODE and IMACRO words to the first CFA of the
\       ICODE and IMACRO words. In a normal CODE or MACRO word the second
\       CFA is executed to compile the function into the target. In these
\       words the first CFA needs to be executed to move the functions
\       object code into the target. Thus the jump is needed for proper
\       operation of the function.

I: ?_IMM        ( cfa -- f1 )           \ return true if ICODE or IMACRO
                >execute @ $FAEB = ;

' LCODE         ALIAS ICODE
' END-LCODE     ALIAS END-ICODE  IMMEDIATE
' LMACRO        ALIAS IMACRO
' END-LCODE     ALIAS END-IMACRO IMMEDIATE

\ ***************************************************************************
\ Data type definitions.

I: LARRAY       ( n1 | <name> -- )      \ An array of data in the library
                {D}  new_symbol
                -1 ,                    \ mark as unresolved symbol
                -1 ,                    \ clear unresolved chain
                0 ,                     \ clear referenced counter
                  ,                     \ save array size word
                file_data,              \ option to add file source info
                does>   body>
                        ?dresolve               \ resolve it if used
                        dup >count incr         \ bump usage
                            >resaddr @ ;        \ return address in DS:

I: TARRAY       ( n1 | <name> -- )      \ An array of data in target
                fhere >r
                {D}  new_symbol
                here-d ,                \ mark as resolved symbol
                -1 ,                    \ clear unresolved chain
                0 ,                     \ clear reference counter
                dup , allot-d           \ data size of a variable
                r> index_constant       \ include in sym tbl
                does>   body>
                        dup >count incr         \ bump usage
                            >resaddr @ ;        \ return address in DS:

I: LVARIABLE    ( | <name> -- )         \ Variable Data
                2 larray ;

I: L2VARIABLE   ( | <name> -- )         \ Variable Data
                4 larray ;

I: TVARIABLE    ( | <name> -- )         \ Variable Data
                2 tarray ;

I: T2VARIABLE   ( | <name> -- )         \ Double Variable Data
                4 tarray ;

DEFER DO_DEFINING                       \ rewind and do a defining word

H: CREATE       ( | <name> -- )         \ a data pointer to HERE-D
                state @                         \ if used in ":" definition
                if      do_defining             \ switch to defining word
                else    0 tarray                \ else just an array
                then    ; immediate

H: HANDLE       ( | <name> -- )         \ An array for a handle data struct
                b/hcb larray ;

host definitions
' T2VARIABLE alias FVARIABLE            \ a floating var is like a double var
compiler definitions

I: LVALUE       ( n1 | <name> -- )      \ variable constant
                {V}  new_symbol
                -1 ,                    \ mark as unresolved symbol
                -1 ,                    \ clear unresolved chain
                0 ,                     \ clear reference counter
                2 ,                     \ data size of a value
                ,                       \ place to hold initial value
                0 ,                     \ 0 = haven't initialized it yet
                does>   body>
                        ?dresolve               \ resolve it if used
                        dup >count incr         \ bump usage
                        dup >inited @ 0=        \ if not initialized
                        if      dup  >dinitial @        \ get initial value
                                over >resaddr @ !-d     \ set it in target
                                dup >inited on          \ mark initialized
                        then
                            >resaddr @ @-d ;    \ return contents of
                                                \ address in target DS:

I: TVALUE       ( n1 | <name> -- )      \ variable constant
                1 ?enough
                fhere >r
                {V}  new_symbol
                >in_word @ !> asm->in   \ align ASM and WORD >IN values
                here-d ,                \ mark as unresolved symbol
                -1 ,                    \ clear unresolved chain
                0 ,                     \ clear reference counter
                2 ,                     \ data size of a value
                dup , ,-d               \ place to hold initial value
                -1 ,                    \ -1 = have already initialized it
                r> index_constant
                does>   body>
                        dup >count incr         \ bump usage
                            >resaddr @ @-d ;    \ return contents of
                                                \ address in target DS:

H: DEFER        ( n1 | <name> -- )      \ a defered word
                {E}  new_symbol
                -1 ,                    \ mark as unresolved symbol
                -1 ,                    \ clear unresolved chain
                0 ,                     \ clear reference counter
                2 ,                     \ data size of a defered word
                file_data,              \ option to add file source info
                does>   drop
                0 " Can't use target DEFERed words in interpret mode!"
                "errmsg abort ;

H: CONSTANT     ( n1 | <name> -- )      \ Literal Data
                1 ?enough
                fhere >r
                {C}  new_symbol
                  ,                     \ save constant word value
                -1 ,                    \ clear dummy unresolved chain
                0 ,                     \ clear reference counter
                0 ,                     \ clear dummy data length
                0 ,                     \ clear data initial value
                r> ?target
                if      dup index_constant
                then    drop
                does>   body>
                        dup  >count @ 0=                \ if not included
                        if      dup index_constant      \ include in sym tbl
                        then
                        dup >count incr         \ bump usage
                            >resaddr @ ;        \ return actual value

H: 2CONSTANT    ( d1 | <name> -- )      \ Literal double Data
                2 ?enough
                fhere >r
                {2C} new_symbol
                swap ,                  \ save constant word value LOW
                -1 ,                    \ clear dummy unresolved chain
                0 ,                     \ clear reference counter
                0 ,                     \ clear dummy data length
                  ,                     \ save const value HIGH in >DINITIAL
                r> ?target
                if      dup index_constant
                then    drop
                does>   body>
                        dup  >count @ 0=                \ if not included
                        if      dup index_constant      \ include in sym tbl
                        then
                        dup  >count incr        \ bump usage
                        dup  >resaddr  @
                        swap >dinitial @ ;      \ return actual double value

forth
defer float_pop

H: FCONSTANT    ( d1 | <name> -- )      \ floating point constant
                fhere >r
                {F} new_symbol
                float_pop
                  ,                     \ save constant value
                -1 ,                    \ clear dummy unresolved chain
                0 ,                     \ clear reference counter
                0 ,                     \ clear dummy data length
                  ,                     \ save const value LOW in >DINITIAL
                r> index_constant       \ add constant & type to symbol file
                does>   drop
                0 " Can't use floating constants in interpret mode!"
                "errmsg abort ;

host definitions
' FCONSTANT ALIAS FCON
compiler definitions

\ ***************************************************************************
\ Allow definition of a table of data in the target or library, used as
\ follows:
\
\       TABLE NUMBERS
\               0 C,    1 C,    2 C,    3 C,    4 C,
\               5 C,    6 C,    7 C,    8 C,    9 C,
\       END-TABLE
\
\ When "NUMBERS" is first referenced in the target, the table will be
\ moved into the target data space, and the data address of "NUMBERS"
\ will be compiled into the target. Later references simply compile the
\ address of the table.
\ ***************************************************************************

H: TABLE        ( | <name> -- a1 )      \ Define a Table of data
                {T}  new_symbol
                -1 ,                    \ mark as unresolved symbol
                -1 ,                    \ clear unresolved chain
                0 ,                     \ clear reference counter
                fhere 0 ,               \ leaves here on stack for use
                                        \ two lines down
                forth                   \ select the FORTH vocabulary
                file_data,              \ option to add file source info
                fhere swap !            \ link above to here
                fhere 0 ,               \ leave here for use by END-TABLE
                does>   body>
                        ?tresolve               \ resolve table when used
                        dup >count incr         \ bump usage
                            >resaddr @ ;        \ return address in DS:

H: END-TABLE    ( a1 -- )               \ complete the definition of a table
                fhere over - 2- swap !  \ store length in table header
                target ;                \ reselect target vocabulary

\ ***************************************************************************
\ This word is used to follow target library definitions that need to have
\ an interpret time function.
\ See the 11/25/89 note in TCOM.TXT for a usage example.

H: EXECUTES>    ( | <name> -- )         \ make word do name
                LAST @ NAME> DUP ?_IMM
                if      "  Is an ICODE/IMACRO word, can't use EXECUTES>"
                        "errmsg
                        also forth ' drop previous beep exit
                then    dup 1+
                fhere over - 2- swap !  \ make it jump to new function
                233 SWAP C!             \ change CALL to JMP
                ?TARGETING >R
                SETASSEM
                >FORTH-MEM              \ set to assemble for FORTH memory
                [ASSEMBLER]
                MOV AX, # ALSO FORTH ' PREVIOUS \ lookup word following
                JMP AX
                END-CODE
                [FORTH]
                R>              \ if we were targeting, back to TARGET
                IF      >TARGET-MEM
                THEN    ;

\ ***************************************************************************
\ This word NO-INTERPRET is used to prevent some target words from being used
\ while in interpret mode.

I: %NO-INTERP2  ( a1 -- )       \ error abort if we try to interpret
                                \ the word defined preceeding NO-INTERPRET
                body>
                " Can't use this TARGET word in INTERPRET mode!" "errmsg
                abort ;

CODE %NO-INTERP ( -- )          \ get here from a CALL
                MOV AX, # ' %NO-INTERP2
                JMP AX          END-CODE

H: NO-INTERPRET ( -- )
                last @ name> dup ?_imm
                abort" is an ICODE/IMACRO word, can't use NO-INTERPRET"
                1+ ['] %NO-INTERP OVER - 2- SWAP ! ; \ go to %NO-INTERP

\ ***************************************************************************

: TASCII        ( | <letter> -- )       \ compile inline an ascii letter
                ( | <letter> -- c1 )    \ interpret time
                bl word 1+ c@ state @
                if      comp_single
                then    ; immediate

I: %%T,"        ( | string" -- )        \ compile string data
                '"' word dup c@ 1+ s,-d ;

H: ,"-T         ( | string" -- )        \ compile string data to CODE space
                '"' word dup c@ 1+ s,-T ;

H: ,line"-T     ( | string" -- )        \ compile string data to CODE space
                                        \ appended with a CRLF
                '"' word count s,-T $0A0D ,-t ;

host definitions forth
DEFER ,"        COMPILER ' %%T,"   IS ,"
compiler definitions

\ ***************************************************************************
\ Display the target words that have been referenced, along with their
\ resolution addresses or values

forth
DEFER ?.onesym
compiler

I: out_unres    ( a1 -- )       \ write unresolved symbol to symbol file
                 dup>r >dtype c@                \ get current type
                255 r@ >dtype c!                \ change type to 255
                    r@ out_symbol               \ write the symbol
                    r> >dtype c! ;              \ restore original type

I: .unsym       ( cfa -- cfa )
                dup >resaddr @ -1 =
                if      \ not MACRO, CONSTANT or 2CONSTANT
                        dup >dtype c@ {M} {F} between 0=
                        if
                                save> loadline
                                save> lfile
\+ yseg                         dup >view y@ loadline !
\+ head@                        dup >name N>VIEW@ loadline !
                                dup >srcfile @ !> lfile
                                dup out_unres
                                dup " is Unresolved" "errmsg
                                restore> lfile
                                restore> loadline
\+ totalwords                   totalwords incr
                                #unres 1+ =: #unres
                        then
                then    ;

I: cfa.name     ( cfa -- cfa )
                dup  >resaddr @ -1 =
                if      dup >dtype c@ {M} {F} between 0=
                        if      ."  \2UNRES"
                        else    dup >dtype c@ {M} =
                                if      ." \1 MACRO"
                                else    dup >resaddr @
                                        hex  5 u.r SPACE
                                then
                        then
                else    dup >resaddr @ hex  5 u.r SPACE
                then    dup >dtype c@ {D}  =
                if ." \1v"  else space then
\+ totalwords   totalwords incr
                dup >name .id tab ?cr ;

I: cfa.count    ( cfa -- cfa )
                dup  >resaddr @ -1 <>
                over >dtype c@ {S} = and
                if      dup >count @ hex  5 u.r 2 spaces
                        dup >name .id tab ?cr
\+ totalwords           totalwords incr
                then    ;

I: .onesym      ( nfa-seg -- )
\+ yseg         dup link> dup >execute @rel>abs 'docol =
\+ headseg      dup name> dup >execute @rel>abs 'docol =
                if      dup >count @
                        if      save> base
                                ?.onesym
                                restore> base
                        then
                then    2drop   ;

I: %.labels     ( -- )
\+ totalwords   totalwords off
                0 =: #unres
                savestate
                cols 10 - rmargin !
                20 tabsize !
                0  lmargin !
                ['] target >body
                fhere 500 + #threads 2* cmove    \ copy threads
                cr
                begin   fhere 500 + #threads
                        largest dup             \ search thread copy
                        ?bye 0=
                        if      ?keypause
                        then
                while   dup .onesym
\+ head@                N>LINK@ swap !       \ insert last link to thread
\+ y@                   y@ swap !
                repeat 2drop
                decimal
                restorestate ;

: .labels       ( -- )
                cr cr ." Referenced words ----- "
                cr
                ['] cfa.name is ?.onesym
                %.labels
\+ totalwords   cr totalwords @ . ." Words Referenced"
                cr cr ;

' .labels alias .symbols

: .counts       ( -- )
                cr cr ." Referenced function use counts ----- "
                cr
                ['] cfa.count is ?.onesym
                %.labels
\+ totalwords   cr totalwords @ . ." Functions Referenced"
                cr cr ;

: .unres        ( -- )
                atsave 2@ at
                ['] .unsym is ?.onesym
                %.labels
                cr at? atsave 2! ;

\ ***************************************************************************
\ Compile the definition of " for inline strings in target and library

I: %%T$"        ( a1 -- )               \ compile string into target
                here-d comp_single      \ address of count of $
                dup c@ 1+ s,-d ;        \ compile string to data area

I: %%T"         ( a1 -- )               \ compile string into target
                %%T$" comp_count  ;     \ & compile a call to count

FORTH
DEFER %T"       ' %%T"  IS %T"
DEFER %T$"      ' %%T$" IS %T$"

I: T"           ( | string" -- )        \ compile a string into target
                ( -- a1 n1 )            \ runtime - return address and length
                '"' word                \ get the string to HERE
                %T" ; immediate         \ compile it into target

I: L"           ( | string" -- )        \ compile a string later compiled
                                        \ into the target
                [compile] " compile ">$
                compile %T" ; immediate

H: T$"          ( | string" -- )        \ compile a string into target
                ( -- a1 )               \ runtime - returns COUNTED string
                '"' word                \ get the string to HERE
                %T$" ; immediate        \ compile it into target

I: L$"          ( | string" -- )        \ compile a string later compiled
                                        \ into the target
                [compile] " compile ">$
                compile %T$" ; immediate

I: T'err        ( a1 -- )
                " ' cannot look-up a forward referenced word!" "errmsg ;

I: T'           ( | name -- a1 )        \ return the target adress of "name".
                defined
                if      dup >dtype c@ {S} <>
                        if      dup >dtype c@ {D} {T} between 0=
                                                        \ return data addr
                                if      " Can't tick MACROS or CONSTANTS"
                                        "errmsg 0       \ return a null
                                else    ?dresolve >resaddr @
                                then                    \ return targ addr
                        else    dup >resaddr @ dup -1 = \ return func addr
                                if      over T'err
                                then    nip
                        then
                else    drop 0 T'err 0
                then    ;

\ ***************************************************************************
\ Define and compile the target definition of a colon word. Automatic
\ forward reference resolution is performed on these definitions.

FORTH
DEFER END-T:    ( -- )          \ See the library for this definition

I: T;           ( --- )                 \ Finish-up :(colon) compiling
                state @ 0=
                if      0 " Not Compiling!" "errmsg
                then    ?tcomcsp  ?brcheck
                ?lib
                IF      compile %restore>
                        compile state
                        END-L; off> ?lib
                ELSE    END-T:
                THEN    [compile] [ ido_resolve ; immediate
                                        \ resolve all new referenced symbols

I: (T:)         ( | <name> .. ; -- )    \ new defining word
                ?exec
                off> ?lib
                !csp
                current @ context !
                tdefined 0=                     \ if not already defined
                if      drop                    \ cleanup stack
                        fhere >r
                        >in-t !> >in
                        do_symbol
                else    ?redefined              \ check for redefiniton
                        dup>r res_symbol
                        {S} r@ >dtype c!        \ function type is subroutine
                        r@ >name dup yc@ $BF and swap yc!
                                                \ clear any immediate flag
                then    ['] no_tinline >body @ r@ >execute >body !
                                                \ no target inline allowed
                                                \ relink to error routine
                set_cold_entry                  \ mark as program entry point
                start-t:
                [assembler]
                ( llab-init ) init_labels       \ 04/13/93 11:12 tjz
                                                \ LLAB-INIT was not resolving
                                                \ a forward reference from a
                                                \ code word  MAYBE???
                [compiler]
                r> cdoes> body> >resaddr @ ;    \ if used interpretively,
                                                \ returns resolution address
                                                \ 09/26/91 14:42:40.97 tjz

I: T]          ( -- )
                state on
        begin   ?stack  tdefined ?dup           \ find the word
                if      0>
                        if      execute         \ execute immediate words
                        else    targ_compile    \ compile the rest
                        then
                else    %number                 \ a number?
                        if      ( d1 -- )       \ compile literal number
                                double?         \ double if '.' found
                                if      swap
                                        comp_single
                                else    drop
                                then    comp_single
                        else    2drop           \ discard double zero
                                >in-t =: >in    \ reset >IN to before word
                                fhere >r
                                -1 add_symbol   \ or add to symbol table
                                compile unnest  \ undefined, so NOOP it
                                r@ >count incr
                                r> compile_call
                        then
                then    state @ 0=
        until   ?sizecheck ;            \ check the space used sofar

I: TL]          ( -- )          \ select compiler, target or library
                ?lib
                if      L]
                else    T]
                then    ;

I: TLITERAL     ( n1 -- )       \ compile a literal into the target
                comp_single ;

I: TLLITERAL    ( n1 -- )
                ?lib
                if      lliteral
                else    tliteral
                then    ;

2VARIABLE :_SAVE 6 ALLOT                \ a place to hold cur ":" information
                                        \ 8 bytes of storage

jumpbuf did_defining                    \ incase we encounter a defining word

I: TARG:        ( | <name> .. ; -- )    \ TARGET : defining word
                filepointer 2@
                outbuf c@ 0 d-  :_save 0 + 2!           \ save current info
                >in @           :_save 4 + !
                here-t          :_save 6 + !
                loadline @      :_save 8 + !
                did_defining setjmp 0=          \ if we didn't do a defining
                                                \ word then define this
                                                \ word as a target word
                if      (T:) T]
                then    ;

\ make some aliases for the normal Forth definitions of these words

assembler

' array     alias forarray
' variable  alias forvariable
' 2variable alias for2variable
' value     alias forvalue
' :         alias for:
' ;         alias for;          immediate
' ]         alias for]          immediate
' literal   alias forliteral    immediate
' allot     alias fallot
' code      alias fcode
' label     alias flabel
' end-code  alias fend-code
' ascii     alias fascii        immediate
' "         alias f"            immediate
' ."        alias f."           immediate
' abort"    alias fabort"       immediate
' [']       alias f[']          immediate
' '         alias f'
' goto      alias fgoto
FORTH       defer lgoto
            defer tgoto

forth

' ,        alias for,
' c,       alias forc,

\ new target compiler defered words

host definitions
FORTH defer array               ' forarray      compiler is array
FORTH defer variable            ' forvariable   compiler is variable
FORTH defer 2variable           ' for2variable  compiler is 2variable
FORTH defer value               ' forvalue      compiler is value
FORTH defer ,                   ' for,          compiler is ,
FORTH defer c,                  ' forc,         compiler is c,
FORTH defer :    immediate      ' for:          compiler is :
FORTH defer ;    immediate      ' for;          compiler is ;
FORTH defer ]    immediate      ' for]          compiler is ]
FORTH defer literal immediate   ' forliteral    compiler is literal
FORTH defer m:   immediate
FORTH defer goto immediate
defer allot
defer code       immediate
defer label      immediate
' t] alias t]
assembler definitions forth

defer end-code  immediate

host definitions FORTH

defer ascii     immediate
defer "         immediate
defer ."        immediate
defer abort"    immediate
defer [']       immediate
defer '

compiler definitions FORTH

defer l."       immediate
defer t."       immediate
defer labort"   immediate
defer tabort"   immediate
defer l[']      immediate
defer t[']      immediate

\ Compiler MODE selection words

H: >library     ( -- )                          \ Select Library
                on> ?library
                off> ?forth
                off> ?target
                F['] FOR,        =: ,
                F['] FORC,       =: C,
                F['] LARRAY      =: ARRAY
                F['] LVARIABLE   =: VARIABLE
                F['] L2VARIABLE  =: 2VARIABLE
                F['] LVALUE      =: VALUE
                F['] L:          =: :
                F['] L;          =: ;
                F['] L]          =: ]
                F['] LLITERAL    =: LITERAL
                F['] LM:         =: M:
                F['] LCODE       =: CODE
                F['] LLABEL      =: LABEL
  [assembler]   F['] END-LCODE   =: END-CODE    [compiler]
                F['] L"          =: "
                F['] L."         =: ."
                F['] LGOTO       =: GOTO
                F['] LABORT"     =: ABORT"
                F['] LALLOT      =: ALLOT
                F['] LASCII      =: ASCII
                F['] L[']        =: [']
                F['] F'          =: ' ;

H: >target      ( -- )                          \ Select Target compiler
                on> ?target
                ?libend!
                off> ?forth
                off> ?library
                F['] ,-D         =: ,
                F['] C,-D        =: C,
                F['] TARRAY      =: ARRAY
                F['] TVARIABLE   =: VARIABLE
                F['] T2VARIABLE  =: 2VARIABLE
                F['] TVALUE      =: VALUE
                F['] TARG:       =: :
                F['] T;          =: ;
                F['] TL]         =: ]
                F['] TLLITERAL   =: LITERAL
                F['] LM:         =: M:
                F['] TCODE       =: CODE
                F['] TLABEL      =: LABEL
  [assembler]   F['] TEND-CODE   =: END-CODE    [compiler]
                F['] T"          =: "
                F['] T."         =: ."
                F['] TGOTO       =: GOTO
                F['] TABORT"     =: ABORT"
                F['] ALLOT-D     =: ALLOT
                F['] TASCII      =: ASCII
                F['] T[']        =: [']
                F['] T'          =: ' ;

H: >forth       ( -- )                          \ select Forth
                on> ?forth
                ?libend!
                off> ?library
                off> ?target
                F['] FOR,         =: ,
                F['] FORC,        =: C,
                F['] FORARRAY     =: ARRAY
                F['] FORVARIABLE  =: VARIABLE
                F['] FOR2VARIABLE =: 2VARIABLE
                F['] FORVALUE     =: VALUE
                F['] FOR:         =: :
                F['] FOR;         =: ;
                F['] FOR]         =: ]
                F['] FORLITERAL   =: LITERAL
                F['] FOR:         =: M:
                F['] FCODE        =: CODE
                F['] FLABEL       =: LABEL
  [assembler]   F['] FEND-CODE    =: END-CODE    [compiler]
                F['] F"           =: "
                F['] F."          =: ."
                F['] FGOTO        =: GOTO
                F['] FABORT"      =: ABORT"
                F['] FALLOT       =: ALLOT
                F['] FASCII       =: ASCII
                F['] F[']         =: [']
                F['] F'           =: ' ;

>FORTH          \ Select FORTH for now

\ ***************************************************************************
\ Allow new user created defining words to be added and used in the target
\ compiler.

I: TDOES>       ( | -- )
                ?exec
                off> ?lib
                !csp
                current @ context !
                init_labels
                HERE-T =: DOES-ADDR
                STATE ON                        \ needed so COMP_STACK_LOAD
                                                \ will generate the proper
                                                \ index records
                COMP_STACK_LOAD                 \ save BX & recover AX
                T]  ;                           \ resolve all new symbols

H: ::           ( | <name> -- )         \ make a new defining word
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
                                        COMPILE STATE   \ signal to index gen
                                        COMPILE ON      \ to mark as : def
                                        COMPILE HERE-D
                                        COMPILE COMP_SINGLE_ALT
                                        HERE-T [COMPILE] LITERAL
                                        COMPILE COMP_JMP_IMM
                                                                 ENDOF
                        F['] DOES>  OF  COMPILE STATE
                                        COMPILE OFF
                                        [COMPILE] ; ?FNDDOES> ON ENDOF
                        F['] ,      OF  COMPILE ,-D              ENDOF
                        F['] C,     OF  COMPILE C,-D             ENDOF
                        F['] ALLOT  OF  COMPILE ALLOT-D          ENDOF
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

I: %DO_DEFINING ( -- )          \ switch to doing a defining word
                ibreset :_save 2@ seqhandle movepointer
                filltib expand_tib
                        :_save 4 + @ >in !
                        :_save 6 + @ dp-t !
                        :_save 8 + @ loadline !
                        :_save 2@ outbuf c@ 0 d+ filepointer 2!
                ::                              \ start from here and
                                                \ build a defining word
                did_defining longjmp ;          \ return waaa...y above

' %do_defining is do_defining

\ try to make a new label if the first word in the line ends in a colon (:)

: asm_label_make? ( -- )
                defined 0=
                >in off         \ backup to start of line
                off> >in-t
                if      count + 1- c@ ':' =         \ ends in ':'?
                        if      save> #tib      \ limit line to just before :
                                ?tcoding        \ reset vocabularies maybe?
                                if      [assembler]
                                        [compile] end-code
                                        [forth]
                                then
                                tib #tib @ 2dup ':' scan nip - nip #tib !
                                tlabel          \ try to make a label
                                restore> #tib   \ restore line length
                                incr> >in       \ bump past the colon (:)
                        then
                else    drop
                then    ;

\ ***************************************************************************
\ Do the target compile.

compiler definitions

: trun         ( -- )          \ target RUN word
                on> ?stack_check1
                depth >r
                expand_tib
                ?asm_labels             \ are we allowing assembler labels?
        if      asm_label_make?
        then    <run>
                depth r> <= ?exit       \ leave if stack depth is the same
                ?stack_check  0= ?exit
                ?stack_check1 0= ?exit
                0 " Warning, Stack Depth increased!" "warnmsg ;

: targ         ( -- )          \ initialize symbol file and .FIL file
                off> curfil#            \ reset files list numbers
                off> nextfil#
                ['] trun is run
                compload                \ compile the currently open file
                edo_resolve ;

false \+ words drop true        \ true if "WORDS" is defined
#IF

I: .compiler    ( -- )

cr ." /definit  = Include the default initialization from file DEFINIT.SEQ."
cr ." /noinit   = Don't include any default initialization, user does it."
cr ." /lst      = Generate a listing file with source, asm & symbols."
cr ." /opt      = Enable compiler optimization.                 (default)"
cr ." /show     = Show symbols as they are compiled."
cr ." /src      = Enable  the listing of source lines."
cr ." /stay     = Stay in Forth after the compile finishes."
cr ." /debug    = Generate data files for the BUG debugger."
cr ." /clean    = Perform a clean compile, no debug data files. (default)"
cr ." /quiet    = Reduce visual output, use with I/O redirection."
cr ." /bye      = Return to DOS ....... (NOT a command line option)."
cr ." /help     = Re-display help screen."
;

: /help         ( -- )
                cr ." Command line format:    "
                ." \`TCOM <filename> <option> <option> <...>\`"
                cr
                .alist
                .compiler
                cr ." \3 *** Type /BYE to leave the compiler *** " ;

#ELSE

: /help
        cr ." Command line format:    "
        ." \`TCOM <filename> <option> <option> <...>\`"
        cr ." Options avaliable:      "
        ." \`/opt /sym /lst /code /src /show\`"
        cr cr
        ." Type \`/BYE <enter>\` to return to DOS (don't include the \`s)."
        cr ;

#THEN

I: .public      ( -- )
                cr space
                ." \3 TCOM \0 the Target COMpiler by Tom Zimmer "
                ." \3 Version 2.50 " tversion
                cr space
                ." \1 *** All TCOM Compilers are Public Domain *** "
                eeol at? eeol at ;

I: ?.instruct   ( -- )
                [ also forth ]
                seqhandle >hndle @ 0<
                if      dark
                        .public
                        /help
                        false =: ?bye
                        forth
                        interpret
                        off> cerrors
                        nosave
                        cursor-on
                        QUIT        \ Just go back to Forth, no file given
                then    ;

I: ?cmd_err     ( a1 n1 f1 -- )
                [forth]
                if      >console                \ select the display
                        save> attrib
                        >norm space >attrib2
                        fhere count ." [ " type ."  ] " type
                        restore> attrib
                        cursor-on
                        incr> cerrors
                        ?bye                    \ leave if not in "/STAY"
                        if      RESTORE_VECTORS
                                BYEFUNC
                                cerrors #bye            \ *** LEAVE HERE ***
                        else    cr ."    Type \1 /BYE \0 to leave"
                                F['] <run> is run errfix
                                nosave
                                sp0 @ sp! forth quit
                        then
                else    2drop
                then    ;

: ?cmd_missing  ( f1 -- )
                "  Invalid command line option!" rot ?cmd_err ;

: c_err         ( a1 n1 -- )
                [forth]
                >console                        \ select the display
                atsave 2@ at
                0 -rot "errmsg cr               \ display err message
                cursor-on
                ?bye                            \ leave if not in "/STAY"
                if      /bye                    \ and leave
                else    F['] (?serror) is ?error
                                                \ reset ?ERROR to normal
                        nosave abort            \ and abort
                then    ;

I: ?compile_err ( a1 n1 f1 -- )
                [forth]
                if      c_err
                else    2drop
                then    ;

I: tdefault     ( -- )
                [forth]
                off> ?loaded,           \ disable LOADED, this time ONLY
                cfghndl $fload drop     \ we don't care if it exists
                on> ?loaded,            \ re-enable loaded,
                seqhandle clr-hcb dos-line c@ 0<>
                if      dos>tib                       \ move dosline to tib
                        bl word 1+ c@ '-' =           \ is - in place of file
                           here 1+ c@ '/' = or        \ or a parameter
                           here c@       0= or        \ or nothing
                        if      seqhandle clr-hcb     \ clear filename handle
                                here 1+ c@ '/' =
                                if      >in off       \ reset to line start
                                then
                        else    here $open_file
                        then    loadline off
                then    ;               \ skip whole thing if dosline is null

' tdefault is default

: DOTARG        ( -- )          \ perform the target compile
                [forth]
                sp0 @  'tib !           \ initialize Forth
                >in     off
                span    off
                #tib    off
                loading off
                only forth also definitions
                defaultstate            \ restore Forth's default state
                defaultattrib           \ set the default attributes to screen
                tcom_path@              \ get the environment specified path
                20 tabsize !            \ adjust the tab size
                warning off             \ no redef warnings
\+ autoeditoff  autoeditoff             \ no autoedit on error
                only                    \ setup TCOM's initial search order
                forth
                host      also
                forth     also
                compiler  also
                target    also  definitions
                ['] xheader is header   \ disallow NULL headers
                0compiler
                off> cerrors            \ reset the error counter
                cursor-off              \ turn off the screen cursor
                default                 \ open a file if one is present
                mypath@                 \ get the compilers path first, then
                +tcom_path              \ add it to the program search path
                tseg_init               \ Initialize target compile buffer
                ['] ?cmd_missing ['] ?missing switch_bodies     \ switch them
                F['] ?cmd_err save!> ?error     \ change error handler
                seqhandle >hndle @ 0>   \ ONLY if a file is open, do these
        if      on> ?stack_check        \ default to do stack checking
\ ***********************************************************************
\ ****** 04/18/94 18:09 tjz removed, as not really needed any more ******
\               env_interpret           \ get the default command line args
\ ***********************************************************************
                app_interpret           \ interpret .OPTION statement in app
        then    interpret               \ get the overridding args
                ['] ?cmd_missing ['] ?missing switch_bodies     \ restore err
                set.filenames           \ init file handle names
                ?errmake                \ create the error message file
                ?symmake                \ make symbol file if /SYM was used
                ['] %"errmsg is "errmsg \ link to error message handler
                restore> ?error         \ restore error handler
                .public                 \ display public domain message
                ?.instruct              \ and instructions if no file given
                ?quiet 0=                       \ if NOT quiet, then
                if      cr ."  Compiling: "     \ display a message
                        seqhandle >pathend" 2dup upper type
                        ?opt
                        if      ."  [Optimized]"
                        then    ."  "
                then
                ?show if cr then
                at? atsave 2!           \ init ATSAVE
                F['] ?compile_err save!> ?error
                [assembler]
                llab-init               \ initialize the local labels
                [forth]
\+ prof_start   prof_start
                fhere !> lib_top        \ initialize library top
                target-initialize       \ initialize the target compiler
                off> curfil#            \ reset files list numbers
                off> nextfil#
                ['] trun is run
\ **************************************************************************
\  Real work of compiling is done in the following word.  Everything else
\  is either compiler setup or cleanup.
\ **************************************************************************
                compload                \ compile the currently open file
\ **************************************************************************
                edo_resolve
                ?add_debug              \ add debug code if user specified
                -1 =: spinval spinner2  \ show spinner one final time
                end-cseg                \ end the code & data segments
                end-dseg
                target-finish           \ do target specific cleanup
                >console                \ reselect the display as output dev
\+ prof_finish  prof_finish
                atsave 2@ at
                ?cold_set 0=
                if      0 " AT LEAST ONE  ':'  COLON DEFINITION IS"     "errmsg
                        0 " REQUIRED TO SET THE PROGRAMS ENTRY POINT!"  "errmsg
                else    .unres          \ Display any unresolved references
                then    overlap_check   \ verify there are no overlapping segs
                ?sizecheck              \ make sure we aren't using too much
                check_stack
                symclose                \ close and flush the symbol file
                [compiler]
\+ merge-segs   merge-segs
                [forth]
                restore> ?error         \ restore normal error handling
                ?bye
                if      /bye            \ leave now or
                else    cr
." Type \`PRINT .SYMBOLS\` to make a printed copy of your programs SYMBOLS."
                        cr
." Type \`/BYE\` to leave."
                then
                cursor-on
                decimal
                forth also compiler also
                ?show_errors ;

' DOTARG IS BOOT                \ Make TARG the Initializer

\ ***************************************************************************
\ Some immediate words to handle values in the target

host definitions

1 ' noop        for>word &>
1 ' noop        for>word addrof>
2 ' comp_store  for>word !>
0 ' comp_fetch  for>word @>
0 ' comp_off    for>word off>
0 ' comp_on     for>word on>
0 ' comp_incr   for>word incr>
0 ' comp_decr   for>word decr>
0 ' comp_pstore for>word +!>
0 ' comp_save   for>word save>
0 ' comp_savest for>word save!>
0 ' comp_rest   for>word restore>


