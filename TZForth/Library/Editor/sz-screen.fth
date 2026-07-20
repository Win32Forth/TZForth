\ sz-screen.fth — SZ-EDITOR mono display / scroll (Phase 3)
\
\ Uses Facility PAGE/AT-XY/EMIT, then TERMINAL-REFRESH once per frame so the
\ host paints the full screen (PAGE alone must not flush an empty buffer).
\
\ Depends on: sz-host.fth, sz-buffer.fth

DECIMAL

  80 CONSTANT SZ-COLS
   1 CONSTANT SZ-TEXT-TOP
  22 CONSTANT SZ-TEXT-BOT

VARIABLE SZ-TOP
VARIABLE SZ-CUR

: SZ-TEXT-ROWS  ( -- n )  SZ-TEXT-BOT SZ-TEXT-TOP - 1+ ;

: SZ-VIEW-RESET  ( -- )
   SZ-TBUF DUP SZ-CUR !  SZ-TOP !
;

: SZ-CUR-COL  ( -- col )
   SZ-CUR @ SZ-LINE-START  SZ-CUR @ SWAP - ;

: SZ-CUR-LINE  ( -- addr )
   SZ-CUR @ SZ-LINE-START ;

: SZ-SCROLL-UP  ( -- )
   SZ-TOP @ SZ-TBUF = IF  EXIT  THEN
   SZ-TOP @ 1- SZ-LINE-START SZ-TOP !
;

: SZ-SCROLL-DOWN  ( -- )
   SZ-TOP @ SZ-NEXTLF
   DUP SZ-TEND = IF  DROP EXIT  THEN
   1+ DUP SZ-TEND SZ-U>= IF  DROP EXIT  THEN
   SZ-TOP !
;

: SZ-LINE-STEPS  ( from to -- n )
   0 >R
   BEGIN
      OVER OVER U<
   WHILE
      SWAP SZ-NEXTLF 1+ SWAP
      R> 1+ >R
   REPEAT
   2DROP R>
;

: SZ-ENSURE-VISIBLE  ( -- )
   BEGIN  SZ-CUR-LINE SZ-TOP @ U<  WHILE  SZ-SCROLL-UP  REPEAT
   BEGIN
      SZ-TOP @ SZ-CUR-LINE SZ-LINE-STEPS
      SZ-TEXT-ROWS 1- >
   WHILE
      SZ-SCROLL-DOWN
   REPEAT
;

: SZ-BLANK-ROW  ( row -- )
   0 SWAP AT-XY
   SZ-COLS 0 DO  BL EMIT  LOOP ;

: SZ-SHOW-LINE  ( line-addr row -- )
   0 SWAP AT-XY
   SZ-PARSE-LINE SZ-COLS MIN
   DUP 0= IF  2DROP EXIT  THEN
   0 DO
      DUP I + C@
      DUP SZ-CH-CR = IF  DROP BL  THEN
      EMIT
   LOOP
   DROP
;

: SZ-SHOW-STATUS  ( -- )
   0 SZ-BLANK-ROW
   0 0 AT-XY
   .( SZ )
   SZ-HAS-NAME? IF  SZ-GET-NAME TYPE  ELSE  .( untitled)  THEN
   SZ-MODIFIED @ IF  .(  *)  THEN
   .(  c) SZ-CUR-COL 1+ 0 .R
   .(  ) SZ-TLEN @ 0 .R .( b)
;

: SZ-SHOW-HELP  ( -- )
   SZ-TEXT-BOT 1+ SZ-BLANK-ROW
   0 SZ-TEXT-BOT 1+ AT-XY
   .( Ctrl-S save  Ctrl-Q quit  arrows or Ctrl-B/F/P/N  type  BS)
;

\ Draw a visible insert marker at SZ-CUR (underscore). The macOS text-view caret
\ stays at the bottom of the console; this is the real editor cursor.
: SZ-PAINT-CURSOR  ( -- )
   SZ-CUR-COL SZ-COLS 1- MIN
   SZ-TOP @ SZ-CUR-LINE SZ-LINE-STEPS SZ-TEXT-TOP +
   SZ-TEXT-BOT MIN
   ( col row )
   2DUP AT-XY
   [CHAR] _ EMIT
   AT-XY
;

: SZ-REDRAW  ( -- )
   SZ-ENSURE-VISIBLE
   PAGE
   SZ-SHOW-STATUS
   SZ-TOP @
   SZ-TEXT-BOT 1+ SZ-TEXT-TOP DO
      DUP SZ-TEND SZ-U>= IF
         I SZ-BLANK-ROW
      ELSE
         DUP I SZ-SHOW-LINE
         SZ-NEXTLF
         DUP SZ-TEND <> IF  1+  THEN
      THEN
   LOOP
   DROP
   SZ-SHOW-HELP
   SZ-PAINT-CURSOR
   TERMINAL-REFRESH
;

: SZ-SCREEN-SMOKE  ( -- )
   S" sz-smoke-out.txt" SZ-LOAD DROP
   SZ-VIEW-RESET
   SZ-REDRAW
   KEY DROP
   FACILITY-OFF
   CLS
   .( sz-screen: OK) CR
;
