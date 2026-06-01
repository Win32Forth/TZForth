\ TCOLOR.SEQ     Color board support for TCOM            by Tom Zimmer

\ For Color boards, the following values may be used for background
\ or forground.

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

\                       16 COLOR MODE   4 COLOR MODE
$00 CONSTANT BLACK       \ black        \ CGA black
$01 CONSTANT BLUE        \ blue         \ CGA cyan
$02 CONSTANT GREEN       \ green        \ CGA magenta
$03 CONSTANT CYAN        \ cyan         \ CGA white
$04 CONSTANT RED         \ red
$05 CONSTANT MAGENTA     \ magenta
$06 CONSTANT BROWN       \ brown
$07 CONSTANT LTGRAY      \ light gray

$08 CONSTANT DKGRAY      \ dark gray   All following, blink in Background.
$09 CONSTANT LTBLUE      \ light blue
$0A CONSTANT LTGREEN     \ light green
$0B CONSTANT LTCYAN      \ light cyan
$0C CONSTANT LTRED       \ light red
$0D CONSTANT LTMAGENTA   \ light magenta
$0E CONSTANT YELLOW      \ yellow
$0F CONSTANT WHITE       \ white

: >FG           ( N1 --- )
                attrib c@ $F0 and + attrib c! ;

: >BG           ( N1 --- )
                $10 * attrib c@ $0F and + attrib c! ;

FORTH TARGET >TARGET

