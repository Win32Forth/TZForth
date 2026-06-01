\  MYCLOCK.BLK   a visual clock program                11Nov87jgm
.options /opt /noinit /inx      \ compiler directives for this program

\                      November 1987

\                       J.G. Modrow
\                     6320 Menlo Drive
\                    San Jose, CA 95120

\                     (408) 997-3530


\       shows a digital clock, hh:mm:ss at the top of the
\       screen abd mm/dd/yy under it, both in roman numerals.

\       Mid screen is a bar graph display showing Hours in
\       15 minute intervals, minutes, seconds, month in 5
\       day intervals, days, years MOD 50.

\ 10/19/89 TJZ
\ Use the following DOS command line to compile CLOCK.SEQ into the
\ CLOCK.COM program file:
\
\       C:> TCOM CLOCK /OPT /NOINIT <Enter>
\

\ cons, vars, arrays, strings

CREATE R-UNITS  ,"     I   II  III IV  V   VI  VII VIIIIX  "
CREATE R-TENS   ,"        X  XX XXX  XL   L  LX LXXLXXX  XC"
CREATE R-HUNDS  ,"     C   CC  CCC CD  D   DC  DCC DCCCCM  "
CREATE R-THOUS  ,"        M  MM MMM  M?   ?  ?M ?MM?MMM  ??"

VARIABLE LAST-SEC       VARIABLE LAST-MIN \ last time displayed
VARIABLE LAST-HR        VARIABLE LAST-DAY
VARIABLE LAST-MO        VARIABLE LAST-YR

\  CREATE MONTHS   " JanFebMarAprMayJunJulAugSepOctNovDec"

\  : .MONTH        ( mo -- ) \ print month
\      3 * MONTHS +  3 TYPE SPACE  ;


\  print Roman Numeral clock

: .R-NUM        ( adr n -- )  4 * + ( 3 fix for F-PC) 1 +  4 TYPE ; \ n = 0..9

: .R-TU         ( n -- ) \ n = 0..99, prints roman numerals
    100 MOD 10 /MOD R-TENS SWAP .R-NUM R-UNITS SWAP .R-NUM ;

: .R-TH         ( n -- ) \ n = 0..9999, prints 1000s & 100S
    100 / 10 /MOD R-THOUS SWAP .R-NUM R-HUNDS SWAP .R-NUM ;

: .=            ( n -- )     1- FOR 205 EMIT NEXT ;

: ?SEC          ( -- h m s f ) \ f = true if sec changed.
        GETTIME  256 / >R  256 /MOD SWAP  R>
        DUP LAST-SEC @ <>  ;

: .R-TIME       ( h m s f -- ) \ print digital time in roman #s
        IF    27 1 AT  DUP LAST-SEC !   \ save sec
              ROT  .R-TU 186 EMIT SWAP  \ print hrs:
              .R-TU 186 EMIT .R-TU      \ print min:sec
        ELSE  2DROP DROP
        THEN  ;

: CLOCK-BOX     ( -- ) \ draws box around roman digital clock.
        DARK  cursor-off 26 0 AT        \ top line
        201 EMIT 8 .= 203 EMIT 8 .= 203 EMIT 8 .= 187 EMIT
        26 1 AT  186 EMIT 8 SPACES      \ time boxes
        186 EMIT 8 SPACES 186 EMIT 8 SPACES 186 EMIT
        26 2 AT                         \ middle line
        204 EMIT 8 .= 206 EMIT 8 .= 206 EMIT 8 .= 185 EMIT
        26 3 AT  186 EMIT 8 SPACES      \ date boxes
        186 EMIT 8 SPACES 186 EMIT 8 SPACES 186 EMIT
        26 4 AT                         \ bottom line
        200 EMIT 8 .= 202 EMIT 8 .= 202 EMIT 8 .= 188 EMIT  ;

: ?DAY          ( -- yr day mo f ) \ f = true if day changed.
        GETDATE  SPLIT  OVER LAST-DAY @  <>  ;

: .R-DATE       ( yr day mo f -- ) \ prints date in roman #s.
        IF    OVER LAST-DAY !           \ update current day
              27 3 AT  .R-TU  186 EMIT  \ print month
              .R-TU  186 EMIT .R-TU     \ print day & year
        ELSE  2DROP DROP
        THEN  ;

\  print bar graph clock

: BAR-HEADER    ( -- )          \ prints header lines for bar graph clk
        5 10 AT         0 12 FOR DUP 5 .R 1+    NEXT DROP CR
        9 SPACES ." |"    11 FOR ." ....|"      NEXT CR
        ." Hour"  CR    ." Mins" CR     ." Secs"  CR
        9 SPACES ." |"    11 FOR ." ....|"      NEXT CR
        ." Month" CR    ." Day " CR     ." Year"  CR
        9 SPACES ." |"    11 FOR ." ''''|"      NEXT CR
        5 SPACES        0 12 FOR DUP 5 .R  5 +  NEXT DROP CR
       12 SPACES ." Written by  J. G. Modrow,"
       ."   November 1987  <ESC> to Quit"   ;

: .BAR  ( chr r n -- ) \ prints chr at position n, row r.
        9 +  SWAP AT  EMIT  ;

: .NEW-BAR      ( chr r n -- ) \ prints bar to position n, at row r.
        9 ROT AT  1+ FOR DUP EMIT NEXT DROP  ;

: ?CLR-BAR      ( r f -- ) \ erases bar  if true.
        IF 9 SWAP AT 61 SPACES  ELSE DROP  THEN  ;

: .B-SEC        ( s -- ) \ prints current seconds on bar
        14 OVER 0= ?CLR-BAR     \ erase if secs = 0
        177 14 ROT .BAR   ;     \ print seconds bar

: .B-MIN        ( m -- ) \ prints minutes bar
        DUP   LAST-MIN @ <>             \ print minute?
        IF    DUP LAST-MIN !            \ update current minute
              13 OVER 0= ?CLR-BAR       \ erase if mins = 0
              178 13 ROT .BAR           \ print mins, 12 hr clk
        ELSE  DROP
        THEN  ;

: .B-HOUR       ( h m -- ) \ prints hours bar
        12 /  SWAP 12 MOD  5 *  +       \ calc hours position
        DUP   LAST-HR @ <>              \ print hour?
        IF    DUP LAST-HR !             \ update current hour
              12 OVER 0= ?CLR-BAR       \ erase if hrs = 0
              219 12 ROT .BAR           \ print hrs
        ELSE  DROP
        THEN  ;

: .B-TIME       ( h m s f -- ) \ prints current time on bar
        IF    .B-SEC   DUP              \ print seconds bar
              .B-MIN  .B-HOUR           \ print min, hr bars
        ELSE  2DROP DROP
        THEN  ;

: .NEW-TIME     ( h m s f -- ) \ initializes time bars.
        DROP 177 14 ROT .NEW-BAR        \ seconds
        DUP  178 13 ROT .NEW-BAR        \ minutes
        12 /  SWAP 12 MOD  5 *  +
             219 12 ROT .NEW-BAR  ;     \ hours

: .B-DAY        ( day -- ) \ prints current day bar
        17 OVER 1 = ?CLR-BAR    \ erase if day = 1
        178 17 ROT .BAR   ;     \ print days bar

: .B-MONTH      ( day mo -- ) \ prints current month bar
        5 * SWAP 29 MIN 6 / +           \ calc month position
        DUP   LAST-MO @ <>              \ print month?
        IF    DUP LAST-MO !             \ update current month
              16 OVER 1 = ?CLR-BAR      \ erase if month = 1
              219 16 ROT .BAR           \ print month bar
        ELSE  DROP
        THEN  ;

: .B-YEAR       ( yr -- ) \ prints current year MOD 50
        50 MOD  DUP LAST-YR @ <>        \ 0..50 range, new year?
        IF    DUP LAST-YR !             \ update current year
              18 OVER 0= ?CLR-BAR       \ erase if yr ends in 0
              177 18 ROT .BAR           \ print year
        ELSE  DROP
        THEN  ;

: .NEW-DATE     ( yr day mo f -- ) \ initializes date bars.
        DROP  5 *  OVER 29 MIN 6 /  +
               219 16 ROT .NEW-BAR      \ month
               178 17 ROT .NEW-BAR      \ day
        50 MOD 177 18 ROT .NEW-BAR  ;   \ year

: .B-DATE       ( yr day mo f -- ) \ prints date in roman #s.
        IF    OVER .B-DAY  .B-MONTH     \ print day&month bars
              .B-YEAR                   \ print year MOD 50
        ELSE  2DROP DROP
        THEN  ;

\  Combine Roman Numeral and Bar Graph clocks

: TIC/TOK       ( -- ) \ Roman & bar graph digital clock
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                LAST-SEC ON  LAST-MIN ON  LAST-HR ON
                LAST-DAY ON  LAST-MO  ON  LAST-YR ON
                CLOCK-BOX    BAR-HEADER
                ?SEC .NEW-TIME  ?DAY .NEW-DATE
                BEGIN  ?SEC  4DUP .R-TIME  .B-TIME
                       ?DAY  4DUP .R-DATE  .B-DATE
                       KEY?     IF      KEY
                                        27 =
                                        IF      CURSOR-ON
                                                0 21 AT ABORT
                                        THEN
                                THEN
                AGAIN  ;

