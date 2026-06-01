\\ TCOMS.SEQ       Display a TCOM generated symbol file    by Tom Zimmer

        Modified 01/03/92 to add minimal help and compiler options. TJZ

{

.options /opt /noinit /nostack          \ compiler options

:: ifield       ( n1 n2 -<name>- n3 )
                ( a1 -- a2 )
                create over c, +        \ compile offset & increment to next
                does> c@ + ;            \ adjust a1 to field address a2


0                       \ starting at field offset zero (0),
 32 ifield >symname     \ symbol name as a counted string
  1 ifield >symtype     \ symbol type for TCOM (macro, function, variable..)
  2 ifield >symresaddr  \ symbols resolution address
  2 ifield >symvalue    \ symbols initial value if a VALUE or CONSTANT
  1 ifield >symfile#    \ source file number in .FIL file
  4 ifield >symoffset   \ source file offset in bytes
  2 ifield >symsize     \ size of data symbol in bytes
  4 ifield >symunused   \ unused space in symbol table entry
constant sym_len        \ length of symbol record buffer

sym_len array symbuf

handle symhndl

: sp>col        ( n1 -- )
                #out @ - 0max spaces ;

: .stype        ( c1 -- )       \ display the symbol type
                dup 2 .r space
                #out @ >r
                case
                        0 of    ." Macro"  endof
                        1 of    ." Const"  endof
                        2 of    ." 2Cons"  endof
                        3 of    ." FCons"  endof
                        4 of    ." Varia"  endof
                        5 of    ." Value"  endof
                        6 of    ." Funct"  endof
                        7 of    ." Defer"  endof
                        8 of    ." Table"  endof
                      255 of    ." Unres"  endof
                                drop
                endcase r> 11 + sp>col ;

0 value symcnt

: .1sym         ( -- )
                cr symcnt 3 .r space
                incr> symcnt
                save> base hex
                symbuf >symtype        c@ .stype
                symbuf >symresaddr      @ 6 u.r
                symbuf >symvalue        @ 7 u.r
                symbuf >symsize         @ 6 .r
                symbuf >symfile#       c@ 6 .r
\                decimal
                symbuf >symoffset      2@ 9 d.r
                6 spaces
                symbuf >symname count type
                restore> base ;

: .usage        ( -- )
                ." Display a TCOM generated Symbol table" cr
                ." Usage: TCOMS <filename> <enter>" ;

: main          ( -- )
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                bl word c@ 0=
                if      .usage abort
                then
                here symhndl $>handle
                " SYM" ">$ symhndl $>ext
                symhndl hopen                           \ open the file
                if      ." Couldn't open "              \ if failed!
                        symhndl count type
                        cr .usage abort                 \ terminate program
                then
cr ."     Type           Resaddr  Value  Size  File#  Offset  Symbol Name"
                bl word c@
        if      0
                begin   drop
                        symbuf sym_len symhndl hread sym_len =
                        symbuf >symname here dup c@ 1+ caps-comp tuck and 0=
                        ?keypause
                until
                if      0.0 symhndl movepointer \ reset to beginning of file
                else    .1sym
                then
        then    begin   symbuf sym_len symhndl hread sym_len =
                while   .1sym
                        ?keypause
                repeat  ;


}

