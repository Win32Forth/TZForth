\\ FILEIO.SEQ         Buffered FIle I/O For F-PC      by Tom Zimmer

***************************************************************************

  This file contains a set of words that allow reading and writing bytes
and lines to multiple files at the same time. Each file is buffered for
either read or write, with a user specified buffer size. Any buffered
handle created, can be read from, or written to, but not both during a
single open.  When a file is written to, the word BFLUSH must be used to
clear the write buffer before a BCLOSE is performed, or data will be lost.
A default buffer size of 2k is normally used, but you can change the value
of B_SIZE to a new value if you want to change the size of a single
buffered handle that is about to be created. This is done as follows:

        16384 !> b_size
        bhandle big_buffered_handle

the value of B_SIZE is restored to DEF_BSIZE after each invocation of
BHANDLE, so you will need to change DEF_BSIZE to a new value if you want to
make all handle being defined have a buffer size other than the default
2048 bytes.  It is useful to note that while you can change DEF_BSIZE to a
larger value, it probably will not have a large effect on the line read
rate.

NOTE:   Don't make either B_SIZE or DEF_BSIZE smaller than 512 bytes. The
        BREFILL word uses a lower limit level of 256 to decide to refill
        the read buffer for a buffered handle.

***************************************************************************
              The Buffered HANDLE memory data structure
***************************************************************************

        2 bytes     2 bytes
      [ segment ]-[ pointer-link ]->
        addr        addr+2
        |           |
        |_>BSEG     |_>BLINK
        |
        |        2 bytes       2 bytes        2 bytes
        |    <-[ bufr-size ]-[ bufr-bytes ]-[ bufr-off ]->
        |        addr+4        addr+6         addr+8
        |        |             |              |
        |        |_>BSIZE      |_>BBYTES      |_>BOFF
        |
        |        1 byte
        |    <-[ count  ]
        |        addr+10
        |        |
        |        |_>BHANDLE
        |
        |_"addr" is returned         by a word defined with BHANDLE.

***************************************************************************
***************************************************************************

{

\ **********************************************************************
\       An error message handler for buffered files
\ **********************************************************************

defer "berrmsg                  \ define an error message handler

I: %"berrmsg    ( cfa a1 n1 -- )
                rot cr >name .id type ;

' %"berrmsg is "berrmsg         \ give defered word a default function

\ **********************************************************************
\       Define the field traversal words for buffered handles
\ **********************************************************************

: +FIELD        ( n1 n2 -<name>- n3 )   \ define "name" as an offset word
                ( a1 -- a2+n1 )
                CREATE OVER C, + DOES> C@ + ;

0   2 +FIELD >BSEG              \ starting paragraph of buffer
    2 +FIELD >BLINK             \ link in pointer chain
    2 +FIELD >BSIZE             \ size of buffer in paragraphs
2+                              \ skip over chain verification check word
    2 +FIELD >BBYTES            \ contents of buffer in bytes
    2 +FIELD >BOFF              \ offset where we are in buffer
    1 +FIELD >BHANDLE           \ offset to the file handle structure
DROP

I: ?PTRERROR    ( f1 a1 -- )    \ Error if F1 true, couldn't adjust memory
                swap            \ show error for word a1
                if      BODY>
                        " Failed to allocate memory!" "berrmsg abort
                else    drop
                then    ;

\ **********************************************************************
\       Default buffered handle buffer size control words
\ **********************************************************************

     2048 value def_bsize       \ default read/write buffer size in bytes
def_bsize value b_size          \ buffered read size used in handle creation
        0 value b_exseg         \ extended read/write segment temporary var

\ **********************************************************************
\       Define "name" as a buffered handle for read or write
\ **********************************************************************

: BHANDLE       ( -<name>- )                    \ make a pointer "name"
                ( -- addr )                     \ it's structure
                CREATE                          \ make the name
                0 ,                             \ initialize read to NULL
                HERE  PHEAD @ ,  PHEAD !        \ link into chain
                B_SIZE PARAGRAPH ,              \ buffer size in paragraphs
( tjz 07/28/91) PHEAD @ ,       \ extra POINTER CHAIN verification word
                0 ,                             \ bytes in buffer
                0 ,                             \ buffer offset
                HERE B/HCB ALLOT CLR-HCB        \ space for handle
                DEF_BSIZE !> B_SIZE             \ restore default buffer size
                DOES> DUP>R >BSEG @ 0=
                   IF      ?CS: R@ >BSIZE @ 0 #PARS @ 0 D+ $FFFF 0 DMIN DROP
                           SETBLOCK R@ ?PTRERROR
                                                \ adjust F-PC's memory usage
                           ?CS: #PARS @ + R@ >BSEG !
                                                \ install physical seg
                           R@ >BSIZE @ #PARS +!
                                                \ adj total paragraphs
                           0 R@ >BOFF !         \ clear buffer offset
                   THEN    R> ;                 \ return handles structure
                                                \ address

: BREFILL       ( bhandle -- )  \ refill the buffered file handle
                dup>r >bbytes @
                if      r@ >bseg @ r@ >boff @ over 0 r@ >bbytes @ cmovel
                then    0 r@ >boff !
                r@ >bbytes @ r@ >bsize @ 16 * over -
                r@ >bhandle r@ >bseg @ exhread r> >bbytes +! ;

: BFLUSH        ( bhandle -- )  \ Flush the buffered data to file handle
                >r 0 r@ >boff @ r@ >bhandle r@ >bseg @ exhwrite
                r@ >boff @ <>
                if      r@ " Buffered write error" "berrmsg abort
                then    0 r@ >boff ! r@ >bsize @ 16 * r> >bbytes ! ;

: BEMPTY        ( bhandle -- )  \ discard the contents of the buffered handle
                >r 0 r@ >bbytes !               \ set remaining to zero
                r@ >bsize @ 16 * r> >boff ! ;   \ set OFFSET to end of buffer

: BMOVEPOINTER  ( d1 bhandle -- )       \ position to d1 offset into bhandle
                dup bempty              \ discard current buffers contents
                >bhandle movepointer ;  \ adjust the file pointer

: %BREAD        ( a1 n1 bhandle -- n2 )  \ buffered file read
                dup>r >bbytes @ over u>=        \ if buffer has enough bytes
                if      r@ >bseg @ r@ >boff @ 2swap b_exseg -rot
                        dup r@ >boff +!                 \ increase offset
                        dup negate r@ >bbytes +!        \ reduce remainder
                        dup>r cmovel                    \ move the data
                        r>                              \ bytes read
                else                            \ else refill the buffer
                        over r@ >bseg @ r@ >boff @ rot b_exseg swap
                        r@ >bbytes @ dup>r cmovel
                        r> dup r@ >boff +!              \ mark as empty
                        0 r@ >bbytes !                  \ start empty
                        r@ brefill                      \ refill buffer
                        dup>r -rot r> /string           \ remove read part
                        r@ >bbytes @            \ any bytes from BREFILL?
                        if      r@ RECURSIVE %bread +
                        else    2drop                   \ -- n1
                        then
                then    r>drop ;

: EXBREAD       ( a1 n1 bhandle seg -- n1 )     \ read into seg
                !> b_exseg %bread ;

: BREAD         ( a1 n1 bhandle -- n1 )         \ read into CS:
                ?cs: !> b_exseg %bread ;

: %BWRITE       ( a1 n1 bhandle -- )    \ buffered file write
                >r dup r@ >bbytes @ u<           \ if there is room in buffer
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
                        r@ RECURSIVE %bwrite
                then    r>drop ;

: EXBWRITE      ( a1 n1 bhandle seg -- )        \ write from seg
                !> b_exseg %bwrite ;

: BWRITE        ( a1 n1 bhandle -- )            \ write from CS:
                ?cs: !> b_exseg %bwrite ;

: BCLOSE        ( bhandle -- f1 )       \ close the buffered file
                dup>r >bhandle hclose           \ -- f1 return error flag
                r> body> %unpointer ;           \ release buffer memory

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
                if      r@ >boff @ r@ >bbytes @ 2dup term_char scan
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



}

