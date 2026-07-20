\ sz-buffer.fth — SZ-EDITOR single text buffer + load/save (Phase 2)
\
\ One in-memory document. Lines may end with CR LF or LF (preserved as stored).
\ Byte addresses are cell values pointing into SZ-TBUF.
\
\ Prerequisites: sz-host.fth (or full File-Access already in dictionary)
\
\ Quick test (from a writable cwd, after loading modules):
\   S" notes.txt" SZ-LOAD-FILE THROW
\   SZ-.INFO
\   S" notes-copy.txt" SZ-SAVE-AS THROW
\   SZ-.INFO

DECIMAL

\ -----------------------------------------------------------------------------
\ Limits
\ -----------------------------------------------------------------------------

  262144 CONSTANT SZ-TBUF-SIZE     \ max file size (bytes) for this pass
     255 CONSTANT SZ-NAME-MAX      \ counted path capacity

\ -----------------------------------------------------------------------------
\ Storage
\ -----------------------------------------------------------------------------

CREATE SZ-TBUF  SZ-TBUF-SIZE ALLOT
VARIABLE SZ-TLEN                   \ used bytes in SZ-TBUF (0..SZ-TBUF-SIZE)
VARIABLE SZ-MODIFIED               \ nonzero if buffer dirty
CREATE SZ-FNAME  256 ALLOT         \ counted path of current file (0 = untitled)

\ -----------------------------------------------------------------------------
\ Buffer basics
\ -----------------------------------------------------------------------------

: SZ-TBUF0      ( -- addr )  SZ-TBUF ;
: SZ-TEND       ( -- addr )  SZ-TBUF SZ-TLEN @ + ;   \ one past last byte

: SZ-CLEAR-BUF  ( -- )
   0 SZ-TLEN !
   0 SZ-MODIFIED !
   0 SZ-FNAME C! ;

: SZ-EMPTY?     ( -- flag )  SZ-TLEN @ 0= ;
: SZ-FULL?      ( -- flag )  SZ-TLEN @ SZ-TBUF-SIZE = ;

\ ( -- free )  bytes free in buffer
: SZ-FREE-BYTES ( -- n )  SZ-TBUF-SIZE SZ-TLEN @ - ;

: SZ-TOUCH      ( -- )  -1 SZ-MODIFIED ! ;
: SZ-CLEAN      ( -- )   0 SZ-MODIFIED ! ;

\ Copy path into SZ-FNAME (counted)
: SZ-SET-NAME   ( c-addr u -- )
   SZ-FNAME SZ-PLACE ;

: SZ-GET-NAME   ( -- c-addr u )
   SZ-FNAME COUNT ;

: SZ-HAS-NAME?  ( -- flag )
   SZ-FNAME C@ 0<> ;

\ -----------------------------------------------------------------------------
\ Line scan (inspired by SmallZimmerEditor nextlf/prevlf/parse_line)
\ -----------------------------------------------------------------------------

$0A CONSTANT SZ-CH-LF
$0D CONSTANT SZ-CH-CR

\ ( addr -- addr' )  address of LF at/after addr, or SZ-TEND if none
: SZ-NEXTLF  ( addr -- addr' )
   DUP SZ-TEND SZ-U>= IF  DROP SZ-TEND EXIT  THEN
   BEGIN
      DUP C@ SZ-CH-LF = IF  EXIT  THEN
      1+
      DUP SZ-TEND SZ-U>=
   UNTIL
   DROP SZ-TEND ;

\ ( addr -- addr' )  start of current line (byte after previous LF, or buffer start)
: SZ-LINE-START  ( addr -- addr' )
   DUP SZ-TBUF SZ-U<= IF  DROP SZ-TBUF EXIT  THEN
   BEGIN
      1-  DUP SZ-TBUF U< IF  DROP SZ-TBUF EXIT  THEN
      DUP C@ SZ-CH-LF =
   UNTIL
   1+ ;

\ ( line-start -- line-start u )  length of line body (not including CR/LF)
: SZ-PARSE-LINE  ( addr -- addr u )
   DUP SZ-NEXTLF  ( a aLF )
   OVER -         ( a nincl-LF? )  \ distance to LF (0 if a=LF)
   \ strip trailing CR if present
   DUP IF
      2DUP + 1- C@ SZ-CH-CR = IF  1-  THEN
   THEN
   ;

\ ( -- n )  number of lines (empty buffer => 0; no final LF still counts last line)
\ Note: DO is ( limit start -- ) with start on top — not ( start limit ).
: SZ-LINE-COUNT  ( -- n )
   SZ-TLEN @ 0= IF  0 EXIT  THEN
   0  SZ-TBUF                    \ count addr
   BEGIN
      DUP SZ-TEND U<             \ addr still in buffer?
   WHILE
      DUP C@ SZ-CH-LF = IF  SWAP 1+ SWAP  THEN
      1+
   REPEAT
   DROP
   \ if buffer does not end with LF, last partial line still counts
   SZ-TEND 1- C@ SZ-CH-LF <> IF  1+  THEN
;

\ -----------------------------------------------------------------------------
\ Load / save
\ -----------------------------------------------------------------------------

\ Read entire file into buffer. ior = 0 success.
\ On success: sets length, clears modified. Truncates if file > buffer
\ (reads at most SZ-TBUF-SIZE bytes). Does not change SZ-FNAME.
: SZ-LOAD-FILE  ( c-addr u -- ior )
   R/O OPEN-FILE                 ( fileid ior )
   DUP 0<> IF  NIP EXIT  THEN    \ open failed — leave ior only
   DROP >R                       ( R: fid )
   SZ-TBUF SZ-TBUF-SIZE R@ READ-FILE  ( u2 ior )
   ?DUP IF  R> CLOSE-FILE DROP EXIT  THEN
   SZ-TBUF-SIZE MIN  SZ-TLEN !
   R> CLOSE-FILE DROP
   SZ-CLEAN
   0
;

\ Load and remember name (c-addr u is path)
: SZ-LOAD  ( c-addr u -- ior )
   2DUP SZ-SET-NAME
   SZ-LOAD-FILE
   DUP IF  0 SZ-FNAME C!  THEN     \ clear name on failure
;

\ Parse name from input and load:  SZ-LOAD" path"
: SZ-LOAD"  ( -- ior )
   [CHAR] " PARSE  SZ-LOAD
;

\ Save buffer to open path in SZ-FNAME. ior = 0 success.
: SZ-SAVE  ( -- ior )
   SZ-HAS-NAME? 0= IF  -1 EXIT  THEN   \ no name
   SZ-GET-NAME W/O CREATE-FILE       ( fileid ior )
   DUP 0<> IF  NIP EXIT  THEN
   DROP >R
   SZ-TBUF SZ-TLEN @ R@ WRITE-FILE   ( ior )
   ?DUP IF  R> CLOSE-FILE DROP EXIT  THEN
   R> CLOSE-FILE
   DUP 0= IF  SZ-CLEAN  THEN
;

\ Save to a new name (updates SZ-FNAME on success)
: SZ-SAVE-AS  ( c-addr u -- ior )
   2DUP SZ-SET-NAME
   SZ-SAVE
   DUP IF  0 SZ-FNAME C!  THEN
;

: SZ-SAVE-AS"  ( -- ior )
   [CHAR] " PARSE  SZ-SAVE-AS
;

\ -----------------------------------------------------------------------------
\ Status / smoke test
\ -----------------------------------------------------------------------------

: SZ-.INFO  ( -- )
   .( SZ-buffer: )
   SZ-HAS-NAME? IF  SZ-GET-NAME TYPE  ELSE  .( untitled)  THEN
   .(  bytes=) SZ-TLEN @ 0 .R
   .(  lines=) SZ-LINE-COUNT 0 .R
   .(  free=) SZ-FREE-BYTES 0 .R
   SZ-MODIFIED @ IF  .(  *modified*)  THEN
   CR
;

\ Dump buffer contents to the console (for verifying edits / save).
: SZ-TYPE-BUF  ( -- )
   SZ-TBUF SZ-TLEN @ TYPE CR
;

\ Re-load the current file from disk into the buffer (discards unsaved edits).
\ Useful after ⌃S + ⌃Q to prove the file on disk matches what you typed.
: SZ-RELOAD  ( -- ior )
   SZ-HAS-NAME? 0= IF  -1 EXIT  THEN
   SZ-GET-NAME SZ-LOAD-FILE
;

\ Two-byte CRLF helper (avoids depending on S\" escapes)
CREATE SZ-CRLF  SZ-CH-CR C, SZ-CH-LF C,

\ Write a short scratch file, load it, report, save a copy (needs writable cwd).
: SZ-BUFFER-SMOKE  ( -- )
   S" sz-smoke-out.txt" W/O CREATE-FILE  ( fid ior )
   DUP 0<> IF  .( sz-buffer smoke: CREATE failed ior=) . CR NIP EXIT  THEN
   DROP >R
   S" line1" R@ WRITE-FILE DROP
   SZ-CRLF 2 R@ WRITE-FILE DROP
   S" line2" R@ WRITE-FILE DROP
   SZ-CRLF 2 R@ WRITE-FILE DROP
   R> CLOSE-FILE DROP
   S" sz-smoke-out.txt" SZ-LOAD
   DUP IF  .( sz-buffer smoke: LOAD failed ior=) . CR EXIT  THEN  DROP
   SZ-.INFO
   S" sz-smoke-copy.txt" SZ-SAVE-AS
   DUP IF  .( sz-buffer smoke: SAVE-AS failed ior=) . CR EXIT  THEN  DROP
   .( sz-buffer: OK - load/save smoke wrote sz-smoke-out.txt and sz-smoke-copy.txt) CR
;
