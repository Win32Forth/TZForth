\\ LINEWALK.SEQ         A Demo of Line Drawing          by Tom Zimmer

        Compile with the following command line:

                TCOM LINEWALK /OPT /NOINIT <Enter>

{

needs graph.seq

: graph_bye     ( -- )          \ cleanup stuff when we are all done
                text-mode 0 1 at
   ." Usage: LINEWALK {max-length(10-1000[200])} {lines/random(10-20000[400])} <enter>"
cr
cr ." LINEWALK.COM is a public domain example program by Tom Zimmer."
cr ." LINEWALK was written in Forth and compiled with the TCOM Target Compiler."
cr
cr ." If you would like to have the source for LINEWALK and other TCOM example"
cr ." programs, send a check for $60.00 US to:"
cr
cr ." Address: Tom Zimmer            Phone: (408) 263-8859 evenings (7pm-9pm pst)"
cr ."          292 Falcato Drive            (415) 327-8800 days     (9am-5pm pst)"
cr ."          Milpitas, Ca. 95035   Outside US orders add 20 dollars."
cr
cr ." You will receive the TCOM compiler, its source, the source for LINEWALK and"
cr ." the source for a many other TCOM example programs on 3.5 inch 1.44 meg disks."
cr
cr ." Example programs include:
cr ."   ZLIST  file viewer       SZ    small editor      VED    Virtual Editor"
cr ."   LOOK   file searcher     ZTREE disk space util   TIMEIT elapse timer"
cr ."   MANGEN Mandelbrot draw   TETRA a game            VMODE  video mode set"
cr
cr ." and several others, plus F-PC, the FULL Forth system on which TCOM is built."
cr ." This package totals almost five megabytes installed, with full source."
cr              bye ;

0 value SEED1
0 value SEED2
0 value SEED3

CODE (RANDOMIZE) ( -- u )
                save_bx
                MOV AH, # 0
                INT 26
                mov bx, dx
                ret     END-CODE

: RANDOMIZE     ( -- )
                (RANDOMIZE)        !> SEED1
                (RANDOMIZE) 2* 1-  !> SEED2
                (RANDOMIZE) 2/ 1+  !> SEED3 ;

: RND           ( n1 -- n2 )
                1 max
                SEED1 177 /MOD  2*    SWAP  171 *  SWAP  - DUP  !> SEED1
                SEED2 176 /MOD  35 *  SWAP  172 *  SWAP  - DUP  !> SEED2
                SEED3 178 /MOD  63 *  SWAP  170 *  SWAP  - DUP  !> SEED3
                +  + SWAP  MOD  ;

M: ?keyboard    ( -- f1 )
                0 $41A c@L 0 $41C c@L - ;

0 value -hdots
0 value -vdots

: rnd_color     ( -- )
                15 rnd 1+ color ! ;

0 value x1 0 value y1 0 value x2 0 value y2

: bounce_xy1    ( x2 y2 x1 y1 -- x2 y2 x1 y1 )
                swap    dup -hdots >= if -1 !> x1  0 !> x2 rnd_color then
                        dup 1 <       if  1 !> x1  0 !> x2 rnd_color then
                swap    dup -vdots >= if -1 !> y1  0 !> y2 rnd_color then
                        dup 1 <       if  1 !> y1  0 !> y2 rnd_color then ;

: bounce_xy2    ( x1 y1 x2 y2 -- x1 y1 x2 y2 )
                swap    dup -hdots >= if -1 !> x2  0 !> x1 rnd_color then
                        dup 1 <       if  1 !> x2  0 !> x1 rnd_color then
                swap    dup -vdots >= if -1 !> y2  0 !> y1 rnd_color then
                        dup 1 <       if  1 !> y2  0 !> y1 rnd_color then ;

0 value line_max
0 value lines_max
0 value line_limit

: limit_xy      ( x2 y2 x1 y1 -- x2 y2 x1 y1 )
                2swap over >r 2swap over r> - dup abs line_limit >
                if      dup 0<
                        if      1 !> x1 -1 !> x2
                        else    1 !> x2 -1 !> x1
                        then    y1 0= y2 0= or
                        if 2 rnd 2 rnd - !> y1 then
                        rnd_color
                then    drop
                2swap dup>r   2swap dup  r> - dup abs line_limit >
                if      dup 0<
                        if      1 !> y1 -1 !> y2
                        else    1 !> y2 -1 !> y1
                        then    x1 0= x2 0= or
                        if 2 rnd 2 rnd - !> x1 then
                        rnd_color
                then    drop ;

0 value cnt-down
0 value cnt-down-max

: draw-a-line   ( x y x y -- )
                cnt-down 0=
                if      line
                        cnt-down-max !> cnt-down
                else    decr> cnt-down
                        2drop 2drop
                then    ;

: draw_1line    ( x y x y -- x y x y )
                line_max rnd 10 max !> line_limit
                2 rnd 2 rnd - !> x1 2 rnd 2 rnd - !> y1
                2 rnd 2 rnd - !> x2 2 rnd 2 rnd - !> y2
                lines_max rnd 1+ 0
                do      4dup draw-a-line
                        limit_xy
                        swap x1 + swap y1 + bounce_xy1 2swap
                        swap x2 + swap y2 + bounce_xy2 2swap
                        i 1+ rnd 15 and 0=
                        if      rnd_color
                        then
                        ?keyboard ?leave
                loop    rnd_color ;

0 value ?rnd

: ?line_length  ( -- )
                >in @ bl word 1+ " /r" caps-comp 0=
                if      drop on> ?rnd
                else    >in !
                then
                bl word ?uppercase number? nip          \ line length
                if      dup 5 max 1000 min !> line_max
                else    200 !> line_max
                then    drop
                bl word ?uppercase number? nip          \ number of lines
                if      dup 1 max 20000 min !> lines_max
                else    400 !> lines_max
                then    drop
                bl word ?uppercase number? nip          \ number of lines
                if      dup 0max 100 min !> cnt-down-max
                else    0 !> cnt-down-max
                then    drop ;

: LINEWALK      ( -- )
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                0 SET_MEMORY                    \ default to min code space
                DOS_TO_TIB                      \ move command tail to TIB
                randomize
                ?vmode 7 = abort" Requires EGA/VGA color!"
                ?line_length
                640x350x16
                2 color !
                vdots 3 - =: -vdots
                hdots 3 - =: -hdots
                -hdots 2/ -vdots 2/ 2dup
                begin   10 0
                        do      draw_1line
                                ?keyboard ?leave
                        loop
                        ?rnd
                        if       500 rnd !> line_max
                                5000 rnd !> lines_max
                                   3 rnd !> cnt-down-max
                        then
                        ?keyboard dup
                        if      drop
                                key $20 <>
                        then
                until   2drop
                ?keyboard
                if      key drop
                then    graph_bye ;

