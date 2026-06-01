\\ GSDUMP.SEQ    graphic screen dump to a printer

These two words will dump a graphic screen to a variety of printers.
LANDSCAPE-DUMP places the horizontal screen axis down the length of the paper.
PORTRAIT-DUMP places the horizontal screen axis across the width of the paper.
This loads on top of GRAPH.SEQ in order to use POINT
{

30 value glmargin       \ number of printer columns for a left margin

: start-line ( c -- ) \ initiate a graphics print line for c columns
        27 pemit  'L' pemit         \ select graphics print mode
        glmargin +                      \ add a margin
        split swap pemit pemit      \ output number of columns
        glmargin 0 do 0 pemit loop    \ move across the margin
        ;

: end-line ( -- ) \ end line and feed paper
        20 0 do  0 pemit loop         \ add some nulls just in case
                                        \ something was dropped
        13 pemit      \ Fujitsu needs a Carriage Return
        27 pemit  'J' pemit  23 pemit     \ feed paper the right amount
        ;

0 value bit
0 value byte

: landscape-dump
        hdots 8 /
        0 do    vdots 2* start-line
                vdots
                0 do
                        1 !> bit
                        off> byte
                        8 0 do  k 8 * 7 + i -  vdots 1- j -  point
                                $ff and 0<> bit and
                                byte or !> byte
                                bit 2* !> bit
                            loop
                        byte $1A = if $18 !> byte then
                                        \ get rid of 1A characters
                                        \ because the printer ignores them
                        byte pemit
                        byte pemit
                loop
                end-line
           loop
        control L pemit       \ finish with a form-feed
        ;


: portrait-dump
        vdots 8 /
        0 do    hdots start-line
                hdots
                0 do
                        1 !> bit
                        off> byte
                        8 0 do  j  k 8 * 7 + i -  point
                                $ff and 0<> bit and
                                byte or !> byte
                                bit 2* !> bit
                            loop
                        byte $1A = if $18 !> byte then
                                        \ get rid of 1A characters
                                        \ because the printer ignores them
                        byte pemit
                loop
                end-line
           loop
        control L pemit       \ finish with a form-feed
        ;


: herc-dump ( -- ) \ fast screen dump for HERCULES graphic screen
        90 0 do 348 dup 2* start-line
                0 do    herc-seg @
                        347 i - 4 /mod 90 *  swap $2000 * +
                        j +  c@l
                        dup $1A = if 2- then  \ get rid of 1A characters
                                              \ because the printer ignores them
                        dup pemit pemit
                loop
                end-line
           loop
        control L pemit       \ finish with a form-feed
        ;

} 様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様様

Screen dumps for HP printers

{
: es ( a c -- )
        $1b pemit
        bounds do  i c@  pemit  loop
        ;
: eg
        " *rb" es $c pemit ;

: pp ( char -- ) \ send one character to the printer
        dup $1A = if drop $18 then      \ get rid of 1A characters
        pemit                         \ because the printer ignores them
        ;

}
printer colors
0 none
1 blue  = cyan + magenta
2 green = yellow + cyan
3 cyan
4 red   = magenta + yellow
5 magenta
6 yellow
7 black
{
create ega>pcolor-table
\       0     1     2     3     4     5     6     7     \ ega color
        7 c,  1 c,  2 c,  3 c,  4 c,  5 c,  6 c,  0 c,  \ print color

\       8     9    10    11    12    13    14    15     \ ega color
        7 c,  1 c,  2 c,  3 c,  4 c,  5 c,  6 c,  0 c,  \ print color

create ega>pblack-table
\       0     1     2     3     4     5     6     7     \ ega color
        1 c,  1 c,  1 c,  1 c,  1 c,  1 c,  1 c,  1 c,  \ black dot

\       8     9    10    11    12    13    14    15     \ ega color
        0 c,  0 c,  0 c,  0 c,  0 c,  0 c,  0 c,  0 c,  \ black dot

0 value row+
0 value col+
0 value byte
0 value bit
: pcset ( n -- ) \ set a bit in the line map at pad
        160 *
        pad +
        byte +  row+ if 640 + then
        dup @ flip
        bit     col+ if 2* then
        or
        flip swap !
        ;

: pblk  0 pcset  ;
: pcyn  1 pcset  ;
: pmgt  2 pcset  ;
: pylw  3 pcset  ;
: pblu  pcyn pmgt ;
: pred  pmgt pylw ;
: pgrn  pylw pcyn ;

: putn ( n -- )
        7 and
        exec: noop pblu pgrn pcyn pred pmgt pylw pblk ;

: put0  off> row+  off> col+  putn ;
: put1  off> row+  on>  col+  putn ;
: put2  on>  row+  off> col+  putn ;
: put3  on>  row+  on>  col+  putn ;

: putcolor ( x y -- ) \ get color and add to table at pad
        dup  vdots u>= if  2drop exit  then
        over hdots u>= if  2drop exit  then
        point
        $f and
        dup ega>pcolor-table + c@  >r
            ega>pblack-table + c@
        0= if  r@  else 7 then  put0
        r@ put1  r@ put2  r> put3
        ;

: color-portrait \ screen dump for Deskjet 550c

        " *t150R" es    \ dpi
        " *r0A" es      \ start at left
        " *r-4U" es     \ planes

        vdots         \ 640 x 350
        0 do
                off> byte
                pad  160 8 * erase
                80              \ hdots 8 /
                0 do
                        1 !> bit
                        8 0 do  j 1+ 8 *  i - 1-  k  putcolor
                                bit 4 * !> bit
                                loop
                        2 +!> byte
                loop

                " *b160V" es
                160 0 do  pad i +       c@ pp  loop      \ black
                " *b160V" es
                160 0 do  pad i + 160 + c@ pp  loop      \ cyan
                " *b160V" es
                160 0 do  pad i + 320 + c@ pp  loop      \ magenta
                " *b160W" es
                160 0 do  pad i + 480 + c@ pp  loop      \ yellow

                " *b160V" es
                160 0 do  pad i + 640 + c@ pp  loop      \ black
                " *b160V" es
                160 0 do  pad i + 800 + c@ pp  loop      \ cyan
                " *b160V" es
                160 0 do  pad i + 960 + c@ pp  loop      \ magenta
                " *b160W" es
                160 0 do  pad i + 1120 + c@ pp  loop      \ yellow
           loop

        " *rB" es
        $0c pemit
        ;

: color-landscape \ screen dump for Deskjet 550c

        " *t150R" es                    \ dpi
        " &l6C"  es " &a8R"  es         \ one inch from top
        " &k12H" es " &a10C" es         \ one inch from left
        " *r1A" es                      \ start here
        " *r-4U" es                     \ planes

        hdots         \ 640 x 350
        0 do
                off> byte
                pad  160 8 * erase
                44  \ 350 8 /   \ vdots 8 /
                0 do
                        1 !> bit
                        8 0 do  hdots 1- k -  j 1+ 8 *  i - 1-  putcolor
                                bit 4 * !> bit
                                loop
                        2 +!> byte
                loop

                " *b88V" es
                88 0 do  pad i +       c@ pp  loop      \ black
                " *b88V" es
                88 0 do  pad i + 160 + c@ pp  loop      \ cyan
                " *b88V" es
                88 0 do  pad i + 320 + c@ pp  loop      \ magenta
                " *b88W" es
                88 0 do  pad i + 480 + c@ pp  loop      \ yellow

                " *b88V" es
                88 0 do  pad i + 640 + c@ pp  loop      \ black
                " *b88V" es
                88 0 do  pad i + 800 + c@ pp  loop      \ cyan
                " *b88V" es
                88 0 do  pad i + 960 + c@ pp  loop      \ magenta
                " *b88W" es
                88 0 do  pad i + 1120 + c@ pp  loop     \ yellow
           loop

        " *rB" es
        $0c pemit
        ;

: laser-portrait \ screen dump for HP Laserjet and black-only Deskjet

        " *t75R" es     \ dpi
        " *r0A" es      \ start at left

        vdots         \ 640 x 350
        0 do
                " *b80W" es
                80 \ hdots 8 /
                0 do
                        1 !> bit
                        off> byte
                        8 0 do  j 1+ 8 *  i - 1-  k  point
                                $ff and 0<> bit and
                                byte or !> byte
                                bit 2* !> bit
                            loop
                        byte $1A = if $18 !> byte then
                                        \ get rid of 1A characters
                                        \ because the printer ignores them
                        byte pemit
                loop
           loop

        " *rB" es
        $0c pemit
        ;

: laser-landscape \ screen dump for HP Laserjet and black-only Deskjet

        " *t75R" es     \ dpi
        " *r0A" es      \ start at left

        hdots         \ 640 x 350
        0 do
                " *b44W" es
                44 \ vdots 8 /
                0 do
                        1 !> bit
                        off> byte
                        8 0 do  k  vdots j 1+ 8 * - i +  point
                                $ff and 0<> bit and
                                byte or !> byte
                                bit 2* !> bit
                            loop
                        byte $1A = if $18 !> byte then
                                        \ get rid of 1A characters
                                        \ because the printer ignores them
                        byte pemit
                loop
           loop

        " *rB" es
        $0c pemit
        ;

4 value printer
: print-screen
        printer 6 min exec:
        landscape-dump  \ IBM/Proprinter
        portrait-dump   \ IBM/Proprinter
        herc-dump       \ fast screen dump for HERCULES graphic screen
        color-portrait  \ Deskjet 550c
        color-landscape \ Deskjet 550c
        laser-portrait  \ HP Laserjet and black-only Deskjet
        laser-landscape \ HP Laserjet and black-only Deskjet
        ;



