\\ COMPILE1.SEQ          A true Code compiler for Forth      by Tom Zimmer

          An optimizing target compiler for the Public Domain Forth
        system F-PC by Tom Zimmer.

          Released to the Public Domain this date 10/11/89 by the
        author Tom Zimmer.

  **********************************************************************
                  LONGJMP was extracted from SETJMP.SEQ
  **********************************************************************
    Add "C"-like error exit to F-PC. If an error occurs that needs to
    abort up to a much higher execution level, this file provides a
    mechanism to do it without having to include a test at each level
    above the current level until the desired level is reached.
  **********************************************************************
{
File-echo on

: jumpbuf       ( | <name> -- )         \ allow defining a jump buffer
                create 0 , 0 , 0 , does> ;

: setjmp        ( a1 -- f1 )            \ a place to come back from "longjmp"
                rp@ over !              \ save current return stack ptr
                r@  over 2+ !           \ and contents of return stack
                sp@ 2+ over 4 + !       \ and current data stack ptr
                drop false ;            \ discard buffer and return false

: longjmp       ( a1 -- f1 )            \ jump back to after "setjmp"
                dup @ 0= abort" No `setjmp' performed!"
                dup>r 2+ @ r@ @ !       \ fix return stack to follow "setjmp"
                r@ 4 + @ sp!            \ fix data stack, as at "setjmp"
                r> @ rp! true ;         \ set return stack to "setjmp"
                                        \ and return true flag

: (TNUMBER?)    ( adr -- d flag )
                0 0  ROT  DUP 1+  C@  ASCII -  =  DUP  >R  -  DPL -1!
                BEGIN   CONVERT  DUP C@  '.' =
                WHILE   DPL 0!
                REPEAT  -ROT  R> IF  DNEGATE  THEN   ROT C@ BL =  ;

switch (number?) (tnumber?)

: >pathend      ( a1 --- a2 )   \ a2 = the address of the char beyond last \
                >pathend" drop ;

handle mypathhndl

: mypath@       ( -- )          \ read my path from DOS environment
                me@ me$ dup >pathend over 1+ - 1 /string mypathhndl place
                mypathhndl count + 1- c@ '\' <>         \ path ends in '\'
                if      " \" mypathhndl +place          \ no, then add it
                then    ;

: +tcom_path    ( -- )
                mypathhndl count "fpath+ ;

\ **********************************************************************
\ Re-select the console for output messages
\ **********************************************************************

0 value ?quiet
0 value err-key

: >console      ( -- )
                ?quiet
                if      ['] (typel) is typel
                else    [']  qtypel is typel
                then
                ['] (emit) is emit
                ['] (print) is pemit
                printing off ;

\ **********************************************************************
\ leave program, and return a DOS error number
\ **********************************************************************

code %#bye      ( n1 -- )       \ terminate to DOS with errorcode n1
                pop ax
                mov ah, # $4C
                int $21
                next            end-code

: #bye          ( n1 -- )       \ restore vectors, and terminate with err code
                >console
                cursor-on
                restore_vectors
                byefunc
                %#bye ;

\ ***************************************************************************
\ Automatic local label generator for assembler labels

only forth also definitions assembler also

llab-init                               \ make sure local label array
                                        \ is initialized before we change
                                        \ the initializer

$40 constant lab1#                      \ first local label number to use
lab1#  value lab#                       \ branch label depth

: 0lab#         ( -- )
                lab1# !> lab#
                labseg
                llab-start lab1# b/llab * +
                llab-size  lab1# b/llab * - -1 lfill ;

: +lab#         ( -- n1 )
                lab#
                incr> lab# ;

: init_labels   ( -- )  \ initializes temp labels ONLY, leave locals alone
                labseg llab-start lab1# 1- b/llab * -1 lfill ;

\ now setassem function clears only part of the local label array, rather
\ than clearing all of the local labels.  First "LAB1#" labels are local,
\ and the rest are global.  Global labels are assigned to names as they are
\ defined in the target.

: labdoassem    ( --- )
                @> run =: arunsave
                0 ['] drop a;!
                aprior 4 + 2@ aprior 2!
                lihere =: linestrt
                ll-global? 0=
                if      init_labels             \ in case labels used
                then
                also assembler ;

' labdoassem is setassem

only forth also definitions hidden also

\ **********************************************************************
\               Long and short branch and library control
\ **********************************************************************

  0 value ?lib          \ library active flag
  0 value ?allalong
  0 value ?long
  0 value ?long_lib
  0 value ?short        \ for those targets that have very short addressing

I: ?long_set    ( -- )
                ?allalong !> ?long
                off> ?short ;

: long_branch   ( -- )
                 on> ?long  on> ?allalong ;

: short_branch  ( -- )
                off> ?long off> ?allalong ;

: long_library  ( -- )
                on> ?long_lib ;

: short_library ( -- )
                off> ?long_lib ;

: [long]        ( -- )
                on> ?long ; immediate

: [Llong]       ( -- )
                ?lib 0= abort" Can only be used in a library!"
                compile [compile] [long] ; immediate

: [short]       ( -- )
                off> ?long
                on> ?short ; immediate

short_branch            \ default to short branches
short_library           \ also use short branches in library

\ ***************************************************************************
\ Buffered printing words to increase performance when creating a listing
\ ***************************************************************************

defer "errmsg

: temp"errmsg   ( a1 a2 n1 -- ) \ a temporary function incase of compile error
                rot drop                \ discard a1
                true (?serror) ;

' temp"errmsg is "errmsg                \ fill in for use while compiling

0 value ?lst                            \ true if we are in listing mode?
0 value ?compress

\ ***************************************************************************
\ Create some aliases to allow their use while in the compiler
\ ***************************************************************************

only forth root also definitions
forth also                              \ select ROOT for new definitions
                                        \ also search Forth
vocabulary host                         \ make a voc for a special list
host definitions                        \ of words available to target
                        ' host      alias [host]      immediate
                        ' forth     alias [forth]     immediate
                        ' assembler alias [assembler] immediate
vocabulary target       ' target    alias [target]    immediate
vocabulary htarget      ' htarget   alias [htarget]   immediate \ h = HIDDEN
vocabulary compiler     ' compiler  alias [compiler]  immediate

host     also
compiler also
forth definitions

variable lastcurrent            \ most recent value of CURRENT on HIDE

: ?TCOMCSP      ( -- )
                SP@ CSP @ <>
                if      0 " Stack Changed" "errmsg
                then    ;

: ;             ( -- )
                state @ 0=
                if      0 " Not Compiling!" "errmsg

                then
                ?tcomcsp   compile unnest
                lastcurrent @ ?dup
                if      save!> current
                        reveal
                        restore> current
                        lastcurrent off
                else    reveal
                then    [compile] [  ; immediate

: H:            ( | name -- )           \ make a word in host vocabulary
                save> current
                host definitions current @ lastcurrent !
                (:) ]
                restore> current ;

I: C:           ( | name -- )           \ make a word in compiler vocabulary
                save> current
                compiler definitions current @ lastcurrent !
                (:) ]
                restore> current ;

\ **********************************************************************
\ xHEADER is installed by DOTARG at compile startup time. It conflicts
\ with the use of HEADERS and HEADERLESS words at compile time.
\ **********************************************************************

I: xHEADER      ( | name -- )           \ make header warn about NULL names
                BL WORD dup c@ 0= abort" Attempt to create a NULL symbol"
                ?UPPERCASE "HEADER ;

\ ' xHEADER is HEADER                     \ link into defered HEADER word

compiler definitions

defer tversion  ' noop is tversion

         ' here alias fhere             \ make fhere an alias for HERE
\+ sys   ' sys  alias /dos
\- totalwords   variable totalwords

defer .alist         ' noop is .alist         \ default to no more help
defer line-done      ' noop is line-done      \ what to do at end of line
defer index_constant ' drop is index_constant \ add constant to symbol tbl
defer file_data,     ' noop is file_data,     \ option to compile source loc

\ In case no disassembler is present, discard the a1,n1 parameters

defer ?.#dis    ' 2drop is ?.#dis

\ ***************************************************************************
\ Target assembly and access words

$10000. 2constant codebytes             \ max target program is 64k bytes
$10000. 2constant databytes             \ max target data    is 64k bytes

        2variable atsave        at? atsave 2!

codebytes pointer seg-code              \ target origin code segment
databytes pointer seg-data              \ target origin data segment

$FFFF value code-begin                  \ lowest address where code is present
 $100 value code-start                  \ start of compiled code
 $000 value data-start                  \ start of compiled data
   variable dp-t code-start dp-t !      \ target dictionary pointer
   variable dp-d data-start dp-d !      \ target DATA dictionary pointer
$FFFF value ram-seg                     \ physical segment in target of ram
                                        \ $FFFF signifies whole system is
                                        \ ram based, and no move from ROM
                                        \ is needed at initialization time.
  $00 value target-origin               \ origin in memory for target code
  $00 value data-origin                 \ origin in memory for target data
$FFEE value rptop                       \ where we will initialize return stk
 $100 value rpsize                      \ return stack size in bytes
 $100 value spsize                      \ data stack size in bytes
    0 value >in-t                       \ a place to save >IN
 $103 value data-seg+                   \ Offset to the instruction that
                                        \ adjusts DS to where data really is.
    0 value cold_start                  \ Offset to CALL instruction to
                                        \ out cold entry point in application
    0 value final_exit                  \ address of where to leave
                                        \ application in initialization code
    0 value ?cold_set                   \ has COLD entry been set
    0 value ?unres                      \ unresolved flag
    0 value ?0opt1
    0 value ?opt
    0 value ?tail_opt
    0 value ?if_opt
    0 value ?code
    0 value ?show
    0 value ?definit
 true value ?bye
    0 value opt_limit
    0 value ?interpretive

: /code-start   ( | <addr> -- )         \ set target CODE starting address
                bl word number drop =: code-start ;

\ : /code-limit   ( | <addr> -- )         \ set max size of CODE compiled
\                 bl word number drop =: data-origin ;

: /data-start   ( | <addr> -- )         \ set target data starting address
                bl word number drop =: data-start ;

: /ram-start    ( | <addr> -- )         \ set the segment in target memory
                                        \ where ram really is, data is then
                                        \ moved into that ram from ROM
                bl word number drop =: ram-seg ;

: /ram-end      ( | <n1> -- )           \ set amount of available ram
                bl word number drop =: rptop ;

\ **********************************************************************
\ flag to specify wheather we want to save the users image file
\ **********************************************************************

0 value ?nosave

: nosave        ( -- )          \ we don't want to save image file
                on> ?nosave ;

: CtrlBreak     ( -- )
                FORTH
                nosave          \ no image save or listing creation
                TRUE ABORT" User aborted with Control Break" ;

' ctrlbreak is warmfunc                 \ link into warm break function

\ ***************************************************************************
\ A display word so user has something to watch while compiling
\ ***************************************************************************

I: vtype        ( a1 n1 -- )
                ?cs: -rot video-typeL ;

I: vspaces      ( n1 -- )
                ?cs: spcs rot video-typeL ;

I: vsp>col      ( n1 -- )
                #out @ - vspaces ;

I: vu.          ( u -- )
                (u.) vtype ;

I: vud.         ( ud -- )
                (ud.) vtype ;

I: vu.r         ( u l -- )
                >r (u.)  r> over - vspaces vtype ;

I: vud.r        ( ud l -- )
                >r (ud.) r> over - vspaces vtype ;

0 value spinval

I: spinner      ( -- )
                ?code
                ?show or ?quiet or ?exit
                incr> spinval
                spinval 1 and ?exit
                savecursor
                atsave 2@ swap 2+ swap at
                " |/-\" drop spinval 2/ 3 and + 1 vtype
                restcursor ;

h: spindata     ( -- )
                ?code
                ?show or ?quiet or ?exit
                incr> spinval
                spinval 63 and ?exit
                savecursor
                atsave 2@ swap 4 + swap at
                " |/-\" drop spinval 64 / 3 and + 1 vtype
                restcursor ;

\ **********************************************************************
\ a pointer to DOVAR, needed later
\ **********************************************************************

' DP-T @REL>ABS CONSTANT 'DOVAR         \ pointer to DOVAR

\ **********************************************************************
\ Target CODE space memory operators
\ **********************************************************************

0 value dp-tsave        \ save most recent DP-T for overflow check purposes
0 value ?overlimit      \ if over limit, issue message, and continue with
                        \ no more warnings about size problems

code savehighest_dp-t   ( -- )          \ save upper DP for limit testing
                mov     ax, dp-t                \ get current DP-T
                cmp     &> dp-tsave ax          \ if lessthan DP-TSAVE
        ju> 0 $ mov     &> dp-tsave ax          \ then DP-TSAVE=DP-T
        0 $:    next    end-code                \ else exit

: ?sizecheck    ( -- )
                dp-d @  0 databytes $100. d- d>
                if      0 " TOO MUCH STATIC DATA!" "errmsg
                        abort
                then
                savehighest_dp-t
                $FFFD dp-tsave u<       \ TOO much code?
                if      0 " TOO MUCH CODE!" "errmsg
                        abort
                then
                ?overlimit ?exit
                dp-t @  paragraph 16 um* dp-d @ 0 d+ codebytes d>
                if      0 " CODE and DATA bigger than 64k!" "errmsg
                        on> ?overlimit
                then    ;

\ ********* Words to allow dealing with flipped byte processors *********
\
\   Use HIGH-LOW in the OPTIMIZ file to select target memory operations
\ for a target processor that places the high byte of a word in the low
\ memory address.
\
\   Use LOW-HIGH in the optimize file to select target memory operations
\ for a target processor that places the low byte of a word in the low
\ memory address (like the 8086, which is the default).

\ 0 value ?swap
    defer ?swap-bytes
' noop is ?swap-bytes           \ default to no operation

: high-low      ( -- )          \ for a high byte in low memory processor
                ['] flip is ?swap-bytes
\                on> ?swap
                ;

' high-low alias /high-low

: low-high      ( -- )          \ for a low byte in low memory processor
                ['] noop is ?swap-bytes
\                off> ?swap
                ;

' low-high alias /low-high

0 value prev-call-addr          \ most recent call address
0 value curfil#_save            \ a place to save the current file number
0 value curfil#                 \ current file number during FLOAD
0 value nextfil#                \ next file number to assign to next FLOAD

defer c!-t      \ defered for flexibility with Mike Mayo's index compiler
defer !-t
defer c@-t
defer @-t
defer c,-t
defer ,-t
defer allot-t
defer s,-t
defer O!        \ other store, for resolving forward references to functions

: tcs:          ( taddr -- tseg taddr ) seg-code swap ;
: erase-t       ( a1 n1 --- )           >r tcs: r> 0 lfill ;
: there         ( taddr -- addr )       target-origin +   ;
I: %c@-t        ( taddr -- char )       there tcs: c@l ;
I: %@-t         ( taddr -- n )          there tcs: @l ?swap-bytes ;
I: %c!-t        ( char taddr -- )       there tcs: c!l ;
I: %!-t         ( n taddr -- )          swap ?swap-bytes swap there tcs: !l ;
: here-t        ( -- taddr )            dp-t @   ;
I: %allot-t     ( n -- )                dp-t +! savehighest_dp-t ;
I: %c,-t        ( char -- )             here-t %c!-t   1 %allot-t  ;
I: %,-t         ( n -- )                here-t  %!-t   2 %allot-t  ;
I: %s,-t        ( addr len -- )         0max 0 ?do count %c,-t loop drop ;
: cset-t        ( n1 addr -- )          dup c@-t rot or swap c!-t ;

' %c!-t    is c!-t         \ link defered functions to defered word
' %!-t     is !-t
' %c@-t    is c@-t
' %@-t     is @-t
' %c,-t    is c,-t
' %,-t     is ,-t
' %allot-t is allot-t
' %s,-t    is s,-t
' %!-t     is o!

I: %data-seg-fix ( -- )
                dp-d @ 3 < ?exit        \ only if there is any data used
                here-t paragraph 16 * dp-t !    \ paragraph align here
                data-seg+ @-t $E4F6 -           \ verify SYSINIT compiled
                                                \ and is NOT changed
                if      cr ." TARGET-INIT MUST be first in TARGET"
                        nosave 255 #bye
                then
                here-t paragraph                \ calc end of CODE used
                data-seg+ %!-t ;                \ set real DATA seg offset

defer data-seg-fix

' %data-seg-fix is data-seg-fix         \ install default function

\ ***************************************************************************
\ Target DATA space memory operators

: tds:          ( daddr -- dseg daddr ) seg-data swap ;
H: here-d       ( -- taddr )            dp-d @   ;
I: %allot-d     ( n -- )                dp-d +! ;
: dhere         ( taddr -- addr )       data-origin + ;
H: @-d          ( taddr -- n )          dhere tds: @l  ;
H: c@-d         ( taddr -- c1 )         dhere tds: c@l ;
H: count-d      ( taddr -- taddr+1 c1 ) dup 1+ swap c@-d ;
I: %c!-d        ( char taddr -- )       dhere tds: c!l ;
I: %!-d         ( n taddr -- )          dhere tds: !l  ;
I: %c,-d        ( char -- )             here-d %c!-d   1 %allot-d spindata ;
I: %,-d         ( n -- )                here-d  %!-d   2 %allot-d spindata ;
I: %s,-d        ( addr len -- )         0max 0 ?do count %c,-d loop drop ;

defer allot-d   ' %allot-d is allot-d
defer c!-d      ' %c!-d    is c!-d
defer !-d       ' %!-d     is !-d
defer c,-d      ' %c,-d    is c,-d
defer ,-d       ' %,-d     is ,-d
defer s,-d      ' %s,-d    is s,-d

H: even_align   ( -- )          \ even align data space
                here-d 1 and allot-d ;

H: odd_align    ( -- )          \ odd align data space
                here-d 1 xor 1 and allot-d ;

: dp-set        ( -- )          \ adjust target DP to next free data space
                here-d 0 !-d ;  \ DP is always at address zero (0) in target

target definitions
' here-t alias here             \ HERE is now a target word.
                                \ Use fhere for host if you need it.
compiler definitions assembler

0 value ?targeting

0 value ic,save         @> ic, is ic,save
0 value cc,save         @> cc, is cc,save

: >8086-MEM     ( -- )                  \ select 8086 type of
                                        \ memory operators
                ?targeting ?exit
                [ASSEMBLER]
                ic,save     is ic,
                cc,save     is cc,
                [']  %c,-t  is oc,
                [']   %,-t  is  o,
                [']   c,-t  is  c,
                [']    ,-t  is   ,
                [']   c@-t  is tc@
                [']  %c!-t  is tc!
                [']   %!-t  is t!
                ['] here-t  is here
                on> ?targeting ;

DEFER >TARGET-MEM       ' >8086-MEM IS >TARGET-MEM

: >FORTH-MEM    ( -- )
                ?targeting 0= ?exit
                [assembler] @> ic,            is ic,save
                [assembler] @> cc,            is cc,save
                [forth] [']    c, [assembler] is  ic,
                [forth] [']    c, [assembler] is  cc,
                [forth] [']    c, [assembler] is  oc,
                [forth] [']     , [assembler] is   o,
                [forth] [']    c, [assembler] is   c,
                [forth] [']     , [assembler] is    ,
                [forth] [']    c@ [assembler] is  tc@
                [forth] [']    c! [assembler] is  tc!
                [forth] [']     ! [assembler] is   t!
                [forth] ['] fhere [assembler] is here
                off> ?targeting ;

\ **********************************************************************
\ Second spinner, for use when defining library words, also shows code
\ and data size information
\ **********************************************************************

I: spinner2     ( -- )
                ?quiet ?show or ?exit
                incr> spinval
                spinval 1 and ?exit
                false save!> printing
                savecursor attrib @ >r
                atsave 2@ at
                " |/-\" drop spinval 2/ 3 and + 1 vtype
                spinval 7 and 0=
                if      atsave 2@ swap 6 + swap at
                        save> base decimal
                        42 vsp>col >attrib3 2 vspaces
                        here-t code-begin - dup 1  vu.r "  - Code, " vtype
                        here-d data-start - dup 1  vu.r "  - Data "  vtype
                        2drop
                        79 vsp>col
\ \+ yhere                $FFF0 yhere - ( 0max ) vu.
\ \+ headseg              #headsegs 3 - headseg @ - 16 um* vud.
                        47 #line @ 1- at >attrib3
                        "  Unused Symbols available: " vtype
                        sp@ pad 500 + - 0max 14 / vu.
                        79 vsp>col
                        restore> base
                then    r>drop restcursor
                restore> printing ;

\ **********************************************************************
\ Library flag and control words.
\ These words allow the symbol file generator to know which words are
\ coming from the library, rather than from the target application.
\ **********************************************************************

0 value lib_end         \ end of current library
0 value ?target
0 value ?forth
0 value ?library

: ?libend!      ( -- )          \ set the end of the current library
                ?library
                if      fhere !> lib_end
                then    ;

\ **********************************************************************
\ linkage words for a previously compiled modules symbols into the
\ current compile
\ **********************************************************************

0 value ?sym_inc                \ was a symbol file included?
0 value symorg                  \ End of code and data markers for the
0 value symvorg                 \ end of the precompiled module being
0 value symdorg

\ **********************************************************************
\ Target segment list creation and maintenance words for CODE & DATA

\  SEGMENTS array
\
\       +0            +2          +4            +6
\       nxt-code-ptr, curseg-ptr, nxt-data-ptr, curseg-ptr
\        \                         \
\         (points to)                (data chain same as code chain)
\                    \
\                      \ +0            +2          +4
\   (segment)->          nxt-code-ptr, start-code, end-code
\                          \
\                            \ +0            +2          +4
\   (segment)->                nxt-code-ptr, start-code, end-code
\                                \
\                                  \
\                                    0 (zero)
\
\ ***************************************************************************

create segments 8 allot         \ an array to hold the code and
       segments 8 erase         \ data segment pointer chain

64 array overlay$

    0 value ccseg                       \ current code segment
    0 value cdseg                       \ current data segment
    0 value here-top
    0 value here-top-save
    0 value code_total                  \ summ of code bytes compiled
    0 value data_total                  \ summ of data bytes compiled
$FF00 value rombytes

    defer segment_end                   \ hook for index record generator
' noop is segment_end
    defer segment_start                 \ hook for index record generator
' noop is segment_start

: #replace      ( a1 n1 a2 n2 a3 -- a1 n1 )
                true save!> caps
                save> base hex
                >r      2over search
                if      >r over r> +
                        r@ 0 <# # # # # #> rot swap cmove
                else    drop
                then    r>drop
                restore> base
                restore> caps ;

: ?org_overlap  ( a1 -- a1 )            \ check for segment overlap
                >r
                segments @
                begin   ?dup
                while   r@ over dup 2+ @ swap 4 + @ 1- between
                        if      >r 0
                                "  CODE segment at $zzzz overlaps $xxxx - $yyyy "
                                overlay$ place
                                overlay$ count
                                " zzzz" r> r@ swap >r 2+ @ #replace
                                " xxxx" r@ 2+  @ #replace
                                " yyyy" r@ 4 + @ #replace
                                "errmsg
                                r>
                        then    @
                repeat  r> ;

: ?vorg_overlap ( a1 -- a1 )            \ check for segment overlap
                >r
                segments 4 + @
                begin   ?dup
                while   r@ over dup 2+ @ swap 4 + @ 1- between
                        if      >r 0
                                "  DATA segment at $zzzz overlaps $xxxx - $yyyy "
                                overlay$ place
                                overlay$ count
                                " zzzz" r> r@ swap >r 2+ @ #replace
                                " xxxx" r@ 2+  @ #replace
                                " yyyy" r@ 4 + @ #replace
                                "errmsg
                                r>
                        then    @
                repeat  r> ;

: ?overlap      ( a1 -- a1 )         \ check for segment overlap
                dup 2+ 2@ - +!> code_total
                >r
                segments @
        begin   ?dup
        while   r@ over <>      \ only if not myself
                if r@ 2+ 2@ <>  \ and not an empty segment
                   if   r@ 2 + @    over 2+ 2@ swap 1- between
                        swap
                        r@ 4 + @ 1- over 2+ 2@ swap 1- between
                        rot or
                        if      >r 0
                                "  CODE segment at $zzzz overlaps $xxxx - $yyyy "
                                overlay$ place
                                overlay$ count
                                " zzzz" r> r@ swap >r 2+ @ #replace
                                " xxxx" r@ 2+  @ #replace
                                " yyyy" r@ 4 + @ #replace
                                "errmsg
                                r>
                        then
                   then
                then @
        repeat  r> ;

: ?voverlap     ( a1 -- a1 )         \ check for DATA segment overlap
                dup 2+ 2@ - +!> data_total
                >r
                segments 4 + @
        begin   ?dup
        while   r@ over <>      \ only if not myself
                if r@ 2+ 2@ <>  \ and not an empty segment
                   if   r@ 2 + @    over 2+ 2@ swap 1- between
                        swap
                        r@ 4 + @ 1- over 2+ 2@ swap 1- between
                        rot or
                        if      >r 0
                                "  DATA segment at $zzzz overlaps $xxxx - $yyyy "
                                overlay$ place
                                overlay$ count
                                " zzzz" r> r@ swap >r 2+ @ #replace
                                " xxxx" r@ 2+  @ #replace
                                " yyyy" r@ 4 + @ #replace
                                "errmsg
                                r>
                        then
                   then
                then @
        repeat  r> ;

: overlap_check ( -- )
                off> code_total
                off> data_total
                segments @
                begin   ?dup while   ?overlap @ repeat
                segments 4 + @
                begin   ?dup while  ?voverlap @ repeat  ;

host definitions

H: end-cseg      ( -- )
                segment_end                     \ mark end of previous
                segments 2+ @ ?dup              \ if prev seg not NULL
                if      here-t swap 4 + !       \ save end addr in struct
                        here-t here-top umax !> here-top
                then    ;

H: org          ( a1 -- )                       \ define a headerless segment
                end-cseg                        \ close previous segment
                ?org_overlap
                fhere segments @ ,              \ link previous to this seg
                dup   segments !                \ this seg into segment list
                      segments 2+ !             \ make this, current segment
( +2 )          dup ,                           \ start of segment
( +4 )          dup ,                           \ current address in segment
                dup dp-t !                      \ adjust code pointer
                savehighest_dp-t                \ limit DP-T
                dup !> linestrt                 \ no code yet compiled here
                code-begin umin !> code-begin
                segment_start ;

compiler definitions

: cseg!         ( seg -- )              \ set the current code segment
                end-cseg                        \ finish current segment
                dup segments 2+ !               \ link me into segments
                4 + @ dup dp-t !                \ set HERE-T to my segment
                !> linestrt                     \ no more code here yet
                segment_start ;

H: cseg          ( a1 | <name> -- )      \ create memory CODE segments words
                create  org
                does>   cseg! ;

H: dseg>         ( -- )                  \ return from the data segment
                ccseg cseg!
                here-top-save !> here-top ;

H: >dseg         ( -- )                  \ select the current data segment
                here-top !> here-top-save
                segments 2+ @ !> ccseg
                cdseg cseg! ;

I: %dorg        ( a1 -- )               \ create a data segment in code space
                end-cseg
                segments 2+ @ >r                \ save current code segment
                save> code-begin                \ save prev code lo limit
                dup org                         \ set the data origin
                data-start umin !> data-start
                restore> code-begin             \ restore previous lo limit
                segments 2+ @ !> cdseg          \ save current data segment
                           r> !> ccseg          \ reset saved code segment
                dseg> ;                         \ return to the code segment

I: %dseg        ( a1 | <name> -- )      \ create data code segment word
                create  %dorg
                does>   !> cdseg
                segment_start ;

H: end-vseg      ( -- )
                segments 6 + @ ?dup             \ if prev seg not NULL
                if      here-d swap 4 + !       \ save end addr in struct
                then    ;

H: vorg          ( a1 -- )
                end-vseg                        \ close prevous segment
                ?vorg_overlap
                fhere segments 4 + @ ,          \ link previous to this seg
                dup   segments 4 + !            \ this seg into segment list
                      segments 6 + !            \ make this, current segment
( +2 )          dup ,                           \ start of segment
( +4 )          dup ,                           \ current address in segment
                dup dp-d !                      \ adjust data pointer
                data-start umin !> data-start ;

H: vseg          ( a1 | <name> -- )      \ create memory DATA segments words
                create  vorg
                does>   end-vseg
                        dup segments 6 + !      \ link me into segments
                        4 + @ dp-d ! ;          \ set HERE-T to my segment

host definitions
defer end-dseg  ' end-vseg is end-dseg
defer dorg      ' vorg     is dorg
defer dseg      ' vseg     is dseg

H: romsize      ( n1 -- )               \ set legal limit on code size
                0 save!> curfil#                \ index record must use 0
                dup !> rombytes
                $400 - $200 umax dorg
                restore> curfil# ;

compiler definitions

: /data_in_ram  ( -- )                  \ put data in with variables
                ['] end-vseg is end-dseg
                ['] vorg     is dorg
                ['] vseg     is dseg ;

: /data_in_rom  ( -- )                  \ put data in with code in rom
                                        \ but in its own place
                ['] end-cseg is end-dseg
                ['] %dorg    is dorg
                ['] %dseg    is dseg ;

: /data_in_code ( -- )                  \ put data in with the code in rom
                                        \ actually lay it inline with code
                ['] end-cseg is end-dseg
                ['] org      is dorg
                ['] cseg     is dseg ;

\ ***************************************************************************
\ Target image save function

handle targethndl

forth definitions

: NOTI          ( -- )
                nosave
                TRUE ABORT" No Target initialization function installed" ;

DEFER TARGET-INITIALIZE         ' NOTI IS TARGET-INITIALIZE
DEFER TARGET-FINISH             ' NOOP IS TARGET-FINISH

0 value #unres
0 value cerrors
0 value warnings
0 value does-addr
0 value ?cleaning

handle image.name
handle symbol.name      symbol.name off
handle listing.name
handle error.name
handle files.name
create image.ext  ," COM" 0 ,   \ default to .COM extension

: set.filenames ( -- )          \ set the filenames for various files
             seqhandle image.name   $>handle image.ext  image.name   $>ext
             seqhandle symbol.name  $>handle " SYM" ">$ symbol.name  $>ext
             seqhandle listing.name $>handle " LST" ">$ listing.name $>ext
             seqhandle files.name   $>handle " FIL" ">$ files.name   $>ext
             seqhandle error.name   $>handle " MSG" ">$ error.name   $>ext ;

I: ?cerrors     ( -- )
                atsave 2@ at space
                save> attrib
                cerrors
                if      ." \2 *********** " >attrib2 cerrors 3 u.r
                        ." \2 COMPILE ERRORS!  *********** "
                        >norm
                else    ." \3  !!-!!  NO COMPILE ERRORS  !!-!!  "
                then    restore> attrib
                warnings ?dup
                if      >attrib2 3 u.r ." \2 WARNINGS issued "
                        >norm
                then
                cerrors warnings or     \ if there were errors
                ?cleaning and           \ and cleaning is set
                if      cr
."  \2 ** You will need to recompile with the /DEBUG option before debugging ** "
                then
                cr at? atsave 2! ;

I: check_stack  ( -- )          \ verify stack is empty, or warn user
                depth >r sp0 @ sp!
                r> 0>
                if      0 " Compile left data on stack" "errmsg
                then    ;

I: %save-image.com ( | -- )
                [compiler]
                ?nosave ?exit
                atsave 2@ at
                image.name targethndl $>handle
                targethndl hcreate                      \ make image.com
                if      >console
                        cr ." Error while creating executable file."
                        255 #bye
                then
                cr ."  Created executable file - " targethndl count type
                data-seg-fix                    \ adjust HERE-T and fix
                                                \ DATA segment alignment
                dp-set                          \ set targets DP
                here-t here-top umax !> here-top        \ upper mem limit
                code-begin here-top over - dup>r
                targethndl seg-code exhwrite r> -       \ write CODE
                if      >console
                        cr ." Error while saving CODE to executable file."
                        255 #bye
                then
                cr ."  Wrote " here-top code-begin - 5 u.r ."  Bytes of CODE"
                here-d 2 u>             \ only if there is some data to write
        if      ."  rounded up to Paragraph."
                data-origin here-d
                targethndl seg-data exhwrite here-d -
                if      >console
                        ." Error while saving DATA to executable file."
                        255 #bye
                then
                cr ."  Wrote " here-d data-start - 5 u.r ."  Bytes of DATA, "
                here-d 0 here-top code-begin - 0 d+ 5 ud.r ."  Bytes total.
        then    targethndl hclose drop
                cr at? atsave 2! ;

DEFER SAVE-IMAGE.COM    ' %SAVE-IMAGE.COM IS SAVE-IMAGE.COM

: ?cleanup      ( -- )          \ cleanup extra files off disk
                ?cleaning                       \ we want a clean disk
                cerrors 0= and                  \ and there were no errors
                if      symbol.name  hdelete drop
                        listing.name hdelete drop
                        files.name   hdelete drop
                        warnings 0=
                        if      error.name   hdelete drop
                        then    " INX" ">$ error.name   $>ext
                        error.name   hdelete drop
                        " MSG" ">$ error.name   $>ext
                then    ;

compiler definitions

\ ***************************************************************************
\ Initialize the target compiler code space and link in the new target words
\ to the assembler.

: tseg_init     ( -- )          \ switch assembler to target space
\+ unedit       unedit                  \ release space used by editor
                seg-code 0=             \ allocate the space needed for
                                        \ the target compile process
                if      0 " Not enough memory for compile buffer"
                        "errmsg nosave abort
                then
                codebytes $10000. d< abort" 'CODEBYTES' must be 64k"
                seg-code     0 $8000 0 lfill
                seg-code $8000 $8000 0 lfill    \ Zero out 64k of code area
                databytes $10000. d< abort" 'DATABYTES' must be 64k"
                seg-data     0 $8000 0 lfill
                seg-data $8000 $8000 0 lfill    \ Zero out upto 64k of data
\+ dumpseg      seg-code =: dumpseg             \ preset dumpseg
                [assembler]                     \ assembler defered words
                global_ref ;                    \ use global references

\ ***************************************************************************
\ Mark the current CODE dictionary address as the current cold program
\ entry point.

0 value ?0init          \ are we doing ZERO initialization (ala very minimal)
0 value ?driver         \ is this a device driver
0 value ?custom
0 value ?asm_labels

I: %set_cold_entry      ( -- )          \ mark HERE-T as the cold entry point
                        ?0init ?exit
                        here-t cold_start - 2-
                        cold_start !-t ;

: SET_COLD_ENTRY ( -- )                 \ A defered word with extra stuff
                                        \ to do in addition to the defered
                                        \ function.
                DOES>   ?0INIT 0=               \ only perform if we aren't
                        IF      PERFORM         \ using /0INIT
                        ELSE    DROP            \ else discard address
                        THEN    ON> ?COLD_SET ;

SET_COLD_ENTRY                          \ execute once to allocate space

' %SET_COLD_ENTRY IS SET_COLD_ENTRY


\ ***************************************************************************
\ Automatic local label variable generator for assembler macros

128 constant br#1
192 constant br#last
br#1 value br#val        \ branch label depth

H: 0br#          ( -- )
                br#1 !> br#val ;

H: +br#          ( -- n1 )
                br#val
                incr> br#val
                br#val br#last =
                if      0 " Exceeded allocated local branch labels" "errmsg
                        abort
                then    ;

H: -br#          ( -- n1 )
                decr> br#val
                br#val dup br#1 <
                if      drop
                        0 " Illegal attempt to resolve an branch label"
                        "errmsg
                        0br# br#val
                then    ;

H: br#           ( -- )
                br#val 1- br#1 max ;

I: ?brcheck     ( -- )
                br#val br#1 >
                if      [assembler]
                        br#val #ll-errs?  \ verify local labels resolved
                        [compiler]
                then    ;

\ ***************************************************************************
\ Compiler control words

variable ?fnddoes>              \ does CREATE DOES> have a DOES> portion?

: /opt          ( -- )          \ enable optimization for this compile
                on> ?opt
\               on> ?tail_opt           \ enable tail optimization also
                on> ?0opt1 ;

: /optoff       ( -- )          \ disable optimization for this compile,
                                \ this is the default mode
                off> ?opt
                off> ?0opt1 ;

' /optoff alias /noopt

: /notailopt    ( -- )          \ disable tail optimization
                off> ?tail_opt ;

' /notailopt alias /tailoptoff
' /notailopt alias /tail-

: /tailopt      ( -- )          \ enable tail optimization
                on> ?tail_opt ;

' /tailopt alias /tailopton
' /tailopt alias /tail+

: .?opt         ( -- )
                cr >rev ." Status of ?OPT is " ?opt . >norm cr ;

/optoff

: opt_off1      ( -- )          \ turn off the optimizers for a while
                                \ after compiling a branch destination
                off> ?opt
                here-t 1- =: opt_limit ;

: ?reopt        ( -- )          \ re-enable the optimizers if they were
                                \ turned off for a while
                ?0opt1 =: ?opt ;

: #?opt         ( n1 -- f1 )    \ check for OPT_LIMIT before "HERE-T - n1"
                here-t swap - opt_limit > ;

: /ifopt        ( -- )          \ optimize IF preceeded by conditional
                on> ?if_opt ;

/ifopt

: /ifoptoff     ( -- )          \ disable IF optimization
                off> ?if_opt ;

' /ifoptoff alias /noifopt

: /definit      ( -- )         \ include the TYPE & SPACES initialization
                                \ code in the compiled image file
                on> ?definit
                off> ?0init ;

: /definitoff     ( -- )          \ don't initialize TYPE and SPACES
                ?interpretive ?exit
                off> ?definit ;

' /definitoff alias /noinit

/definit

: /0init        ( -- )          \ absolute minimum init code, CAUTION!!!
                on> ?0init      \ minimal stacks only
                on> ?cold_set ; \ beginning of program is entry in 0init


I: driver-fix   ( -- )
                here-t paragraph 16 * dp-t !    \ paragraph align here
\               here-t paragraph                \ calc end of CODE used
\               data-seg+ %!-t                  \ set real DATA seg offset
                ;

: /driver       ( -- )          \ we are compiling a device driver
                on> ?driver
                on> ?0init
                on> ?cold_set   \ beginning of program is entry in 0init
                on> ?asm_labels
                ['] driver-fix is data-seg-fix
                " SYS" image.ext place ;

' /driver alias /device

: /asm_labels   ( -- )
                on> ?asm_labels ;

: /custom_init  ( -- )
                on> ?custom
                on> ?0init
                on> ?cold_set
                on> ?asm_labels ;

: /asm          ( -- )
                /custom_init ;

: check_/noinit ( -- )          \ verify the /NOINIT option is in effect
                ?definit
                if      0 " Need the /NOINIT option!" "errmsg
                then    ;

: check_/definit ( -- )         \ verify the /DEFINIT option is in effect
                ?definit 0=
                if      0 " Need the /DEFINIT option!" "errmsg
                then    ;

' showlines alias /src          \ this MUST be here so /LST can use it!
' hidelines alias /srcoff
' hidelines alias /nosrc

: /show         ( -- )          \ show the symbols on the screen as they
                                \ are compiled
                on> ?show ;

' /show alias /sho

: /showoff      ( -- )          \ don't show the symbols on the screen
                                \ as they are compiled. This is the default
                                \ mode.
                off> ?show ;

' /showoff alias /noshow

/showoff

: /quiet        ( -- )
                on> ?quiet
                slow
\+ statoff      statoff
                ;

' /quiet alias /q

: /key          ( -- )
                on> err-key ;

' /key alias /k

I: defaultattrib ( -- )         \ set the compilers screen attributes to
                                \ match the current screen attributes.
                video-seg @ at? 160 * swap 2* + 1+ c@L attrib ! ;

I: %noheadroom          ( -- )
\- adjust-#heads        true abort" Symbol space exausted!" ;
\+ adjust-#heads        adjust-#heads abort" Symbol space exausted" ;

switch noheadroom %noheadroom

I: %nolistroom          ( -- )
\- adjust-#lists        true abort" Library space exausted!" ;
\+ adjust-#lists        adjust-#lists abort" Library space exausted" ;

switch nolistroom %nolistroom

I: %?missing    ( f -- )        \ new version of ?MISSING
                if      loading @ 0=
                        if      space here count type
                        then
                        true abort"  is an Undefined symbol!"
                then    ;

switch ?missing %?missing       \ exchange the bodies

defer release_memory    ' noop is release_memory

defer ?show_errors      ' noop is ?show_errors

defer make_listing      ' noop is make_listing

defer compress.com      ' noop is compress.com

: ?make_listing ( -- )          \ build a listing file of compile
                ?nosave ?exit
                listing.name hdelete drop       \ first delete listing file
                ?lst
                if      make_listing
                then    ;

: ?compress.com ( -- )          \ compress the executable file
                ?nosave ?exit
                ?compress
                if      compress.com
                then    ;

: .TCOMSTAT     ( -- )
                segments @ 0= ?exit
                ."  Elapsed seconds: "
                time-elapsed 10 um/mod nip 1 max dup>r
                0 <# # '.' hold #s #> type
                ." ,  Lines: "  totallines @ 1 u.r
                ." ,  Compiled bytes/second: "
                0 >r
                segments @
                begin   dup 2+ @ over 4 + @ swap - r> + >r
                        @ dup 0=
                until   drop
                segments 4 + @
                begin   dup 2+ @ over 4 + @ swap - r> + >r
                        @ dup 0=
                until   drop
                r> 100 um* r> um/mod nip 0 <# # '.' hold #s #> type ;

I: %bye         ( -- )          \ return to dos after performing cleanup
                >console
                cursor-on
                RESTORE_VECTORS
                ?show_errors
                BYEFUNC         \ ALL DEFERED BYE FUNCTIONS DONE HERE!!
                ?cerrors
                save-image.com  \ save the users program now if possible
                release_memory
                ?make_listing
                ?compress.com
                >console
                cursor-on
                err-key cerrors and
                if      cr ."  \2 Errors were found, press a key to continue "
                        key drop
                then
                RESTORE_VECTORS
                .tcomstat
                ?cleanup
                cr
                cerrors %#bye ;

switch %bye bye                 \ exchange the bodies of %BYE & BYE

H: /bye          ( -- )         \ leave compiler after the compile
                bye ;

: /stay         ( -- )
                off> ?bye nosave ;

' /stay alias /sta

\+ newfile : /edit ( <filename> -- )    \ edit file specified, don't compile
\+ newfile         newfile bye ;

\+ newfile      ' /edit alias /e

\ **********************************************************************
\ Interpret the "TCOM=" string from the environment.
\ **********************************************************************

create env$ 256 allot

I: env@         ( a1 n1 --- )         \ extract the command spec
                dup>r   "envfind 0=
                if      drop env$ off
                else    r@ + envsize 255 min swap
                        env$ dup clr-hcb >nam -rot
                        do      evseg i c@l 0= ?leave
                                evseg i c@l over c! 1+
                                1 env$ c+!
                        loop    drop
                then    r>drop ;

\ I: env_interpret ( -- )
\                 " TCOM=" env@           \ get the "TCOM=" string from environ
\                 env$ c@ 0= ?exit        \ leave if nothing to interpret
\                 save> 'tib
\                 save> #tib
\                 save> >in
\                 env$ count #tib ! 'tib ! >in off        \ set to interpret
\                 interpret                               \ an interpret it
\                 restore> >in
\                 restore> #tib                           \ restore everything
\                 restore> 'tib ;

I: tcom_path@   ( -- )
                " TPATH=" env@
                env$ count fpath$ place ;

\ ***************************************************************************
\ Interpret the .OPTION statment from the application loadfile
\ ***************************************************************************

I: expand_tib   ( -- )                  \ conditionally expand tabs in TIB
                tib #tib @
                begin   9 scan ?dup
                while   over bl swap c!
                repeat  drop ;

: app_interpret ( -- )
                save> caps caps on      \ save and set CAPS
                save> 'tib              \ preserve existing interpret info
                save> #tib
                save> >in
                32 0
                do      lineread 0= ?leave
                        outbuf crlf>bl's settib
                        expand_tib
                        " .OPT" outbuf count search     \ found .OPTION?
                        if      >r
                                outbuf count 2dup
                                r> /string              \ strip ".OPTION"
                                bl scan nip - nip >in ! \ skip to BLANK
                                interpret               \ interpret OUTBUF
                                leave                   \ don't look for more
                        else    drop                    \ cleanup stack
                        then
                loop
                restore> >in            \ restore previous interpret info
                restore> #tib
                restore> 'tib
                restore> caps           \ restore CAPS
                0.0 seqhandle movepointer       \ reset file lineread info
                ibreset
                off> loadline ;

\ Since .option may be encountered at compiletime, it is defined to discard
\ the remainder of the current source line.

host definitions

' \ alias .options immediate
' \ alias .option  immediate
' \ alias .opt     immediate

compiler definitions

create bittbl   1 c, 2 c, 4 c, 8 c, 16 c, 32 c, 64 c, 128 c,

: bit>mask      ( bit -- mask ) \ convert a bit 0-7 number to a bit mask
                dup>r 7 and bittbl + c@
                r> 0 7 between 0=
                if      0 " Invalid BIT number specified" "errmsg
                then    ;

\ ***************************************************************************
\       Get the current open files last modified TIME and DATE
\ ***************************************************************************

code file_date&time     ( handle# -- file-time file-date )
               pop bx                           \ handle# -> bx
               mov ah, # $057                   \ Function 57 -> ah
               mov al, # 0                      \ 0 -> al for "get"
               int $21                          \ gets the time & date
               push cx                          \ the time to the stack
               push dx                          \ the date over it
               next     end-code

\ ***************************************************************************
\ Zero out one local label, so we can have more than one set of
\ conditionals in a colon definition. Used with -BR# above.
\ See MACRO REPEAT for an example of usage.

[assembler] ' 01lab alias 01lab

b/llab 2* 2+ array br#buf

H: BR#SWAP       ( -- )          \ exchange two most recent branch array
                                \ elements.
                [assembler]
                a;
                br#val 2- dup
                [forth]
                0<
                if      0 " Illegal attempt to resolve an branch label"
                        "errmsg abort
                then
                [assembler]
                llab>line 2dup 2>r ?cs: br#buf b/llab 2* cmoveL
                ?cs: br#buf     b/llab + 2r@   b/llab    cmoveL
                ?cs: br#buf 2r> b/llab +       b/llab    cmoveL ;

\ ***************************************************************************
\ Define the fields of the BODY of a target compiler provided function.
\
\ here is the structure of a function BODY:
\
\   +0     +1         +6            +8          +10         +12
\   ÚÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄ¿
\   ³ type ³ JMP NEST ³ res-address ³ res-chain ³ Ref-count ³ Data-size ³
\   ÀÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÙ
\
\ FIELD builds words that adjust to the various fields of the body


I: field        ( n1 n2 -- n3 )         \ compile time
                ( a1 -- a2 )
                create over c, +        \ compile offset & increment to next
                ;code   pop bx          \ get pointer to
                        sub ax, ax      \ clear AX
                        mov al, 0 [bx]  \ get byte field offset into AL
                        mov di, sp      \ get a copy of stack pointer
                        add 0 [di], ax  \ add AX to address on stack
                        next
                end-code

\ Equivelant high level code for above assembly ;code.
\
\       does> c@ +      \ adjust a1 to field address a2 of field in structure

0 >body                 \ starting at field offset >body
                        \ define field operators
        1 field >dtype          \ definition type byte                  +0
        5 field >execute        \ execution address to compile word     +1
        2 field >resaddr        \ resolution address                    +6
        2 field >chain          \ chain of unresolved references        +8
        2 field >count          \ count of times used                   +10
        2 field >dsize          \ size of data symbol                   +12
        2 field >dinitial       \ initial value of VALUEs               +14
        2 field >inited         \ has value been initialized yet        +16
' >inited alias >srcfile        \                                       +16
drop                            \ cleanup stack

\ ***************************************************************************
\ Make data type constants for target objects

I: dtype        ( n1 | <name> -- n2 )
                dup constant 1+ ;

\    !!!!  DO NOT CHANGE THE ORDER OF ANY OF THE FOLLOWING WORDS !!!!
\ These constants also specify the execution order in the later "EXEC:"
\ words LIB_COMPILE and TARG_COMPILE.

0       \ these must start with ZERO for the EXEC: in TARG_COMPILE later
        \ in this file to work properly.

        ( Macro )       dtype {M}       \    Ä¿
        ( Constant )    dtype {C}       \     ÃÄ these MUST to be together,
        ( 2Constant )   dtype {2C}      \     ³  between statments are used
        ( FConstant )   dtype {F}       \    ÄÙ  later to check for a range
        ( Data )        dtype {D}       \        of types.
        ( Value )       dtype {V}
        ( Subroutine )  dtype {S}
        ( dEfer )       dtype {E}
        ( Table )       dtype {T}
        ( Data Segment) dtype {DS}
        ( Code Segment) dtype {CS}
drop

\ ***************************************************************************
\ Debug support for target compiler

\+ (see)        H: tsee         ( | <name> -- )
\+ (see)                        ' >execute (see) ;

\+ ldump        H: tdump        ( a1 n1 -- )
\+ ldump                        seg-code -rot ldump ;

\       ONLY make TDIS if the disassembler is available

\+ =seg         H: tdis         ( a1 --- )
\+ =seg                         seg-code =seg dis ;

\+ adebug       H: tdebug       ( | <name> -- )
\+ adebug                       ' >execute adebug ;

\ ***************************************************************************
\ Symbol write routines, builds a simple symbol table for BXDEBUG.

               handle symhndl           \ file handle for symbol writing
               create symbuf  64 allot  \ symbol name buffer
        4096 constant symwsize          \ symbol buffer size
symwsize 2+ 0 pointer symseg            \ the symbol buffer

0 value symwcnt                 \ symbol write buffer character count
0 value ?sym                    \ are we building an symbol table
0 value ?index                  \ are we building an index file?
0 value ?typed                  \ include data type flag bit in symbol name?
0 value ?fil                    \ generate a FILES list file
0 value ?noredef                \ allow redefinitions
0 value ?dis                    \ load disassembler?
0 value ?dbg                    \ load debugger?
0 value ?symo                   \ did symbol file ever get opened?
0 value ?stack_check
0 value ?stack_check1

: /stack        ( -- )          \ perform stack depth increase checking
                on> ?stack_check ;

: /nostack      ( -- )          \ don't perform stack depth checking
                off> ?stack_check ;

: /nostack1     ( -- )          \ don't perform stack checking once
                off> ?stack_check1 ;

  defer  symheader      ' noop is symheader
  defer  symfooter      ' noop is symfooter
  defer  symwrite       ' noop is symwrite

: /symoff       ( -- )          \ don't create a symbol table
                off> ?sym ;

' /symoff alias /nosym

/symoff                         \ default is no symbol table file

I: ?symmake     ( -- )          \ make symbol file if /SYM was used
                ?sym 0= ?exit
                symhndl >hndle @ 0<
                if      off> symwcnt                    \ reset buffer len
                        symbol.name symhndl $>handle
                        symhndl c@ 5 <                  \ if name is ".SYM"
                        if      " TCOM.SYM" symhndl ">handle
                        then
                        symhndl hcreate dup
                        if      off> ?sym
                                0 " Could not make SYMBOL file." "errmsg
                        else    symheader
                        then    0= !> ?symo
                then    ;

I: symwflush    ( -- )          \ write symbol buffer contents to disk
                0 symwcnt symhndl symseg exhwrite symwcnt -
                if      >console
                        off> ?sym
                        0 " SYMBOL file write error" "errmsg
                then    off> symwcnt ;

I: symbwrite    ( a1 n1 -- )    \ buffered write to symbol file
                >r                              \ preserve len on return stk
                symwcnt r@ + symwsize >=        \ write buffer full?
                if      symwflush               \ then flush buffer
                then    ?cs: swap               \ prepend CS:
                symseg symwcnt r@ cmoveL        \ append data
                r> +!> symwcnt ;                \ adj count

I: symcr        ( -- )          \ write a CRLF to symbol file
                ?sym 0= ?exit
                $0A0D sp@ 2 symbwrite drop ;     \ write CRLF

I: symclose     ( -- )          \ close the symbol file if it was open
                ?symo
                if      symfooter
                        symwflush                       \ write any remaining stuff
                        symhndl hclose drop             \ and close the file
                        off> ?sym
                        off> ?symo
                        off> ?fil
                then    ;

I: symbye       ( -- )          \ function to perform when leaving forth
                symclose
                defers byefunc ;

' symbye is byefunc

\ ***************************************************************************
\ The following four words can be redefined to allow building a symbol table
\ in a different format than is provided. You will need to know the format
\ of the symbol table you want to generate.

I: %symheader   ( -- )          \ write header for debugger symbol file
                ;

I: %symfooter   ( -- )          \ write footer for debugger symbol file
                ?sym 0= ?exit
                symcr
                $001A sp@ 2 symbwrite drop ;     \ write Ctrl Z & null

I: %symwrite    ( a1 -- a1 )    \ a1 = CFA of symbol
                ?sym 0= ?exit
                dup >name
                [ ' NO-NAME >name ] literal = ?exit     \ don't bother writing
                                                        \ headerless symbols
                dup>r
                symcr
                save> base hex
                dup >resaddr @ 0 <# # # # # #>  symbwrite
                restore> base
                spcs 1                          symbwrite
\+ yseg         yseg @ over >name            ?cs: symbuf 32 cmovel
\+ headseg              dup >name +headorg 6 ?cs: symbuf 32 cmovel
                symbuf c@ 31 and symbuf c!
\+ yseg         symbuf count + 1- dup c@ 127 and swap c!
                ?typed
                if      r@ >dtype c@ dup  {S} =
                                             swap {M} = or
                                if      $80 symbuf 1+ c+!   then
                then    r>drop
                symbuf count symbwrite ;


' %symheader is symheader       \ install the defered
' %symfooter is symfooter       \ symbol table building
' %symwrite  is symwrite        \ words.

: /sym          ( -- )          \ create a symbol table file for BXDEBUG
                on> ?sym                        \ turn on symbol generation
                off> ?typed                     \ don't include type flag
                on> ?fil ;                      \ make a files list

' /sym    alias /symbols

: /redefok      ( -- )  off> ?noredef ;
: /noredef      ( -- )  on> ?noredef ;

/noredef        \ default to no redefinition allowed

\ : /forth        ( -- )          \ enable interpretive Forth in target
\                 on> ?interpretive
\                 /sym
\                 on> ?typed ;
\
\ : /dis          ( -- )          \ enable disassembly in target
\                 on> ?dis
\                 /forth ;
\
\ : /nodis        ( -- )  off> ?dis ;
\
\ : /debug        ( -- )          \ enable debugging in target
\                 on> ?dbg
\                 /dis ;
\
\ ' /debug alias /dbg
\
\ : /nodebug      ( -- )  off> ?dbg ;

: /compress     ( -- )
                on> ?compress ;

' /compress alias /lz

: /clean        ( -- )
                on> ?cleaning
                off> ?lst
                off> ?fil
                off> ?index
                /symoff ;

' /clean alias /c

/clean          \ default to no debug data files created

: /debug        ( -- )
                off> ?cleaning
                on> ?fil
                on> ?index
                /sym ;

' /debug alias /dbg

\ **********************************************************************
\  project fucntions
\ **********************************************************************

I: $open_file   ( a1 -- )               \ open file a1, or leave if it won't
                dup     $file           \ can we open it?
                if      >console
                        save> attrib
                        cr >norm space >attrib2
                        ."  [ " dup count type
                        ."  ] ** Couldn't open file ** "
                        restore> attrib
                        0 #bye
                then    drop ;

: list_align    ( -- )          \ align list space to paragraph boundry
                xhere paragraph + xdpseg ! xdp off ;

\ **********************************************************************
\ Linkage to .FIL and .LIN file creation
\ Builds a <filename>.FIL file containing a series of filename entries.
\ Each filename is trailing blank filled into a 16 byte entry.
\ the drive and path is stripped off before its inclusion in the .FIL file.
\ **********************************************************************

0 value lfile                   \ address of loaded file variable

    defer switching_files       \ marker for index record generation
' noop is switching_files

: ?filopen      ( -- f1 )       \ f1=true if file is open
                files.name >hndle @ 0< dup
                if      drop
                        files.name hcreate dup
                        if      >console
                                off> ?fil
                                0 " FILESLIST create error" "errmsg
                        then
                else    files.name endfile 2drop    \ position to end of file
                then    0= ;

I: filesbye     ( -- )          \ function to perform when leaving forth
                files.name hclose drop          \ and close the file
                off> ?fil
                defers byefunc ;

' filesbye is byefunc

: ?write_fil    ( -- )          \ write one 64 byte name record
                ?fil
                if      ?filopen
                        if      seqhandle count dup>r           \ -- a1 n1
                                files.name hwrite drop          \ --
                                spcs 64 r> - 0max               \ trail spaces
                                files.name hwrite drop
                        then
                then    ;



: $tfload       ( a1 -- f1 )    \ load file name a1, return f1=true=failed
                sequp
                <$file> dup>r 0=
                if      ?write_fil
                        incr> nextfil#
                        nextfil# save!> curfil#
                        filepointer 2@ 2dup outbuf c@ 0 d- 2>r
                        0.0 filepointer 2!
                        switching_files         \ tell switching files
                        filepointer 2!          \ restore just in case
                        %off> outbuf
                        here save!> lfile       \ fload will compile filename
                                                \ at HERE
                        <fload>
                        restore> lfile
                        2r> filepointer 2!      \ next read is here
                        restore> curfil#
                then    r>              ( --- f1 )
                seqdown
                expand_tib ;

: compload      ( -- )
                fhere off               \ clear out anything at HERE
                ?write_fil
                incr> nextfil#
                nextfil# save!> curfil#
                here !> lfile           \ OK will compile filename at HERE
                ok
                restore> curfil# ;

makedefer fload ffload                  \ convert FLOAD into a defered word
                                        \ pointing to function FFLOAD.

H: tcomfload    ( | <filename> --- )
                save> base
                bl word                         \ get filename
                switching_files
                $tfload decimal ?open.error     \ perform the load
                switching_files
                restore> base ;

' tcomfload is fload                    \ link new function into FLOAD

handle binhndl

H: BINLOAD-DATA ( -<filename>- ) \ load a binary file to DATA memory
                bl word binhndl $>handle
                binhndl hopen ?open.error
                here-d $FFF0 here-d - binhndl seg-data exhread allot-d
                binhndl hclose drop ;

H: BINLOAD-CODE ( -<filename>- ) \ load a binary file to CODE memory
                bl word binhndl $>handle
                binhndl hopen ?open.error
                here-t $FFF0 here-t - binhndl seg-code exhread allot-t
                binhndl hclose drop ;

HOST DEFINITIONS

: CHIP          ( | <filename> -- )     \ load the .DEF file in HEX base
                hex
                false save!> ?fil
                -1 save!> nextfil#
                ['] noop save!> switching_files
                tcomfload
                restore> switching_files
                restore> nextfil#
                restore> ?fil
                decimal ;

' CHIP ALIAS .CHIP
' \S   ALIAS END-EQUATES
' \S   ALIAS END_EQUATES

: PATH          ( -<path1;path2;..>- )  \ set the search path
                fpath+ ;

' PATH ALIAS .PATH

: PATH+         ( -<path1;path2;..>- )  \ append to the search path
                fpath+ ;

' PATH+ ALIAS  .PATH+
' PATH+ ALIAS  FPATH+
' PATH+ ALIAS .FPATH+

COMPILER DEFINITIONS

\ **********************************************************************
\ Actually load (compile) the application, and conditionally load the
\ additional files DIS.SEQ, TDEBUG.SEQ and TFORTH.SEQ onto the application
\ after completing the compile.  In the 8086 version of the compiler,
\ these files add an interactive mode to the application and allow
\ easier user debugging.
\ **********************************************************************
\ perform the compile

I: ?$fload      ( a1 f1 -- f2 )
                if      $tfload
                else    drop false
                then    ;

defer ido_resolve               \ inclusive resolve forward references
' noop is ido_resolve
defer edo_resolve               \ at the end resolve forward references
' noop is edo_resolve

: ?add_debug    ( -- )          \ conditionally add debug code to program
                ?interpretive
                if
\                         /redefok        \ allow redefinitions
\                         " DIS.SEQ" ">$ ?dis ?$fload
\                         if      cr ." Couldn't open " seqhandle count type
\                                 ." , no disassembler will be available."
\                         then
\                         " TDEBUG.SEQ" ">$ ?dbg ?$fload
\                         if      cr ." Couldn't open " seqhandle count type
\                                 ." , no debugger will be available."
\                         then
\                         " TFORTH.SEQ" ">$ true ?$fload
\                         if      cr ." Couldn't open " seqhandle count type
\                                 ." , can't append a Forth environment."
\                         then
                then    ;

\ ***************************************************************************
\ output error messages to "<filename>.ERR" file.
\ ***************************************************************************

           0 value ?erro
           0 value errwcnt
             handle errhndl
        4096 constant errwsize          \ symbol buffer size
errwsize 2+ 0 pointer errseg            \ the symbol buffer

I: errwflush    ( -- )          \ write symbol buffer contents to disk
                0 errwcnt errhndl errseg exhwrite errwcnt -
                if      >console
                        off> ?erro
                        0 " ERROR file write error" "errmsg
                        errhndl hclose drop
                then    off> errwcnt ;

I: errbwrite    ( a1 n1 -- )    \ buffered write to error file
                ?erro 0= if 2drop exit then     \ leave if not opened
                >r                              \ preserve len on return stk
                errwcnt r@ + errwsize >=        \ write buffer full?
                if      errwflush               \ then flush buffer
                then    ?cs: swap               \ prepend CS:
                errseg errwcnt r@ cmoveL        \ append data
                r> +!> errwcnt ;                \ adj count

I: errcr        ( -- )          \ write a CRLF to error file
                $0A0D sp@ 2 errbwrite drop ;     \ write CRLF

I: ?errmake     ( -- )                  \ make the error message file
                errhndl >hndle @ 0<
                if      off> errwcnt                    \ reset buffer len
                        error.name errhndl $>handle
                        errhndl c@ 5 <                  \ if name is ".MSG"
                        if      " TCOM.MSG" errhndl ">handle
                        then
                        errhndl hcreate
                        if      0 " Could not make ERROR file." "errmsg
                        else    on> ?erro
                                "  ** TCOM Error message file **" errbwrite
                        then
                then    ;

I: errspaces    ( n1 -- )       \ write n1 spaces to error file
                spcs swap errbwrite ;

I: erremit      ( c1 -- )       \ write char c1 to error file
                sp@ 1 errbwrite drop ;

FALSE \+ HEADC@ DROP TRUE
#IF
I: err.id       ( nfa-seg -- )
                7 over 6 headc@ 31 and 0
                ?do     2dup headc@ erremit 1+
                loop    2drop 1 errspaces ;
#ELSE
I: err.id
                dup 1+ dup yc@ rot yc@ 31 and 0
                ?do     dup 127 and erremit 128 and
                        if      95 128 or
                        else    1+ dup yc@
                        then
                loop    2drop 1 errspaces ;
#THEN

I: errclose     ( -- )          \ close the symbol file if it was open
                ?erro
                if      cerrors 0=
                        if      errcr
                                "  **    NO COMPILE ERRORS    **" errbwrite
                        then
                        errcr                   \ one last CRLF
                        errwflush               \ write any remaining stuff
                        errhndl hclose drop     \ and close the file
                        off> ?erro
                then    ;

I: errbye       ( -- )          \ function to perform when leaving forth
                errclose
                defers byefunc ;

' errbye is byefunc

: lfile_name    ( -- a1 n1 )    \ get the loaded file name
\+ yseg         yseg @ lfile >name  ycount $1f and pad placel
\+ headseg             lfile >name +headorg 6 ?cs: pad 32 cmovel
                                                        \ get the header
                pad c@ $1F and pad c!                   \ clean count
\+ yseg         pad count + 1- dup c@ $7F and swap c!   \ clean name end
                pad count ;

0 VALUE ERRMSG$

I: %%"errmsg    ( cfa a1 n1 -- )        \ display error message
                [ hidden ]
                save> base decimal
                errcr outbuf count 2- 0max      errbwrite \ show source line
                errcr errmsg$ count             errbwrite
                lfile_name                      errbwrite \ display filename
                " ("                            errbwrite
                loadline @ 1 max (.)            errbwrite
                " ) "                           errbwrite
                rot ?dup                        \ display cfa if non-zero
                if      " [ "                   errbwrite
                        >name err.id
                        " ] "                   errbwrite
                else    fhere count dup 1 31 between
                        if      " [ "           errbwrite
                                2dup            errbwrite
                                "  ] "          errbwrite
                        then    2drop         1 errspaces
                then                            errbwrite \ display message
                incr> cerrors                   \ bump found error count
                restore> base ;

I: %"errmsg     ( cfa a1 n1 -- )
                " *ERROR* " ">$ !> errmsg$
                %%"errmsg ;

I: %%"err       ( a1 n1 -- )            \ display an error
                fhere off
                0 -rot "errmsg ;

' %%"err is "err

: "warnmsg      ( cfa a1 n1 -- )        \ put out a warning to user
                " *WARNING* " ">$ !> errmsg$
                %%"errmsg
                incr> warnings                  \ add to warnings
                cerrors 1- 0max !> cerrors ;    \ not really an error

: %?show_errors ( -- )          \ show error messages if there are any
                cerrors
                if      errwflush
                        atsave 2@ at
                        #out @
                        if      cr
                        then
                        cerrors 5 >
                   if   ."  \3 +++++++  The First 5 Error Messages  +++++++ "
                   else ."  \3 +++++++++++    Error Messages    +++++++++++ "
                   then errhndl save!> seqhandle
                        0.0 seek
                        ibreset
                        5 0
                        do      %lineread c@ 0= ?leave
                                outbuf 1+ " *ERROR* " caps-comp 0=
                                if      cr space
                                        outbuf crlf>bl's count type
                                        1       \ +loop by ONE
                                else    0       \ +loop by ZERO
                                then
                       +loop
                        cr at? atsave 2!
                        restore> seqhandle
                        ibreset
                then    ;

' %?show_errors is ?show_errors

\ ***************************************************************************
\ Make a header in target

0 value ?header

: /header       ( -- )                  \ enable building headers in target
                on> ?header ;

: /nohead       ( -- )                  \ disable building headers in target
                off> ?header ;

/nohead                                 \ default to no headers in target

defer comp_header       ' drop is comp_header   \ default to nothing

I: make_header  ( a1 -- )
                ?header
                if
\+ yseg                 yseg @ over >name            ?cs: symbuf 32 cmovel
\+ headseg                      dup >name +headorg 6 ?cs: symbuf 32 cmovel
                        symbuf c@ 31 and symbuf c!
\+ yseg                 symbuf count + 1- dup c@ 127 and swap c!
                        symbuf comp_header
                then    drop ;

\ **********************************************************************
\  New version of "|" for TCOM
\ **********************************************************************

: T"iheader     ( a1 -- )
                dup>r
                save> ydp                               \ save head ptr
                I:end over c@ 5 + - dup ydp ! !> I:end  \ to end of head spc
                <"header>                               \ make the header
                restore> ydp                            \ restore head ptr
                r>
                save> current                           \ save vocabulary
                save> context                           \ current and context
                save> last
                htarget definitions                     \ select HTARGET
                <"header>                               \ make one in HTARGET
                restore> last
                restore> context                        \ restore vocabulary
                restore> current                        \ current and context
                save_"header 0= ?exit                   \ leave if empty
                save_"header is "header
                off> save_"header ;

: I|            ( -- )
                beheadable 0= ?exit             \ only if beheadable
                save_"header  ?exit             \ don't nest this operation
                @> "header !> save_"header      \ preserve current header func
                ['] T"iheader is "header ;

switch | I|     \ make the new version take effect

: TI:           ( -- )          \ Internal words definer
                I| : ;          \ really REALLY makes headerless words!

switch I: TI:

\ ***************************************************************************
\ Create a new symbol of type c1.

I: $new_symbol  ( a1 c1 -- )    \ add a new symbol string a1 of type c1
                swap            \ to the symbol list
                current @ context !             \ initialize things
                ?uppercase "create
                ( c1 ) c,                       \ +0 type BYTE "C"all
                233 C,                          \ +1      BYTE JMP
                >nest fhere 2+ - ,              \ +2      WORD DOCOL relative
                xhere paragraph + dup xdpseg !  \ align LIST
                xseg @ - ,                      \ +4      WORD LIST relative
                xdp off ;                       \ reset OFFSET

I: new_symbol   ( c1 -- )       \ add a new symbol  of type c1 to symbol list
                bl word swap $new_symbol ;

\ ***************************************************************************
\ Display a symbol

I: %.asymbol    ( a1 -- )       \ a1 = CFA of symbol
                save> base hex
                ?code
                if      cr
                        dup >resaddr @ 0 <# # # # # #> type
                        space 7 0 do ." -----" loop space
                        dup >name .id
                else    ?show
                        if      ?cr
                                dup >resaddr @ 0 <# # # # # #> type
                                2 spaces dup >name .id
                                tab
                        then
                then    drop restore> base ;

defer .asymbol  ' %.asymbol is .asymbol

I: out_symbol   ( a1 -- )       \ a1 = cfa of symbol
                dup .asymbol
                symwrite drop
                spinner2 ;

\ ***************************************************************************
\ Display a macro name when used

I: %?.macro     ( a1 -- )       \ a1 = CFA of symbol
                ?code
                if      cr ." --M-- "
                        dup >name .id
                then    drop ;

defer ?.macro   ' %?.macro is ?.macro

\ ***************************************************************************
\ Display a call name when used

I: %?.call      ( a1 -- )
                ?code
                if      save> base hex
                        cr
                        here-t 3 - 0 <# # # # # #> type 4 spaces
                        ." CALL "
                        dup >name .id
                        restore> base
                then    drop ;

defer ?.call    ' %?.call is ?.call

\ ***************************************************************************
\ Stack for items to be resolved at the end of the current definition compile.

2048 constant max_res   \ maximum number of symbols to resolve at one time

\ create res_stack max_res 2+ 2* allot
\        res_stack max_res 2+ 2* erase  \ clear stack

max_res 2* 16 + 0 pointer resseg

0 value resptr          \ resolution stack pointer

I: >res         ( a1 -- )       \ add symbol a1 to symbols to be resolved
                resseg resptr !L
                resptr 2+ max_res 2* >
                if      0 " TOO Many forward references, reference stack overflow!"
                        "errmsg abort
                then
                2 +!> resptr ;

I: res>         ( -- a1 )       \ get an item from the resolution stack
                resptr 2 <
                if      0 " Resolve Stack Underflow!" "errmsg abort
                then
                -2 +!> resptr
                resseg resptr @L ;

I: ?resdepth    ( -- n1 )       \ return depth of resolution stack in items
                resptr 2/ ;

: (;tcode)       ( cfa -- )
                2r> @l swap
                dup>r 232 ( call ) r@ c!       \ make a call not jump
                3 + - r> 1+ !  ;

: cdoes>        ( -- )
                compile (;tcode) here x, 232 ( call ) c,
                >does here 2+ - , xhere paragraph + dup xdpseg !
                xseg @ - , xdp off ; immediate

\ ***************************************************************************
\ Macro defining words. MACRO's compile IN-LINE assembly code when
\ executed at their ">EXECUTE" address. Compiled ONLY if referenced,
\ and EVERY time referenced.

0 VALUE ?MACRO

DEFER MACRO-START
DEFER LMACRO-START

H: MACRO        ( | <name> -- )
                fhere >r
                {M}  new_symbol                 \ +0    BYTE "M"acro
                -1 ,                            \ +6    WORD unresolved sym
                -1 ,                            \ +8    WORD unresolved chain
                0 ,                             \ +10   WORD reference count
                !csp                            \ save stack
                compile (lit)                   \ compile (lit)
                r@ x,                           \ followed by addr of symbol
                compile ?.macro
                macro-start
                ]                          \ compile remaining portion
                r> cdoes> body> >r a;
                r@ >count incr
                r> >execute execute ;

H: LMACRO       ( | <name> -- )
                fhere >r
                {M}  new_symbol                 \ +0    BYTE "M"acro
                -1 ,                            \ +6    WORD unresolved sym
                -1 ,                            \ +8    WORD unresolved chain
                0 ,                             \ +10   WORD reference count
                !csp                            \ save stack
                compile (lit)                   \ compile (lit)
                r@ x,                           \ followed by addr of symbol
                compile ?.macro
                lmacro-start
                ]                          \ compile remaining portion
                r> cdoes> body> >r a;
                r@ >count incr
                r> >execute execute ;

HOST DEFINITIONS
DEFER END-MACRO  IMMEDIATE      \ see the library for this definition
DEFER END-LMACRO IMMEDIATE
COMPILER DEFINITIONS

\ ***************************************************************************
\ Add a symbol that is being used, but is not yet defined.

I: add_symbol   ( a1 -- )               \ add a symbol not yet resolved
                >r                      \ Save a1 out of the way of !CSP
                                        \ in NEW_SYMBOL.
                {S}  new_symbol         \ +0    BYTE type "S" a SUBROUTINE
                -1 ,                    \ +6    WORD resolved address
                r> ,                    \ +8    WORD unresolved chain
                0 ,                     \ +10   WORD reference count
                0 ,                     \ +12   data size=0
                0 ,                     \ +14   initial value
                lfile ,                 \ +16   source file pointer
                ;

: $add_symbol   ( a1 c1 -- a2 )         \ add a symbol with name a1 type c1
                fhere >r                \ return a2 the symbol address
                $new_symbol             \ +0    BYTE type of symbol
                -1 ,                    \ +6    WORD resolved address
                -1 ,                    \ +8    WORD unresolved chain
                0 ,                     \ +10   WORD reference count
                0 ,                     \ +12   data size=0
                0 ,
                r> ;                    \ return the symbols address

\ ***************************************************************************
\ resolve one symbol a1 to here-t

0 value ?inline

DEFER RESOLVE_1 ( a1 -- )

I: %resolve_1   ( a1 -- )               \ resolve one reverence to HERE-T
                here-t over 2+ - swap O! ;

' %resolve_1 is resolve_1               \ link in default resolver


\ this is a resolve optimizer, see OPTIMIZ.SEQ for more info

defer resolve_opt       ' drop is resolve_opt

: res_symbol   ( a1 -- )               \ resolve here-t to a1
                ?inline         \ don't resolve if compiled INLINE
                if      out_symbol
                else    dup >resaddr @ -1 =
                        if      dup make_header
                                dup >dinitial @ dup lab1# br#1 1- between
                                if      [assembler]
                                        dup $:  \ else resolve local label
                                        [compiler]
                                then    drop
                                here-t over >resaddr !  \ resolve symbol
                                dup
                                >chain  dup @ swap -1!  \ resolve chain
                                begin   dup -1 <>
                                while   dup @-t swap resolve_1
                                                        \ resolve one ref
                                repeat  drop            \ discard -1
                                dup resolve_opt         \ resolve optimize
                                    out_symbol          \ write the symbol
                        else    drop
                        then    \ init_labels    01/06/93 10:32 tjz removed
                then    ;

\ ***************************************************************************
\ Either resolve a symbol already defined, or make a new symbol if its not
\ yet defined.  Flag if already defined and resolved.

0 value lib_bottom      \ bottom of target words for library
0 value lib_top

I: do_symbol    ( | <name> -- )
                >in @ >r                        \ save >IN for later
                defined                                 \ both defined AND
                over >dtype c@ {M} {T} between and      \ a real target word
                over lib_bottom u> and                  \ above lib_bottom AND
                if      dup  >resaddr @ -1 <>   \ already resolved or
                                                \ its a MACRO, CONSTANT or
                                                \ 2CONSTANT
                        over >dtype c@ {M} {F} between or
                        ?noredef and
                        if      " Attempt to REDEFINE a symbol! " "errmsg
                        else    res_symbol
                        then
                else    drop
                        r@ >in !
                        fhere >r
                        -1 add_symbol           \ add a new symbol
                        r@ make_header
                        here-t r@ >resaddr !    \ resolve address
                        r> out_symbol
                        opt_off1
                then    r>drop ;

\ ***************************************************************************
\ When actually target compiling code, compile a call to a routine

                        \ see the library for this definition
DEFER COMP_CALL         ( a1 -- )       \ a1 = CFA of symbol
DEFER COMP_JMP          ( a1 -- )       \ a1 = CFA of symbol
DEFER COMP_JMP_IMM      ( a1 -- )       \ a1 = actual code addr
DEFER SUB_RET           ( -- )          \ subtract one RET instruction

: compile_call  ( a1 -- )               \ compile call to routine
                dup comp_call ?.call ;

: compile_jmp   ( a1 -- )               \ compile jmp to routine
                dup comp_jmp  ?.call ;

\ ***************************************************************************
\ resolver for the data type definitions

I: ?dresolve    ( a1 -- a1 )            \ resolve symbol if needed
                                        \ not CONSTANT or 2CONSTANT
                dup lib_bottom u< 0=            \ not lessthan lib_bottom
                                                \ AND not a type of constant
                over >dtype c@ {C} {F} between 0= and
                over >resaddr @ -1 = and        \ AND not yet resolved
                if      here-d over >resaddr !  \ set start address
                        dup >dsize @ allot-d    \ allocate needed space
                        dup out_symbol          \ show symbols name
                then    ;                       \ return address in DS:

\ ***************************************************************************
\ resolver for the TABLE type definition

I: %?tresolve   ( a1 -- a1 )            \ resolve symbol if needed
                                        \ NOT CONSTANT OR 2CONSTANT
                dup lib_bottom u< 0=            \ not lessthan lib_bottom
                                                \ AND not a type of constant
                over >dtype c@ {C} {F} between 0= and
                over >resaddr @ -1 = and        \ AND not yet resolved
                if      here-d over >resaddr !  \ set start address
                        dup >dsize @            \ get address of data array
                        length s,-d             \ move table to target
                        dup out_symbol          \ show symbols name
                then    ;                       \ return address in DS:

defer ?tresolve ( a1 -- a1 )            \ resolve symbol if needed

' %?tresolve is ?tresolve

\ ***************************************************************************
\ perform the in-line compiling/handling of numbers

                        \ see the library for these definitions
DEFER COMP_SINGLE       \ compile a single precision number
DEFER COMP_SINGLE_ALT   \ compile a single precision number to AX for 8086
DEFER COMP_STACK_LOAD   \ load stack from wherever defined word put data ptr
' noop is COMP_STACK_LOAD \ default COMP_STACK_LOAD to "NOOP"
DEFER COMP_FETCH        \ see library
DEFER COMP_STORE        \ see library
DEFER COMP_COUNT        \ see library
DEFER COMP_PERFORM      \ see library
DEFER COMP_OFF          \ see library
DEFER COMP_ON           \ see library
DEFER COMP_INCR         \ see library
DEFER COMP_DECR         \ see library
DEFER COMP_PSTORE       \ see library
DEFER COMP_SAVE         \ see library
DEFER COMP_SAVEST       \ see library
DEFER COMP_REST         \ see library
DEFER COMP_FPUSH        \ see library

DEFER FIX-CREATE-DOES   ( n1 -- n2 )    \ test target for "create does" and
' noop is fix-create-does               \ modify address to target data addr

                                        \ resolve and compile a single number
: res_comp_single ( a1 -- )             \ a1 = address of symbol
                ?dresolve
                dup >count incr
                >resaddr @ comp_single ;

: res_comp_subroutine ( a1 -- )         \ a1 = address of subroutine
                ?dresolve
                dup >count incr
                >resaddr @ fix-create-does comp_single ;

: res_comp_double ( a1 -- )             \ compile a double number, is already
                dup >count incr         \ resolved, since used only for
                dup
                >resaddr  @ comp_single
                >dinitial @ comp_single ;

: res_comp_fconst ( a1 -- )             \ compile a floating constant
                dup >count incr
                dup >dinitial @ comp_single
                    >resaddr  @ comp_single
                                comp_fpush ;

: res_comp_value  ( a1 -- )             \ resolve and compile a value, plus
                                        \ move initial VALUE into target
                dup execute drop                \ execute to resolve
                                                \ and discard returned value
                    res_comp_single             \ compile addr of value
                    comp_fetch ;                \ follow with a fetch

\                 dup res_comp_single
\                 comp_fetch                      \ follow with a fetch
\                 dup >inited @ 0=                \ value initialized?
\                 if      dup >dinitial @         \ get initial value
\                         over >resaddr @ !-d     \ store in target
\                         dup >inited on          \ mark as initialized
\                 then    drop ;

                                        \ address of value
: res_comp_&value ( a1 -- )             \ resolve and compile single, plus
                                        \ move initial VALUE into target
                dup execute drop        \ execute to resolve
                                        \ and discard returned value
                state @
                if      ?macro          \ if we are compiling a macro then
                        if              \ compile compile a literal
                                compile (lit) >resaddr @ x,
                        else    res_comp_single
                        then
                else    >resaddr @
                then    ;

: res_comp_defer ( a1 -- )
                res_comp_single comp_perform ;

: res_comp_macro    ( a1 -- )
                dup >count   incr
                    >execute execute ;

: res_comp_call ( a1 -- )
                dup >count incr compile_call ;

: res_comp_jmp  ( a1 -- )
                dup >count incr compile_jmp ;

: res_comp_table ( a1 -- )
                execute comp_single ;

\ ***************************************************************************
\ These words expect a literal to follow compiled inline. They pick up the
\ literal and pass it as a parameter to the function specified.  This
\ technique saves two bytes per occurance of the specified operation, for
\ a savings of about 2k in the target compiler .EXE file size.

I: inlines      ( a1 | <name> -- )      \ make words that pick up inline
                                        \ literals and pass them to
                                        \ functions as parameters
                create ,
                does> 2r@ @L r> 2+ >r swap perform ;

headerless

' res_comp_single       inlines res_comp_lit
' res_comp_subroutine   inlines res_comp_sub
' res_comp_double       inlines res_comp_dbl
' res_comp_fconst       inlines res_comp_fcn
' res_comp_value        inlines res_comp_val
' res_comp_&value       inlines res_comp_&val
' res_comp_call         inlines res_comp_cll
' res_comp_jmp          inlines res_comp_jpp
' res_comp_defer        inlines res_comp_def
' res_comp_table        inlines res_comp_tbl
' comp_single           inlines comp_lit

headers

\ ***************************************************************************
\ Resolve forward references by executing the unresolved resolution stack
\ until it is empty. As each CFA on the resolution stack is executed, its
\ definition is compiled, possibly putting additional words on the
\ resolution stack.

I: %do_resolve  ( -- )                  \ execute the resolve stack
                ?inline ?exit
\+ ?long        ?long_lib save!> ?long  \ use short branches for library
                curfil# !> curfil#_save
                0 save!> curfil#        \ save and clear for source from lib
                begin   ?resdepth       \ do it till its empty
                while   res>
                        dup >count incr
                        dup >resaddr @ -1 =
                        if      >execute execute
                        else    drop
                        then
                repeat
                restore> curfil#
\+ ?long        restore> ?long
                ;

: /libafter     ( -- )
                ['] %do_resolve is edo_resolve
                ['] noop        is ido_resolve ;

: /libin        ( -- )
                ['] %do_resolve is ido_resolve
                ['] noop        is edo_resolve ;

' /libafter     alias /liba
' /libafter     alias /lib+
' /libafter     alias /+lib
' /libin        alias /libinside
' /libin        alias /libi

/libin          \ default to resolving forward references as they occur

: %release_memory ( -- )        \ release uneeded pointer memory
                                \ prior to shelling out to listing
                unpointer> errseg
                unpointer> symseg
                unpointer> seg-code
                unpointer> seg-data
                unpointer> svseg ;

' %release_memory is release_memory

