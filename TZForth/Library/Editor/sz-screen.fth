\ sz-screen.fth — SZ-EDITOR mono display / scroll (Phase 5 frame + cursor)
\
\ Uses Facility PAGE/AT-XY/EMIT, then TERMINAL-REFRESH once per frame so the
\ host paints the full screen (PAGE alone must not flush an empty buffer).
\
\ Layout (0-based rows, 108 cols — facility default matches):
\   row 0        status
\   row 1        top border  +----...----+
\   rows 2..21   text        |NNNNN|body (100 cols)...|
\   row 22       bottom border
\   row 23       help
\
\ Text body is exactly SZ-TEXT-WIDTH (100) columns — not reduced for the gutter.
\
\ Depends on: sz-host.fth, sz-buffer.fth

DECIMAL

 108 CONSTANT SZ-COLS           \ full facility width: | gutter | text100 |
   1 CONSTANT SZ-FRAME-TOP
  22 CONSTANT SZ-FRAME-BOT
   2 CONSTANT SZ-TEXT-TOP
  21 CONSTANT SZ-TEXT-BOT
   1 CONSTANT SZ-LN-COL         \ first column of line-number gutter
   5 CONSTANT SZ-LN-WIDTH       \ digits (right-justified; blank if past EOF)
   6 CONSTANT SZ-LN-SEP         \ column of | between gutter and text
   7 CONSTANT SZ-TEXT-LEFT      \ first column of text body
 100 CONSTANT SZ-TEXT-WIDTH     \ exact editable text columns

\ SZ-CUR / SZ-TOP are defined in sz-buffer.fth (needed by SZ-ENSURE-CAP).

VARIABLE SZ-HCOL                   \ leftmost visible text column (horizontal scroll)
VARIABLE SZ-DRAW-LNO               \ running 1-based line # while painting (not on R stack)
VARIABLE SZ-SAVE-BASE              \ BASE save for gutter (avoid R stack inside DO)

: SZ-TEXT-ROWS  ( -- n )  SZ-TEXT-BOT SZ-TEXT-TOP - 1+ ;

: SZ-VIEW-RESET  ( -- )
   SZ-TBUF DUP SZ-CUR !  SZ-TOP !
   0 SZ-HCOL !
;

: SZ-CUR-COL  ( -- col )
   SZ-CUR @ SZ-LINE-START  SZ-CUR @ SWAP - ;

: SZ-CUR-LINE  ( -- addr )
   SZ-CUR @ SZ-LINE-START ;

\ Count line starts from addr `from` up to (not past) `to`. Must precede SZ-LINE-NO.
\ Uses a variable — must not nest on R inside callers that also use R.
VARIABLE SZ-STEP-N
: SZ-LINE-STEPS  ( from to -- n )
   0 SZ-STEP-N !
   BEGIN
      OVER OVER U<
   WHILE
      SWAP SZ-NEXTLF 1+ SWAP
      1 SZ-STEP-N +!
   REPEAT
   2DROP SZ-STEP-N @
;

\ 1-based line number of a line-start address (empty buffer => 1).
: SZ-LINE-NO  ( line-addr -- n )
   SZ-TBUF SWAP SZ-LINE-STEPS 1+ ;

: SZ-CUR-LINE-NO  ( -- n )
   SZ-CUR-LINE SZ-LINE-NO ;

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

\ Keep cursor column inside the horizontal window [SZ-HCOL, SZ-HCOL+WIDTH).
: SZ-ENSURE-HVISIBLE  ( -- )
   SZ-CUR-COL
   DUP SZ-HCOL @ < IF
      SZ-HCOL !  EXIT
   THEN
   \ past right edge → scroll so cursor sits on last visible column
   DUP SZ-HCOL @ SZ-TEXT-WIDTH + 1- > IF
      SZ-TEXT-WIDTH - 1+  0 MAX  SZ-HCOL !
   ELSE
      DROP
   THEN
;

\ Keep SZ-CUR's line in the text window without O(n²) scroll-down walks.
\ Jumping to end of a large file used to call SZ-SCROLL-DOWN + SZ-LINE-STEPS
\ once per line and hit STEP-LIMIT, aborting the editor (looked like Ctrl-End quit).
\ Vertical position uses a data-stack copy — never R@ inside DO (R is the loop frame).
: SZ-ENSURE-VISIBLE  ( -- )
   SZ-CUR-LINE                      \ ( line-start )
   \ Cursor above window → snap top to that line
   DUP SZ-TOP @ U< IF  DUP SZ-TOP !  THEN
   \ Cursor too far below top → put it on the last visible row
   SZ-TOP @ OVER SZ-LINE-STEPS
   SZ-TEXT-ROWS 1- > IF
      \ walk back TEXT-ROWS-1 line starts from cursor line
      SZ-TEXT-ROWS 1- 0 ?DO
         DUP SZ-TBUF = IF  LEAVE  THEN
         1- SZ-LINE-START
      LOOP
      SZ-TOP !
   ELSE
      DROP
   THEN
   SZ-ENSURE-HVISIBLE
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
      SZ-LN-SEP I AT-XY  [CHAR] | EMIT
      SZ-COLS 1- I AT-XY  [CHAR] | EMIT
   LOOP
;

\ ( n row -- )  right-justified 1-based line number in gutter; n=0 blanks gutter.
: SZ-SHOW-GUTTER  ( n row -- )
   SZ-LN-COL SWAP AT-XY
   DUP 0= IF
      DROP  SZ-LN-WIDTH 0 DO  BL EMIT  LOOP  EXIT
   THEN
   BASE @ SZ-SAVE-BASE !  DECIMAL
   0 <# #S #>                       ( c-addr u )
   SZ-LN-WIDTH OVER - 0 MAX 0 ?DO  BL EMIT  LOOP
   TYPE
   SZ-SAVE-BASE @ BASE !
;

\ Paint one text row with horizontal scroll (SZ-HCOL = first visible column).
: SZ-SHOW-LINE  ( line-addr row -- )
   SZ-TEXT-LEFT SWAP AT-XY
   SZ-PARSE-LINE                    ( a u )
   \ skip scrolled-off prefix
   SZ-HCOL @ OVER MIN >R            ( a u ) ( R: skip )
   R@ - 0 MAX                       ( a u' )
   SWAP R> + SWAP                   ( a' u' )
   SZ-TEXT-WIDTH MIN
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
   .(  L) SZ-CUR-LINE-NO 0 .R
   .(  C) SZ-CUR-COL 1+ 0 .R
   .(  ) SZ-TLEN @ 0 .R .( b)
   .( /) SZ-TBUF-CAP @ 0 .R
;

: SZ-SHOW-HELP  ( -- )
   SZ-TEXT-BOT 2 + SZ-BLANK-ROW
   0 SZ-TEXT-BOT 2 + AT-XY
   \ ASCII only (facility is a byte grid; non-ASCII used to blank the whole help row).
   .( Cmd-S save  Cmd-O open  Cmd-W close | arrows Home/End PgUp/Dn BS Del)
;

\ Place Facility cursor on the insert cell (host reverse-videos it).
\ Column is relative to SZ-HCOL so End on a long line can sit at the true end.
: SZ-PLACE-CURSOR  ( -- )
   SZ-CUR-COL SZ-HCOL @ -  0 MAX  SZ-TEXT-WIDTH 1- MIN
   SZ-TEXT-LEFT +
   SZ-TOP @ SZ-CUR-LINE SZ-LINE-STEPS SZ-TEXT-TOP +
   SZ-TEXT-BOT MIN
   AT-XY
;

: SZ-REDRAW  ( -- )
   SZ-ENSURE-VISIBLE
   PAGE
   SZ-SHOW-STATUS
   SZ-DRAW-FRAME
   \ Line numbers must use a VARIABLE — R@ inside DO is the loop index, not our
   \ counter (old R> 1+ >R produced 2,4,6… and broke the DO frame).
   SZ-TOP @ SZ-LINE-NO SZ-DRAW-LNO !
   SZ-TOP @
   SZ-TEXT-BOT 1+ SZ-TEXT-TOP DO
      DUP SZ-TEND SZ-U>= IF
         \ past EOF — blank gutter, empty text between frame bars
         0 I SZ-SHOW-GUTTER
      ELSE
         SZ-DRAW-LNO @ I SZ-SHOW-GUTTER
         DUP I SZ-SHOW-LINE
         SZ-NEXTLF
         DUP SZ-TEND <> IF  1+  THEN
         1 SZ-DRAW-LNO +!
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
