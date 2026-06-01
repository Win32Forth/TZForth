\\ DMP.SEQ


        .options /opt /noinit
{

needs \tcom\tpoint.seq

32768 constant seg-limit

    0 value inx-ptr

seg-limit $10 + 0 pointer cpm_seg     0 value cpm-len
seg-limit       0 pointer sym_seg     0 value sym-len
seg-limit       0 pointer inx_seg     0 value inx-len

handle cpmhndl

: @T            ( a1 -- n1 )
                cpm_seg swap @L ;

: C@T           ( a1 -- n1 )
                cpm_seg swap C@L ;

fload dis80.seq

: read-1file    ( bufoff buflen bufseg extadr extlen -- readlen )
                ">$ cpmhndl $>ext
                cpmhndl hopen
                if      cr ." Couldn't open: "
                        cpmhndl count type abort
                then
                cpmhndl swap exhread ( -- readlen )     \ length is returned
                cpmhndl hclose drop ;

: read-files    ( -<name>- )
                bl word dup c@ 0=
                if      drop
                        ." Filename?: " query bl word
                then    cpmhndl $>handle
                $100 seg-limit cpm_seg " CPM" read-1file $100 + !> cpm-len
                   0 seg-limit sym_seg " SYM" read-1file        !> sym-len
                   0 seg-limit inx_seg " INX" read-1file        !> inx-len
                ;

: ifield        ( n1 n2 -<name>- n3 )
                ( a1 -- a2 )
                create over c, +        \ compile offset & increment to next
                does> c@ + ;            \ adjust a1 to field address a2

0       /nostack1       \ starting at field offset zero (0),
  2 ifield >targaddr    \ target address field
  3 ifield >srcoff/type \ Combined source file offset and type nibble
  1 ifield >srcfile#    \ source file number in .FIL file
constant inx_size       \ length of index record buffer

0       /nostack1       \ starting at field offset zero (0),
 32 ifield >symname     \ symbol name as a counted string
  1 ifield >symtype     \ symbol type for TCOM (macro, function, variable..)
  2 ifield >symresaddr  \ symbols resolution address
  2 ifield >symvalue    \ symbols initial value if a VALUE or CONSTANT
  1 ifield >symfile#    \ source file number in .FIL file
  4 ifield >symoffset   \ source file offset in bytes
  2 ifield >symsize     \ size of data symbol in bytes
  4 ifield >symunused   \ unused space in symbol table entry
constant sym_size       \ length of symbol record buffer

32 array nbuf

: >>name        ( cfa -- name )
                >r 0
                begin   sym_seg over >symresaddr @L r@ <>
                        over sym-len u< and
                while   sym_size +
                repeat  dup sym-len u<
                if      >symname sym_seg swap ?ds: nbuf 32 cmovel
                else    drop nbuf off
                then    r>drop nbuf ;

: >>find        ( counted-string -- cfa )
                sym_seg save!> sseg             \ searching the symbol seg
                >r 0
                begin   r@ over >symname r@ c@ 1+ caps-comp
                        over sym-len u< and
                while   sym_size +
                repeat  dup sym-len u<
                if      >symresaddr sym_seg swap @L
                else    drop 0
                then    r>drop
                restore> sseg ;

: inx-reset     ( -- )
                off> inx-ptr ;

: next-inx      ( -- a1 type )
                inx_seg inx-ptr >targaddr @L
                inx_seg inx-ptr >srcoff/type c@L $F0 and u16/
                inx_size +!> inx-ptr ;

\  2 ifield >targaddr    \ target address field
\  3 ifield >srcoff/type \ Combined source file offset and type nibble


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
$14E CONSTANT RP0
$150 CONSTANT RP
$152 CONSTANT SP0
$154 CONSTANT VOC-INIT

0 value |"
0 value |lit
0 value |do
0 value |?do
0 value |loop
0 value |+loop
0 value |?branch
0 value |branch

: inline-init   ( -- )
                " (x)" over '"' swap 1+ c!      \ fix "
                                ">$ >>find =: |"
                " (lit)"        ">$ >>find =: |lit
                " (do)"         ">$ >>find =: |do
                " (?do)"        ">$ >>find =: |do
                " (loop)"       ">$ >>find =: |loop
                " (+loop)"      ">$ >>find =: |+loop
                " ?branch"      ">$ >>find =: |?branch
                " branch"       ">$ >>find =: |branch ;

: h.2           ( n1 -- )
                save> base hex
                0 <# # # #> type space
                restore> base ;

: h.4           ( n1 -- )
                save> base hex
                0 <# # # # # #> type space
                restore> base ;

: $dump         ( a1 -- )
                dup c@T '"' emit swap 1+ swap 0
                ?do     dup i + c@T emit
                loop    drop '"' emit space ;

: .header       ( a1 -- )
                cr dup ." At: " h.4 dup @T ." Link: " h.4
                2+ dup c@T
                2dup + 1+ >r
                swap 1+ swap 0
                ?do     dup i + c@T 127 and emit
                loop    drop
                ."  CFA: " r> h.4 ;

: dumpT         ( a1 n1 -- )
                2dup 2>r ." Starts at: "
                swap 2 bounds
                ?do     ?cr i c@T h.2   ?keypause
                loop
                ."  length = " u.
                2r> over 2+ !> cptr +
                begin   dup cptr u>
                while   cr tab inst
                        ?keypause
                repeat  ;

: ?inline       ( a1 -- )
                dup @T
                case
                |"       of     2+ $dump   endof
                |lit     of     2+ @T h.   endof
                |do      of     2+ @T h.   endof
                |?do     of     2+ @T h.   endof
                |loop    of     2+ @T h.   endof
                |+loop   of     2+ @T h.   endof
                |?branch of     2+ @T h.   endof
                |branch  of     2+ @T h.   endof
                                2drop
                endcase ;

: .word         ( a1 -- )
                dup @T >>name dup c@
                if      count type space
                        dup ?inline
                else    ." [" h.4 ." Unknown]"
                then    drop ?cr ;

: ||:           ( a1 -- )
                ." COLON " drop ;

: ||create      ( a1 -- )
                ." VARIABLE " 2+ @T h. ;

: ||defer       ( a1 -- )
                ." DEFER " 2+ @T dup h. ?dup
                if      >>name count type
                then    ;

: ||constant    ( a1 -- )
                ." CONSTANT " 2+ @T h. ;

: .wordtype     ( a1 -- )
                tab dup @T
                case
                nest       of   ||:             endof
                docreate   of   ||create        endof
                dodefer    of   ||defer         endof
                doconstant of   ||constant      endof
                                swap 2+ =
                                if      ." CODE "
                                then
                endcase         ;

: notype        ( a1 -- ) drop ;
: othertype     ( a1 -- ) .wordtype ;
: insttype      ( a1 -- ) !> cptr cr tab inst ;
: calltype      ( a1 -- ) !> cptr cr tab inst ;
: bytetype      ( a1 -- ) cr tab dup h.4 c@T h.2 ;
: wordtype      ( a1 -- ) drop ;
: stringtype    ( a1 -- ) cr tab $dump ;
: endtype       ( a1 -- ) drop ;
: branchtype    ( a1 -- ) drop ;
: :othertype    ( a1 -- ) .header ;
: :insttype     ( a1 -- ) drop ;
: :calltype     ( a1 -- ) .word ; \ really lists of addresses
: codebytetype  ( a1 -- ) drop ;
: codewordtype  ( a1 -- ) drop ;
: :stringtype   ( a1 -- ) cr tab $dump ;
: starttype     ( a1 -- ) drop ;

: do-inx        ( a1 type -- )
                $0F and exec:
                notype          othertype       insttype        calltype
                bytetype        wordtype        stringtype      endtype
                branchtype      :othertype      :insttype       :calltype
                codebytetype    codewordtype    :stringtype     starttype ;

: init-segs     ( -- )          \ initialize the far segments
                cpm_seg 0=
                sym_seg 0= or
                inx_seg 0= or   abort" Failed to allocate memory"
                cpm_seg 0 seg-limit 0 LFILL     0 !> cpm-len
                sym_seg 0 seg-limit 0 LFILL     0 !> sym-len
                inx_seg 0 seg-limit 0 LFILL     0 !> inx-len ;

: main          ( -<name>- )
                decimal
                dosio_init
                caps on
                ?ds: sseg !
                $fff0 set_memory
                DOS_TO_TIB                      \ move command tail to TIB
                16 tabsize !
                16 lmargin !
                65 rmargin !
                init-segs
                read-files
                inline-init
                inx-reset
        begin   inx-ptr inx-len u<
        while   next-inx
                over >>name dup c@
                if      dup count cr type
                then    drop
                do-inx
                ?keypause
        repeat  drop cr ;



