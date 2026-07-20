\ sz-edit.fth — SZ-EDITOR interactive loop (Phase 4)
\
\ Keys (Control = ⌃, not Command/Apple ⌘):
\   printable     insert
\   Enter         CRLF
\   BS / Del      backspace
\   arrows        move (host maps to same codes as Ctrl-B/F/N/P)
\   Ctrl-B/F      left / right
\   Ctrl-P/N      up / down
\   Ctrl-S        save
\   Ctrl-Q        quit
\
\ Depends on: sz-host, sz-buffer, sz-screen

DECIMAL

  2 CONSTANT SZ-CTRL-B
  6 CONSTANT SZ-CTRL-F
  8 CONSTANT SZ-BS
 10 CONSTANT SZ-LF-KEY
 13 CONSTANT SZ-ENTER
 14 CONSTANT SZ-CTRL-N
 16 CONSTANT SZ-CTRL-P
 17 CONSTANT SZ-CTRL-Q
 19 CONSTANT SZ-CTRL-S
127 CONSTANT SZ-DEL

VARIABLE SZ-DONE

\ -----------------------------------------------------------------------------
\ Insert / delete at SZ-CUR
\ -----------------------------------------------------------------------------

\ Open u bytes at SZ-CUR (shift tail right). Uses MOVE (overlap-safe).
\ flag true on success.
: SZ-OPEN-HOLE  ( u -- flag )
   DUP SZ-FREE-BYTES > IF  DROP 0 EXIT  THEN
   DUP 0= IF  DROP -1 EXIT  THEN
   >R                                   \ R: u
   SZ-TEND SZ-CUR @ -                   \ n = bytes after cursor
   DUP 0> IF
      \ ( n )  MOVE ( src dest u ) — shift [CUR,TEND) to [CUR+u,TEND+u)
      SZ-CUR @                          \ n src
      SZ-CUR @ R@ +                     \ n src dest
      ROT                               \ src dest n
      MOVE
   ELSE
      DROP
   THEN
   R@ SZ-TLEN +!
   R> DROP
   -1
;

: SZ-INSERT-CH  ( c -- )
   \ only store printable and tab
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
   SZ-TEND SZ-CUR @ - 1-                    \ bytes after the deleted char
   DUP 0> IF
      SZ-CUR @ 1+  SZ-CUR @  ROT  MOVE      \ src dest u
   ELSE
      DROP
   THEN
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

\ -----------------------------------------------------------------------------
\ Save / quit
\ -----------------------------------------------------------------------------

: SZ-DO-SAVE  ( -- )
   SZ-HAS-NAME? 0= IF
      SZ-TEXT-BOT 1+ SZ-BLANK-ROW
      0 SZ-TEXT-BOT 1+ AT-XY
      .( no filename — use SZ-SAVE-AS after quit)
      TERMINAL-REFRESH
      EXIT
   THEN
   SZ-SAVE IF
      SZ-TEXT-BOT 1+ SZ-BLANK-ROW
      0 SZ-TEXT-BOT 1+ AT-XY
      .( SAVE failed)
      TERMINAL-REFRESH
   ELSE
      SZ-TEXT-BOT 1+ SZ-BLANK-ROW
      0 SZ-TEXT-BOT 1+ AT-XY
      .( saved )
      SZ-GET-NAME TYPE
      .(  ) SZ-TLEN @ 0 .R .( b)
      TERMINAL-REFRESH
   THEN
;

: SZ-CONFIRM-QUIT  ( -- flag )
   SZ-MODIFIED @ 0= IF  -1 EXIT  THEN
   SZ-TEXT-BOT 1+ SZ-BLANK-ROW
   0 SZ-TEXT-BOT 1+ AT-XY
   .( Modified! Quit without save? y/N )
   TERMINAL-REFRESH
   KEY
   DUP [CHAR] y =  SWAP [CHAR] Y =  OR
;

: SZ-DO-QUIT  ( -- )
   SZ-CONFIRM-QUIT IF  -1 SZ-DONE !  THEN
;

\ -----------------------------------------------------------------------------
\ Dispatch — motion and controls first; never insert control codes
\ -----------------------------------------------------------------------------

: SZ-HANDLE-KEY  ( c -- )
   \ strip any high bits if host ever sends them
   255 AND
   DUP SZ-CTRL-Q = IF  DROP SZ-DO-QUIT EXIT  THEN
   DUP SZ-CTRL-S = IF  DROP SZ-DO-SAVE EXIT  THEN
   DUP SZ-CTRL-B = IF  DROP SZ-GO-LEFT EXIT  THEN
   DUP SZ-CTRL-F = IF  DROP SZ-GO-RIGHT EXIT  THEN
   DUP SZ-CTRL-P = IF  DROP SZ-GO-UP EXIT  THEN
   DUP SZ-CTRL-N = IF  DROP SZ-GO-DOWN EXIT  THEN
   DUP SZ-BS = IF  DROP SZ-BACKSPACE EXIT  THEN
   DUP SZ-DEL = IF  DROP SZ-BACKSPACE EXIT  THEN
   DUP SZ-ENTER = IF  DROP SZ-INSERT-CRLF EXIT  THEN
   DUP SZ-LF-KEY = IF  DROP SZ-INSERT-CRLF EXIT  THEN
   \ printable only
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
   \ Always leave facility mode before any console output / CLS.
   FACILITY-OFF
   CLS
   .( SZ-EDITOR: done) CR
   SZ-MODIFIED @ IF  .( warning: buffer still modified) CR  THEN
   SZ-.INFO
;

: SZ-EDIT  ( -- )  SZ-EDIT-LOOP ;

: SZ-EDIT-FILE  ( c-addr u -- )
   SZ-LOAD IF  .( SZ-EDIT-FILE: load failed) CR EXIT  THEN
   SZ-EDIT
;

: SZ-EDIT"  ( -- )
   [CHAR] " PARSE SZ-EDIT-FILE
;

: SZ-EDIT-SMOKE  ( -- )
   S" sz-smoke-out.txt" SZ-LOAD
   IF  .( SZ-EDIT-SMOKE: load a file or run SZ-BUFFER-SMOKE first) CR EXIT  THEN
   SZ-EDIT
;
