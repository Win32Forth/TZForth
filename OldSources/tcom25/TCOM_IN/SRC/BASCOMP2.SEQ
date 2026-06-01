\ BASCOMP2.SEQ          A BASIC Code compiler for Forth      by Tom Zimmer

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
END-LCODE                               \ invoke once to allocate space

\ ***************************************************************************
\ Library and Target compiler functions. These words either compile actual
\ code into the target "TARG_COMPILE", or compiler functions into the library
\ "LIB_COMPILE" that will LATER compile code into the target.

I: LIB_COMPILE  ( a1 -- )
                dup >dtype c@   \ body contains TYPE byte
                case
( Macro )       {M}  of  >execute x,                            endof
( Constant )    {C}  of  compile res_comp_lit    x,             endof
\ ( 2Constant )  {2C}  of  compile res_comp_dbl    x,             endof
\ ( FConstant )   {F}  of  compile res_comp_fcn    x,             endof
( Data )        {D}  of  compile res_comp_lit    x,             endof
\ ( Value )       {V}  of  compile res_comp_val    x,             endof
( Subroutine )  {S}  of  compile res_comp_cll    x,             endof
\ ( dEfer )       {E}  of  compile res_comp_def    x,             endof
\ ( Table )       {T}  of  compile res_comp_tbl    x,             endof
                  ( elseof )
                        drop
                        " is NOT a target symbol! " "errmsg
                endcase ;

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
                        spinner                 \ something to watch
                repeat  skip'c' ?uppercase find ;

\ ***************************************************************************
\ Library COLON definitions. L: words are only included in the target
\ dictionary if they are referenced They are accessed with a CALL.
\ No forward references are allowed while creating Library definitions.
\ When L: words are later referenced, they are auto-resolving.

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
                then    ?csp END-L; off> ?lib [compile] [  ; immediate

I: L:           ( | <name> -- )
                ['] END-L: IS END-L;
                (L:) L] ; immediate

I: LM:          ( | <name> -- )
                ['] END-LM: IS END-L;
                fhere >r
                (LM:) L]
                {M} r> >dtype c! ;      \ data type is macro

compiler definitions

' ['] ALIAS F['] IMMEDIATE

DEFER DB,
DEFER DW,

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

' .labels   alias .symbols
' ;         alias for;          immediate

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

\ Compiler MODE selection words

H: >library     ( -- )                          \ Select Library
                on> ?library
                off> ?forth
                off> ?target ;

H: >target      ( -- )                          \ Select Target compiler
                on> ?target
                ?libend!
                off> ?forth
                off> ?library ;

H: >forth       ( -- )                          \ select Forth
                on> ?forth
                ?libend!
                off> ?library
                off> ?target ;

>FORTH          \ Select FORTH for now

\ ***************************************************************************
\ ***************************************************************************
\ Do the target compile.

compiler definitions

I: BASrun       ( -- )          \ target RUN word
                on> ?stack_check1
                depth >r
                brun
                depth r> <= ?exit  \ leave if stack depth is the same
                ?stack_check  0= ?exit
                ?stack_check1 0= ?exit
                0 " Warning, Stack Depth increased!" "errmsg
                incr> warnings                  \ add to warnings
                cerrors 1- 0max !> cerrors ;    \ not really an error

I: BAStarg      ( -- )          \ initialize symbol file and .FIL file
                off> curfil#            \ reset files list numbers
                off> nextfil#
                ['] BASrun is run
                true save!> state
                compload                \ compile the currently open file
                comp_ret                \ append a final return instruction
                %do_resolve             \ resolve forward references
                restore> state ;

: /help
        cr ." Command line format:    "
        ." \`TCOM <filename> <option> <option> <...>\`"
        cr ." Options avaliable:      "
        ." \`/opt /sym /lst /code /src /show\`"
        cr cr
        ." Type \`/BYE <enter>\` to return to DOS (don't include the \`s)."
        cr ;

I: .public      ( -- )
                cr space
                ." \3 TCOM \0 the Target COMpiler by Tom Zimmer "
                ." \3 Version 2.17 " tversion
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
                        quit
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

I: DOBASTARG    ( -- )          \ perform the target compile
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
                assembler also
                ['] xheader is header   \ disallow NULL headers
                off> cerrors            \ reset the error counter
                cursor-off              \ turn off the screen cursor
                default                 \ open a file if one is present
                tseg_init               \ Initialize target compile buffer
                ['] ?cmd_missing ['] ?missing switch_bodies     \ switch them
                F['] ?cmd_err save!> ?error     \ change error handler
                seqhandle >hndle @ 0>   \ ONLY if a file is open, do these
        if      /sym                    \ default to building an symbol table
                on> ?index              \ default to building an index  table
                on> ?stack_check        \ default to do stack checking
                env_interpret           \ get the default command line args
                app_interpret           \ interpret .OPTION statement in app
        then    interpret               \ get the overridding args
                ['] ?cmd_missing ['] ?missing switch_bodies     \ restore err
                mypath@                 \ get the compilers path
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
                target-initialize       \ initialize the target compiler
                BAStarg                 \ else compile source file
                ?add_debug              \ add debug code if user specified
                -1 =: spinval spinner2  \ show spinner one final time
                end-cseg                \ end the code & data segments
                end-dseg
                target-finish           \ do target specific cleanup
                >console                \ reselect the display as output dev
\+ prof_finish  prof_finish
                atsave 2@ at
                .unres                  \ Display any unresolved references
                overlap_check           \ verify there are no overlapping segs
                ?sizecheck              \ make sure we aren't using too much
                check_stack
                symclose                \ close and flush the symbol file
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

' DOBASTARG IS BOOT             \ Make TARG the Initializer


