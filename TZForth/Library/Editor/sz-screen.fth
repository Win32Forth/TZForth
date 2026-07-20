\ sz-screen.fth — SZ-EDITOR mono display / scroll (Phase 5 frame + cursor)
\
\ Uses Facility PAGE/AT-XY/EMIT, then TERMINAL-REFRESH once per frame so the
\ host paints the full screen (PAGE alone must not flush an empty buffer).
\
\ Layout (0-based rows, 80 cols):
\   row 0        status
\   row 1        top border  +----...----+
\   rows 2..21   text        | body...  |   (20 rows × 78 cols)
\   row 22       bottom border
\   row 23       help
\
\ Depends on: sz-host.fth, sz-buffer.fth

DECIMAL

  80 CONSTANT SZ-COLS
   1 CONSTANT SZ-FRAME-TOP
  22 CONSTANT SZ-FRAME-BOT
   2 CONSTANT SZ-TEXT-TOP
  21 CONSTANT SZ-TEXT-BOT
   1 CONSTANT SZ-TEXT-LEFT      \ first column of text body
  78 CONSTANT SZ-TEXT-WIDTH

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

\ Keep SZ-CUR's line in the text window without O(n²) scroll-down walks.
\ Jumping to end of a large file used to call SZ-SCROLL-DOWN + SZ-LINE-STEPS
\ once per line and hit STEP-LIMIT, aborting the editor (looked like Ctrl-End quit).
: SZ-ENSURE-VISIBLE  ( -- )
   SZ-CUR-LINE >R                         \ R: cursor line start
   \ Cursor above window → snap top to that line
   R@ SZ-TOP @ U< IF  R@ SZ-TOP !  THEN
   \ Cursor too far below top → put it on the last visible row
   SZ-TOP @ R@ SZ-LINE-STEPS
   SZ-TEXT-ROWS 1- > IF
      R@                                  \ walk back TEXT-ROWS-1 line starts
      SZ-TEXT-ROWS 1- 0 ?DO
         DUP SZ-TBUF = IF  LEAVE  THEN
         1- SZ-LINE-START
      LOOP
      SZ-TOP !
   THEN
   R> DROP
;

: SZ-BLANK-ROW  ( row -- )
   0 SWAP AT-XY
   SZ-COLS 0 DO  BL EMIT  LOOP ;

\ Horizontal rule: +----...----+  (width SZ-COLS)
: SZ-DRAW-HBAR  ( row -- )
   0 SWAP AT-XY
   [CHAR] + EMIT
   SZ-COLS 2 - 0 DO  [CHAR] - EMIT  LOOP
   [CHAR] + EMIT
;

: SZ-DRAW-FRAME  ( -- )
   SZ-FRAME-TOP SZ-DRAW-HBAR
   SZ-FRAME-BOT SZ-DRAW-HBAR
   SZ-TEXT-BOT 1+ SZ-TEXT-TOP DO
      0 I AT-XY  [CHAR] | EMIT
      SZ-COLS 1- I AT-XY  [CHAR] | EMIT
   LOOP
;

: SZ-SHOW-LINE  ( line-addr row -- )
   SZ-TEXT-LEFT SWAP AT-XY
   SZ-PARSE-LINE SZ-TEXT-WIDTH MIN
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
   .( SZ-EDITOR )
   SZ-HAS-NAME? IF  SZ-GET-NAME TYPE  ELSE  .( untitled)  THEN
   SZ-MODIFIED @ IF  .(  *)  THEN
   .(  c) SZ-CUR-COL 1+ 0 .R
   .(  ) SZ-TLEN @ 0 .R .( b)
;

: SZ-SHOW-HELP  ( -- )
   SZ-TEXT-BOT 2 + SZ-BLANK-ROW
   0 SZ-TEXT-BOT 2 + AT-XY
   .( ^S save ^Q quit  arrows  Home/End  ^Home/^End  PgUp/Dn  BS Del  type)
;

\ Place Facility cursor on the insert cell (host reverse-videos it).
: SZ-PLACE-CURSOR  ( -- )
   SZ-CUR-COL SZ-TEXT-WIDTH 1- MIN  SZ-TEXT-LEFT +
   SZ-TOP @ SZ-CUR-LINE SZ-LINE-STEPS SZ-TEXT-TOP +
   SZ-TEXT-BOT MIN
   AT-XY
;

: SZ-REDRAW  ( -- )
   SZ-ENSURE-VISIBLE
   PAGE
   SZ-SHOW-STATUS
   SZ-DRAW-FRAME
   SZ-TOP @
   SZ-TEXT-BOT 1+ SZ-TEXT-TOP DO
      DUP SZ-TEND SZ-U>= IF
         \ empty text row inside frame — leave spaces between |
      ELSE
         DUP I SZ-SHOW-LINE
         SZ-NEXTLF
         DUP SZ-TEND <> IF  1+  THEN
      THEN
   LOOP
   DROP
   SZ-SHOW-HELP
   SZ-PLACE-CURSOR
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
