\ TBLOCK.SEQ            Virtual BLOCK system for TCOM   by Tom Zimmer

comment:

  This is a very simple BLOCK system, supporting only a single buffer
at present. Be sure to use EMPTY-BUFFERS before using any other BLOCK
word.

comment;

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

1024 value b/buf
   0 value blkbuf
    handle blkhndl
  variable updated
  variable blk

: save-buffers  ( -- )
                blk @ 0< ?exit
                updated @
                if      blk @ b/buf *d blkhndl movepointer
                        blkbuf b/buf blkhndl hwrite drop
                        updated off
                then    ;

: flush         ( -- )
                save-buffers -1 blk ! ;

: buffer        ( n1 -- a1 )
                save-buffers
                blk ! blkbuf ;

: block         ( n1 -- a1 )
                blk @ over <>
                if      save-buffers
                        dup blk !
                        b/buf *d blkhndl movepointer
                        blkbuf b/buf blkhndl hread drop
                else    drop
                then    blkbuf ;

: update        ( -- )
                updated on ;

: empty-buffers ( -- )
                updated off
                -1 blk !
                blkbuf 0=       \ allocate some buffer space the first time
                if      b/buf ds:alloc =: blkbuf
                then    ;

FORTH TARGET >TARGET

