\ FRTH.SEQ              Interpretive Forth Experiment     by Tom Zimmer

0 VALUE  HEADSEG
HANDLE   HEADHNDL
0 VALUE  HEADDP
0 VALUE  WORDCNT

: READ_SYMTBL   ( -- )
                $1000 alloc 8 =
                abort" Could not allocate space for symbols" nip =: headseg
                me@ me$ headhndl $>handle
                " SYM" ">$ headhndl $>ext
                headhndl hopen
                if      cr ." Couldn't open symbol file "
                        headhndl count type abort
                then
                0 $FFF0 headhndl headseg exhread =: headdp ;

\       ( Macro )       0               types of symbols
\       ( Constant )    1
\       ( 2Constant )   2
\       ( FConstant )   3
\       ( Data )        4
\       ( Value )       5
\       ( Subroutine )  6
\       ( dEfer )       7
\       ( Table )       8

: FIND          ( adr  -- cfa flag )
                dup c@ 0= if false exit then
                headseg save!> sseg
                >r 0
                begin   r@ 2dup c@ 1+ compare
                        over headdp u< and
                while   48 +
                repeat  dup headdp u<
[long]          if      headseg over 33 + @L            \ get resaddr
                        headseg rot  32 + c@L           \ get type
                        case
                                6 of    255     endof   \ subroutine
                                0 of    255     endof   \ macro
                                7 of    254     endof   \ defered word
                                        drop 1          \ all others
                        endcase
                else    drop here false
                then    r>drop
                restore> sseg ;

: DEFINED       ( -- here 0 | cfa [ -1 | 1 ] )
                BL WORD ?UPPERCASE FIND ;

: LTYPE         ( seg a1 n1 -- )
                bounds
                ?do     dup i c@L emit
                        ?keypause
                loop    drop ;

: .1NAME        ( a1 -- )
                save> base hex
                >r
                headseg r@ 33 + @L 4 u.r space
                headseg r@ 1+ headseg r> c@L ltype
                restore> base ;

: WORDS         ( -- )
                cr
                off> wordcnt
                20 save!> tabsize
                60 save!> rmargin
                0
                begin   dup headdp u<
                        ?keypause
                while   dup .1name
                        incr> wordcnt
                        wordcnt 3 and 0=
                        if      cr
                        else    tab
                        then
                        48 +
                repeat  drop
                restore> rmargin
                restore> tabsize
                cr wordcnt . ." Total words " ;

\ These seemingly silly definitions, make library macros available to
\ the interpretive Forth environment.

\ While these are techically re-definitions, any references to these words
\ either before they are defined, or after, will still use the library
\ defined macro.

: @             ( a1 -- n1 )    @ ;
: !             ( n1 a1 -- )    ! ;
: C@            ( a1 -- n1 )    C@ ;
: C!            ( n1 a1 -- )    C! ;
: @-T           ( a1 -- n1 )    ?cs: swap @L ;
: !-T           ( n1 a1 -- )    ?cs: swap !L ;
: C@-T          ( a1 -- n1 )    ?cs: swap C@L ;
: C!-T          ( n1 a1 -- )    ?cs: swap C!L ;

: BYE           ( -- )          BYE ;
: DP            ( -- a1 )       DP ;
: HERE          ( -- a1 )       DP @ ;
: DECIMAL       ( -- )          DECIMAL ;
: HEX           ( -- )          HEX ;
: DUP           ( ? )           DUP ;
: DROP          ( ? )           DROP ;
: OVER          ( ? )           OVER ;
: SWAP          ( ? )           SWAP ;
: 2DROP         ( ? )           2DROP ;
: EXECUTE       ( N1 -- )       EXECUTE ;
: ?CS:          ( ? )           ?CS: ;
: ?DS:          ( ? )           ?DS: ;
: TIB           ( ? )           TIB ;
: +             ( ? )           + ;
: -             ( ? )           - ;
: *             ( ? )           * ;
: /             ( ? )           / ;
: MOD           ( ? )           MOD ;
: +!            ( ? )           +! ;
: 0=            ( ? )           0= ;
: 1+            ( ? )           1+ ;
: 2+            ( ? )           2+ ;
: INCR          ( ? )           INCR ;
: DECR          ( ? )           DECR ;
: RP@           ( ? )           RP@ 2+ ;
: SP@           ( ? )           SP@ ;

: ?DO_EXECUTE   ( n1 f1 -- )
                case
                        255 of  execute         endof
                        254 of  @ execute       endof
                                drop
                endcase ;

: ?MISSING      ( F1 -- )
                if      here count type true abort"  ?"
                then    ;

: .DEPTH        ( -- )
                depth 10 umin 0
                ?do ." ." loop ;

: TNUMBER?      ( a1 -- d1 f1 )
                dup 1+ c@ '$' =                 \ if first char is a $
                if      save> base hex
                        dup>r count 1- over c!  \ remove  the $ symbol
                        number?                 \ attempt number conversion
                        '$' r> 1+ c!            \ restore the $ symbol
                        restore> base
                else    number?
                then    ;

: NUMBER        ( a1 -- n1 )
                tnumber? nip 0= ?missing ;

: DUMMY         ( -- )                  \ make sure a bunch of words are
                exit                    \ included in target
                u. .r h. h.r dump words ;

: ?STACK        ( -- )
                depth 0< abort" Stack Underflow!" ;

: INTERPRET     ( -- )
                broken @ if bye then            \ leave on Ctrl-Break
                begin   ?stack  defined here c@
                while   ?dup
                        if      ?do_execute
                        else    number
                        then
                repeat  2drop ;

: '             ( | <name> -- a1 )
                defined 0= ?missing ;

: >NAME         ( adr  -- adr2 )        \ return the name field count byte
                >r 33                   \ address of header
                begin   headseg over @L r@ <>
                        over headdp u< and
                while   48 +
                repeat  dup headdp u<
                if      33 -                    \ step back to name field
                else    drop false
                then    r>drop ;

: .ID           ( a1 -- )
                dup 0= if drop exit then
                headseg swap 2dup c@L ?ds: pad rot 1+ cmovel
                pad count type space ;

?DIS #IF

\- sym_len      48 constant sym_len

sym_len ARRAY DISNAME

: DIS>SYMBOL    ( a1 -- a2 f1 )
                >name dup
                if      headseg swap ?ds: disname sym_len cmovel
                        disname true
                else    0
                then    ;

: SEE           ( | <name> -- )
                ['] ?.symbol   is .symbol
                ['] dis>symbol is >symbol
                ' headseg over >name 32 + c@L
                case
                        6 of    -1      endof   \ subroutine
                        0 of    -1      endof   \ macro
                                drop 0          \ all others
                endcase
                if      dis
                else    10 dump
                then    ;

: DIS           ( a1 -- )
                ['] ?.symbol   is .symbol
                ['] dis>symbol is >symbol
                dis ;

#ENDIF

?DBG #IF

: DBG           ( | <name> -- )
                ['] ?.symbol   is .symbol
                ['] dis>symbol is >symbol
                ' $trace ;

: DEBUG         ( | <name> -- )
                ['] ?.symbol   is .symbol
                ['] dis>symbol is >symbol
                ['] interpret  =: interp
                ' $breakat ;

: $TRACE        ( a1 -- )
                ['] ?.symbol   is .symbol
                ['] dis>symbol is >symbol
                $trace ;

: $BREAKAT      ( a1 -- )
                ['] ?.symbol   is .symbol
                ['] dis>symbol is >symbol
                ['] interpret  =: interp
                $breakat ;

#ENDIF

: QUIT          ( -- )
                sp0 @ sp!               \ reset data stack
                sp0 @ 2+ 'tib !         \ reset TIB
                begin   rp0 @ rp!       \ reset return stack
                        cr query space
                        interpret ."  ok " .depth
                again  ;

: COLD          ( -- )
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                ." 80x86 Forth environment for TCOM "
                0 =: abort_func
                read_symtbl     \ error here, does BYE
                ['] quit is abort_func          \ don't leave on error
                quit
                ;

