\\ LINESCAN.SEQ         A Demo of Line Drawing          by Tom Zimmer

        Compile with the following command line:

                TCOM LINES /OPT /NOINIT <Enter>

{

needs graph.seq

: graph_bye     ( -- )          \ cleanup stuff when we are all done
                text-mode 0 1 at
   ."         Usage: LINESCAN {#lines(1-1000[1]) {max-line-length(2-800[40])}} <enter>"
cr ." While running:   '+' : increase #lines    '-' : decrease #lines "
cr ." LINESCAN.COM is a public domain example program by Tom Zimmer."
cr ." LINESCAN was written in Forth and compiled with the TCOM Target Compiler."
cr
cr ." If you would like to have the source for LINESCAN and other TCOM example"
cr ." programs, send a check for $60.00 US to:"
cr
cr ." Address: Tom Zimmer            Phone: (408) 263-8859 evenings (7pm-9pm pst)"
cr ."          292 Falcato Drive            (415) 327-8800 days     (9am-5pm pst)"
cr ."          Milpitas, Ca. 95035   Outside US orders add 20 dollars."
cr
cr ." You will receive the TCOM compiler, its source, the source for LINESCAN and"
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

      1000 constant max-lines
            0 value #linescan
           70 value line-limit
            0 value tox     0 value toy
            0 value fmx     0 value fmy
            0 value the-color
            0 value the-rnd
            0 value the-lines

: ?kexit        ( -- )
                ?keyboard
                if  key
                    case    '+' of  #linescan 1+ max-lines min !> #linescan
                                endof
                            '-' of  #linescan 1-         0 max !> #linescan
                                endof
                                    graph_bye
                    endcase
                then ;

: rnd_color     ( -- )
                15 rnd 1+ color ! ;

: draw_1line    ( -- )
                begin 2 rnd 2 rnd - ?dup until
                begin 2 rnd 2 rnd - ?dup until
                line-limit #linescan + rnd 5 + 0
                do      fmy 0<       if abs        rnd_color then
                        fmy -vdots > if abs negate rnd_color then swap
                        fmx 0<       if abs        rnd_color then
                        fmx -hdots > if abs negate rnd_color then swap
                        fmx tox - abs line-limit >
                        if      swap abs
                                fmx tox >
                                if      negate
                                then    swap
                                rnd_color
                        then
                        fmy toy - abs line-limit >
                        if      abs     fmy toy >
                                if      negate
                                then
                                rnd_color
                        then
                        2dup    +!> fmy    +!> fmx
                        fmx fmy tox toy line
                        swap_lines
                        ?kexit
                loop    rnd_color
                10 rnd 8 ( 3 )  <
                if      tox fmx !> tox !> fmx
                        toy fmy !> toy !> fmy
                then    2drop   ;

0 value nextline

: swap_lines    ( d1 -- d1 )
                #linescan 1 < ?exit
                color @ the-color nextline 2*  + !
                        the-rnd   nextline 4 * + 2!
                &> tox  the-lines nextline 8 * + 8 cmove
                nextline 1+ !> nextline
                nextline #linescan > if off> nextline then
                the-lines nextline 8 * + &> tox 8 cmove
                the-rnd   nextline 4 * + 2@
                the-color nextline 2*  + @ color ! ;

0 value ?specified
0 value linecnt

: ?random_set   ( -- )
                ?specified 0=
                if      incr> linecnt
                        linecnt 31 and 0=
                        if       9 rnd !> #linescan
                                200 rnd 2 max !> line-limit
                        then
                then    ;

: linescan      ( -- )
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to max code space
                DOS_TO_TIB                      \ move command tail to TIB
                randomize
                bl word ?uppercase number? nip
                if      dup 1- 0max max-lines min !> #linescan
                        on> ?specified
                then    drop
                bl word ?uppercase number? nip
                if      dup 2 max 800 min !> line-limit
                then    drop
                max-lines 2+ 2 * ds:alloc !> the-color
                max-lines 2+ 4 * ds:alloc !> the-rnd
                max-lines 2+ 8 * ds:alloc !> the-lines
                ?vmode 7 = abort" Requires EGA/VGA color!"
                640x350x16
                2 color !
                vdots 3 - =: -vdots
                hdots 3 - =: -hdots
                50 50 p-at ." Initializing arrays, one moment..."
                max-lines 0                             \ fill lines array
                do      -hdots rnd 1+ dup !> tox  !> fmx
                        -vdots rnd 1+ dup !> toy  !> fmy
                        &> tox the-lines i 8 * + 8 cmove
                loop
                -hdots 2/ dup !> tox  !> fmx
                -vdots 2/ dup !> toy  !> fmy
                max-lines 0
                do      begin 2 rnd 2 rnd - ?dup until
                        begin 2 rnd 2 rnd - ?dup until
                        the-rnd i 4 * + 2!
                loop
                max-lines 0
                do      15 rnd 1+ the-color i 2* + !
                loop
                640x350x16
                begin   draw_1line
                        ?random_set
                again   ;

