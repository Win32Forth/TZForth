\ sz-edit.fth — SZ-EDITOR interactive loop (Phase 5 navigation)
\
\ Keys (Control = ⌃, not Command/Apple ⌘):
\   printable       insert
\   Enter           CRLF
\   BS              backspace
\   Del / Ctrl-D    delete under cursor
\   arrows          move (host delivers codes 2/6/14/16)
\   Home / Ctrl-A   start of line
\   End  / Ctrl-E   end of line
\   Ctrl-Home       start of file
\   Ctrl-End        end of file
\   PgUp / PgDn     page up / down
\   Ctrl-S          save
\   Ctrl-Q          quit
\
\ Depends on: sz-host, sz-buffer, sz-screen

DECIMAL

  1 CONSTANT SZ-HOME-LINE      \ Ctrl-A / Home
  2 CONSTANT SZ-LEFT           \ ← arrow (host)
  4 CONSTANT SZ-DEL-FWD        \ Ctrl-D / forward delete
  5 CONSTANT SZ-END-LINE       \ Ctrl-E / End
  6 CONSTANT SZ-RIGHT          \ → arrow (host)
  8 CONSTANT SZ-BS
 10 CONSTANT SZ-LF-KEY
 13 CONSTANT SZ-ENTER
 14 CONSTANT SZ-DOWN           \ ↓ arrow (host)
 16 CONSTANT SZ-UP             \ ↑ arrow (host)
 17 CONSTANT SZ-CTRL-Q
 19 CONSTANT SZ-CTRL-S
 23 CONSTANT SZ-PGUP
 24 CONSTANT SZ-PGDN
 28 CONSTANT SZ-HOME-FILE      \ Ctrl-Home
 29 CONSTANT SZ-END-FILE       \ Ctrl-End
127 CONSTANT SZ-DEL            \ also delete-forward (legacy)

VARIABLE SZ-DONE

\ -----------------------------------------------------------------------------
\ Insert / delete at SZ-CUR
\ -----------------------------------------------------------------------------

: SZ-OPEN-HOLE  ( u -- flag )
   DUP SZ-FREE-BYTES > IF  DROP 0 EXIT  THEN
   DUP 0= IF  DROP -1 EXIT  THEN
   >R
   SZ-TEND SZ-CUR @ -
   DUP 0> IF
      SZ-CUR @  SZ-CUR @ R@ +  ROT  MOVE
   ELSE
      DROP
   THEN
   R@ SZ-TLEN +!
   R> DROP
   -1
;

: SZ-INSERT-CH  ( c -- )
   DUP BL < OVER 126 > OR IF  DROP EXIT  THEN
   1 SZ-OPEN-HOLE 0= IF  DROP EXIT  THEN
   SZ-CUR @ C!
   1 SZ-CUR +!
   SZ-TOUCH
;

: SZ-INSERT-CRLF  ( -- )
   2 SZ-OPEN-HOLE 0= IF  EXIT  THEN
   SZ-CH-CR SZ-CUR @ C!
   SZ-CH-LF SZ-CUR @ 1+ C!
   2 SZ-CUR +!
   SZ-TOUCH
;

: SZ-BACKSPACE  ( -- )
   SZ-CUR @ SZ-TBUF = IF  EXIT  THEN
   -1 SZ-CUR +!
   SZ-TEND SZ-CUR @ - 1-
   DUP 0> IF
      SZ-CUR @ 1+  SZ-CUR @  ROT  MOVE
   ELSE
      DROP
   THEN
   -1 SZ-TLEN +!
   SZ-TLEN @ 0< IF  0 SZ-TLEN !  THEN
   SZ-TOUCH
;

\ Delete character(s) under cursor (forward). CRLF pair removed as one unit.
: SZ-DELETE-FWD  ( -- )
   SZ-CUR @ SZ-TEND = IF  EXIT  THEN
   \ CRLF under cursor?
   SZ-CUR @ C@ SZ-CH-CR =
   SZ-CUR @ 1+ SZ-TEND U< AND
   IF
      SZ-CUR @ 1+ C@ SZ-CH-LF = IF
         SZ-TEND SZ-CUR @ - 2 - DUP 0> IF
            SZ-CUR @ 2 +  SZ-CUR @  ROT  MOVE
         ELSE  DROP  THEN
         -2 SZ-TLEN +!
         SZ-TLEN @ 0< IF  0 SZ-TLEN !  THEN
         SZ-TOUCH EXIT
      THEN
   THEN
   \ single byte
   SZ-TEND SZ-CUR @ - 1- DUP 0> IF
      SZ-CUR @ 1+  SZ-CUR @  ROT  MOVE
   ELSE  DROP  THEN
   -1 SZ-TLEN +!
   SZ-TLEN @ 0< IF  0 SZ-TLEN !  THEN
   SZ-TOUCH
;

\ -----------------------------------------------------------------------------
\ Motion only (never mutate buffer)
\ -----------------------------------------------------------------------------

: SZ-GO-LEFT  ( -- )
   SZ-CUR @ SZ-TBUF > IF  -1 SZ-CUR +!  THEN ;

: SZ-GO-RIGHT  ( -- )
   SZ-CUR @ SZ-TEND < IF  1 SZ-CUR +!  THEN ;

: SZ-GO-UP  ( -- )
   SZ-CUR-COL >R
   SZ-CUR-LINE DUP SZ-TBUF = IF  DROP R> DROP EXIT  THEN
   1- SZ-LINE-START
   DUP SZ-PARSE-LINE NIP R@ MIN +
   SZ-CUR !
   R> DROP
;

: SZ-GO-DOWN  ( -- )
   SZ-CUR-COL >R
   SZ-CUR-LINE SZ-NEXTLF
   DUP SZ-TEND = IF  DROP R> DROP EXIT  THEN
   1+ DUP SZ-TEND SZ-U>= IF  DROP R> DROP EXIT  THEN
   DUP SZ-PARSE-LINE NIP R@ MIN +
   SZ-CUR !
   R> DROP
;

: SZ-GO-HOME-LINE  ( -- )
   SZ-CUR-LINE SZ-CUR ! ;

: SZ-GO-END-LINE  ( -- )
   SZ-CUR-LINE SZ-PARSE-LINE + SZ-CUR ! ;

: SZ-GO-HOME-FILE  ( -- )
   SZ-TBUF SZ-CUR ! ;

: SZ-GO-END-FILE  ( -- )
   SZ-TEND SZ-CUR ! ;

: SZ-PAGE-UP  ( -- )
   SZ-TEXT-ROWS 0 DO  SZ-GO-UP  LOOP ;

: SZ-PAGE-DOWN  ( -- )
   SZ-TEXT-ROWS 0 DO  SZ-GO-DOWN  LOOP ;

\ -----------------------------------------------------------------------------
\ Save / quit
\ -----------------------------------------------------------------------------

: SZ-MSG-LINE  ( -- )
   SZ-TEXT-BOT 2 + SZ-BLANK-ROW
   0 SZ-TEXT-BOT 2 + AT-XY
;

: SZ-DO-SAVE  ( -- )
   SZ-HAS-NAME? 0= IF
      SZ-MSG-LINE
      .( no filename — use SZ-SAVE-AS after quit)
      TERMINAL-REFRESH
      EXIT
   THEN
   SZ-SAVE IF
      SZ-MSG-LINE
      .( SAVE failed)
      TERMINAL-REFRESH
   ELSE
      SZ-MSG-LINE
      .( saved )
      SZ-GET-NAME TYPE
      .(  ) SZ-TLEN @ 0 .R .( b)
      TERMINAL-REFRESH
   THEN
;

: SZ-CONFIRM-QUIT  ( -- flag )
   SZ-MODIFIED @ 0= IF  -1 EXIT  THEN
   SZ-MSG-LINE
   .( Modified! Quit without save? y/N )
   TERMINAL-REFRESH
   KEY
   DUP [CHAR] y =  SWAP [CHAR] Y =  OR
;

: SZ-DO-QUIT  ( -- )
   SZ-CONFIRM-QUIT IF  -1 SZ-DONE !  THEN
;

\ -----------------------------------------------------------------------------
\ Dispatch
\ -----------------------------------------------------------------------------

: SZ-HANDLE-KEY  ( c -- )
   255 AND
   DUP SZ-CTRL-Q = IF  DROP SZ-DO-QUIT EXIT  THEN
   DUP SZ-CTRL-S = IF  DROP SZ-DO-SAVE EXIT  THEN
   DUP SZ-LEFT = IF  DROP SZ-GO-LEFT EXIT  THEN
   DUP SZ-RIGHT = IF  DROP SZ-GO-RIGHT EXIT  THEN
   DUP SZ-UP = IF  DROP SZ-GO-UP EXIT  THEN
   DUP SZ-DOWN = IF  DROP SZ-GO-DOWN EXIT  THEN
   DUP SZ-HOME-LINE = IF  DROP SZ-GO-HOME-LINE EXIT  THEN
   DUP SZ-END-LINE = IF  DROP SZ-GO-END-LINE EXIT  THEN
   DUP SZ-HOME-FILE = IF  DROP SZ-GO-HOME-FILE EXIT  THEN
   DUP SZ-END-FILE = IF  DROP SZ-GO-END-FILE EXIT  THEN
   DUP SZ-PGUP = IF  DROP SZ-PAGE-UP EXIT  THEN
   DUP SZ-PGDN = IF  DROP SZ-PAGE-DOWN EXIT  THEN
   DUP SZ-BS = IF  DROP SZ-BACKSPACE EXIT  THEN
   DUP SZ-DEL-FWD = IF  DROP SZ-DELETE-FWD EXIT  THEN
   DUP SZ-DEL = IF  DROP SZ-DELETE-FWD EXIT  THEN
   DUP SZ-ENTER = IF  DROP SZ-INSERT-CRLF EXIT  THEN
   DUP SZ-LF-KEY = IF  DROP SZ-INSERT-CRLF EXIT  THEN
   DUP BL < IF  DROP EXIT  THEN
   DUP 127 < IF  SZ-INSERT-CH EXIT  THEN
   DROP
;

: SZ-EDIT-LOOP  ( -- )
   0 SZ-DONE !
   SZ-VIEW-RESET
   BEGIN
      SZ-DONE @ 0=
   WHILE
      SZ-REDRAW
      KEY SZ-HANDLE-KEY
   REPEAT
   FACILITY-OFF
   CLS
   .( SZ-EDITOR: done) CR
   SZ-MODIFIED @ IF  .( warning: buffer still modified) CR  THEN
   SZ-.INFO
;

: SZ-EDIT-FILE  ( c-addr u -- )
   SZ-LOAD IF  .( SZ-EDIT-FILE: load failed) CR EXIT  THEN
   SZ-EDIT-LOOP
;

\ Parse a path and edit. With FROMLIB on the same console line, relative
\ names resolve under Resources/Library (OPEN-FILE honors FROM-LIBRARY):
\   FROMLIB SZEDIT Editor/SZ-EDITOR-README.txt
: SZEDIT  ( -- )  BL WORD COUNT SZ-EDIT-FILE ;
