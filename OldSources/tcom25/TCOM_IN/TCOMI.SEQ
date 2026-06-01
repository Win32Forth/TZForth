\\ TCOMI.SEQ      Display a TCOM generated index file       by Tom Zimmer

        Modified 7/1/90 To print the integer of the type and
                        the file offset in hex. JB

        Modified 01/03/92 to add minimal help and compiler options. TJZ

{

.options /opt /noinit /nostack          \ compile options

:: ifield       ( n1 n2 -<name>- n3 )
                ( a1 -- a2 )
                create over c, +        \ compile offset & increment to next
                does> c@ + ;            \ adjust a1 to field address a2

0                       \ starting at field offset zero (0),
  2 ifield >targaddr    \ target address field
  3 ifield >srcoff/type \ Combined source file offset and type nibble
  1 ifield >srcfile#    \ source file number in .FIL file
constant inx_len        \ length of index record buffer

inx_len array inx_buf   \ -- uses stack value for total length of fields

handle inxhndl          \ index file handle


\  0 constant notype
\  1 constant othertype
\  2 constant insttype
\  3 constant calltype
\  4 constant bytetype
\  5 constant wordtype
\  6 constant stringtype
\  7 constant segmentend
\  8 constant branchtype
\  9 constant :othertype
\ 10 constant :insttype
\ 11 constant :calltype
\ 12 constant :bytetype
\ 13 constant :wordtype
\ 14 constant :stringtype
\ 15 constant segmentstart

: sp>col        ( n1 -- )
                #out @ - 0max spaces ;

: .itype        ( c1 -- )       \ display the index record type
                #out @ >r
                save> base decimal
                dup 2 .r space
                restore> base
                case
                        0 of    ." Notype"       endof
                        1 of    ." Other"        endof
                        2 of    ." Inst"         endof
                        3 of    ." Call"         endof
                        4 of    ." Byte"         endof
                        5 of    ." Word"         endof
                        6 of    ." String"       endof
                        7 of    ." SegEnd"       endof
                        8 of    ." BRtype"       endof
                        9 of    ." :Other"       endof
                       10 of    ." :Inst"        endof
                       11 of    ." :Call"        endof
                       12 of    ." :Byte"        endof
                       13 of    ." :Word"        endof
                       14 of    ." :String"      endof
                       15 of    ." SegStart"     endof
                                drop
                endcase r> 13 + sp>col ;

: .srcoff/type  ( a1 -- )       \ display source offset and type nibble
                save> base hex
                2 spaces
                count swap @ swap               \ get 3 bytes
                dup $F0 and u16/                \ get upper nibble of
                                                \ low byte of upper word
                .itype                          \ display the type
                $0F and                         \ mask off the type nibble
                7 ud.r                          \ display the source offset
                restore> base ;

0 value inxcnt

: .1inx         ( -- )
                cr inxcnt 5 u.r space
                incr> inxcnt
                save> base hex
                inx_buf >targaddr        @ 6 u.r
                decimal
                inx_buf >srcoff/type     .srcoff/type
                inx_buf >srcfile#       c@ 7 .r
                restore> base ;

: .usage        ( -- )
                ." Display a TCOM generated Index file" cr
                ." Usage: TCOMI <filename> <enter>" ;

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
                here inxhndl $>handle
                " INX" ">$ inxhndl $>ext
                inxhndl hopen                           \ open the file
                if      ." Couldn't open "              \ if failed!
                        inxhndl count type
                        cr .usage abort                 \ terminate program
                then
                cr ."         Addr     Type        Src Off  File#"
                begin   inx_buf inx_len inxhndl hread inx_len =
                while   .1inx
                        ?keypause
                repeat  ;


}

