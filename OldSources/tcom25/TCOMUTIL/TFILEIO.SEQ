\ FILEIO.SEQ         Buffered FIle I/O For F-PC      by Tom Zimmer

\   This file contains a set of words that allow reading and writing
\ bytes and lines to multiple files at the same time. Any buffered handle
\ created, can be read from, or written to, but not both during a single
\ open.  When a file is written to, the word BFLUSH must be used to clear
\ the write buffer before a BCLOSE is performed, or data will be lost. A
\ buffer size of 2k is used.
\
\ ***************************************************************************
\               The Buffered HANDLE memory data structure
\ ***************************************************************************
\
\         2 bytes     2 bytes       2 bytes        2 bytes
\       [ segment ]-[ bufr-size ]-[ bufr-bytes ]-[ bufr-off ]->
\         addr        addr+2        addr+4         addr+6
\         |           |             |              |
\         |_>BSEG     |_>BSIZE      |_>BBYTES      |_>BOFF
\         |
\         |        1 byte
\         |    <-[ count  ]
\         |        addr+10
\         |        |
\         |        |_>BHANDLE
\         |
\         |
\         |_"addr" is returned         by a word defined with BHANDLE.
\
\ **********************************************************************
\       Define the field traversal words for buffered handles
\ **********************************************************************

MACRO >BSEG     ( a1 -- a2 )                    END-MACRO
MACRO >BSIZE    ( a1 -- a2 )    ADD BX, # 2     END-MACRO
MACRO >BBYTES   ( a1 -- a2 )    ADD BX, # 4     END-MACRO
MACRO >BOFF     ( a1 -- a2 )    ADD BX, # 6     END-MACRO
MACRO >BHANDLE  ( a1 -- a2 )    ADD BX, # 8     END-MACRO

0 value b_exseg         \ read/write segment temporary

\ **********************************************************************
\       Define "name" as a buffered handle for read or write
\ **********************************************************************

:: BHANDLE      ( -<name>- )                    \ make a pointer "name"
                ( -- addr )                     \ it's structure
                CREATE                          \ make the name
                0 ,                             \ initialize read to NULL
                $80 ,   ( 2048 decimal )        \ buffer size in paragraphs
                0 ,                             \ bytes in buffer
                0 ,                             \ buffer offset
                B/HCB ALLOT                     \ space for handle
                DOES>   DUP >BSEG @ ?EXIT
                        >R
                        R@ >BSIZE @ ALLOC 8 =
                        ABORT" Failed to allocate memory!"
                        NIP R@ >BSEG !
                        0 R@ >BOFF !            \ clear buffer offset
                        R> ;                    \ return structurer address

: BREFILL       ( bhandle -- )  \ refill the buffered file handle
                dup>r >bbytes @
                if      r@ >bseg @ r@ >boff @ over 0 r@ >bbytes @ cmovel
                then    0 r@ >boff !
                r@ >bbytes @ r@ >bsize @ 16 * over -
                r@ >bhandle r@ >bseg @ exhread r> >bbytes +! ;

: BFLUSH        ( bhandle -- )  \ Flush the buffered data to file handle
                >r 0 r@ >boff @ r@ >bhandle r@ >bseg @ exhwrite
                r@ >boff @ <> abort" Buffered write error"
                0 r@ >boff ! r@ >bsize @ 16 * r> >bbytes ! ;

: BEMPTY        ( bhandle -- )  \ discard the contents of the buffered handle
                >r 0 r@ >bbytes !               \ set remaining to zero
                r@ >bsize @ 16 * r> >boff ! ;   \ set OFFSET to end of buffer

: BMOVEPOINTER  ( d1 bhandle -- )       \ position to d1 offset into bhandle
                dup bempty              \ discard current buffers contents
                >bhandle movepointer ;  \ adjust the file pointer

: %BREAD        ( a1 n1 bhandle -- n2 )  \ buffered file read
                dup>r >bbytes @ over u>=         \ if buffer has enough bytes
                if      r@ >bseg @ r@ >boff @ 2swap b_exseg -rot
                        dup r@ >boff +!                 \ increase offset
                        dup negate r@ >bbytes +!        \ reduce remainder
                        dup>r cmovel                    \ move the data
                        r> r>drop                       \ bytes read
                        exit
                then                            \ else refill the buffer
                over r@ >bseg @ r@ >boff @ rot b_exseg swap
                r@ >bbytes @ dup>r cmovel
                r> dup r@ >boff +!                      \ mark as empty
                0 r@ >bbytes !                          \ start empty
                r@ brefill                              \ refill buffer
                dup>r -rot r> /string                   \ remove read part
                r@ >bbytes @                    \ any bytes from BREFILL?
                if      r@ ( RECURSIVE ) %bread +
                else    2drop                           \ -- n1
                then    r>drop ;

: EXBREAD       ( a1 n1 bhandle seg -- n1 )     \ read into seg
                !> b_exseg %bread ;

: BREAD         ( a1 n1 bhandle -- n1 )         \ read into DS:
                ?ds: !> b_exseg %bread ;

: %BWRITE       ( a1 n1 bhandle -- )    \ buffered file write
                >r dup r@ >bbytes @ u<          \ if there is room in buffer
                if      tuck b_exseg -rot          \ dup cnt under addr
                        r@ >bseg @ r@ >boff @ rot cmovel
                        dup r@ >boff +!
                        negate r@ >bbytes +!
                else    over b_exseg swap
                        r@ >bseg @ r@ >boff @ r@ >bbytes @ dup>r cmovel
                        r> dup r@ >boff +!
                        0 r@ >bbytes !
                        r@ bflush
                        /string
                        r@ ( RECURSIVE ) %bwrite
                then    r>drop ;

: EXBWRITE      ( a1 n1 bhandle seg -- )        \ write from seg
                !> b_exseg %bwrite ;

: BWRITE        ( a1 n1 bhandle -- )            \ write from DS:
                ?ds: !> b_exseg %bwrite ;

: BCLOSE        ( bhandle -- f1 )       \ close the buffered file
                >bhandle hclose ;         \ -- f1 return error flag

: BOPEN         ( bhandle -- f1 )       \ open the buffered file
                dup bempty >bhandle hopen ;

: BCREATE       ( bhandle -- f1 )       \ create file in bhandle
                dup>r >bsize @ 16 * r@ >bbytes ! \ remaining room to size
                0 r@ >boff !                     \ set offset to zero
                r> >bhandle hcreate ;

: BDELETE       ( bhandle -- f1 )       \ delete file in bhandle
                >bhandle hdelete ;

: $>BHANDLE     ( a1 bhandle -- )       \ move string into buffered handle
                >bhandle $>handle ;

: ">BHANDLE     ( a1 n1 bhandle -- )    \ move string into buffered handle
                >bhandle ">handle ;

$0A VALUE TERM_CHAR             \ line termination character

: BLINEREAD     ( bhandle -- segment a1 n1 )
                dup >bseg @ save!> sseg >r
                r@ >bbytes @ 256 u<
                if      r@ brefill      \ then refill the buffer
                then    r@ >bbytes @
        [long]  if      r@ >boff @ r@ >bbytes @ 2dup term_char scan
                        2dup 2>r nip dup if 1- then -
                        2r> 1 /string r@ >bbytes ! r@ >boff !
                        r@ >bseg @ -rot
                else    r@ >bseg @ 0 0
                then    r>drop
                restore> sseg ;

: BCURPOINTER   ( bhandle -- d1 )       \ get current file position of
                                        \ bhandle to recent BLINEREAD
                dup>r >bhandle curpointer       \ current physical file ptr
                r> >bbytes @ 0 d-  ;            \ backup for buffer contents

\S      ***************** Stop Loading Here ******************

\ Example usage of buffered file words

: typel         ( seg off len -- )
                0
                ?do     2dup c@L emit 1+
                loop    2drop ;

create crlf$ $0D c, $0A c,

bhandle testfile1

: wtest        ( -- )          \ multi file buffered write test
                testfile1 bcreate abort" Failed to make file1"
                10 0
                do
                        " #1 Hello there "      testfile1 bwrite
                        i (u.)                  testfile1 bwrite
                        crlf$ 2                 testfile1 bwrite
                loop    testfile1 bflush
                testfile1 bclose drop ;

: rtest         ( -- )          \ lineread test WITH screen update
                testfile1 bopen abort" Filed to open file1"
                cr
                10 0
                do      testfile1 blineread typel
                loop    testfile1 bclose drop ;

: MAIN          ( -- )
                DECIMAL                         \ always select decimal
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                " file1."  ">$ testfile1  $>bhandle
                cr ." Performing Write test."
                wtest
                cr ." Performing Read test."
                rtest ;

