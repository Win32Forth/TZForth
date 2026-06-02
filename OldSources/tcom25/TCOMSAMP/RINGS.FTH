\\ RINGS.SEQ  Draw Random Rings in Graphic Mode  by Tom Zimmer & Robert Smith

  Draw random rings in graphic mode, runs in 640x350 mode.

        .options /opt /noinit /tailopton

 **********************************************************************

 The SINTBL below was defined by using the following program using F-PC
 and Robert Smiths FFLOAT floating point package to generate the values
 which were redirected to a disk file using the ">B" F-PC operator to
 create BROWSE.PRN from the displayed output of this program.
 BROWSE.PRN was then edited into the table you see here, giving an array
 of absolute screen offsets for coordinates to draw the clock hands.

 **********************************************************************

        needs ffloat    \ load the floating point package
        floats          \ allow automatic floating point number conversion
        degrees         \ make FSIN word in degrees

        : makesin       ( -- )
                        462 0
                        do      cr i 0 float fsin 240.0 f* int d.
                                100 ms
                                ?keypause
                     6 +loop    ;

 **********************************************************************

{

needs graph.seq

create sintbl
          0 ,    25 ,    49 ,    74 ,    97 ,   120 ,   141 ,   160 ,
        178 ,   194 ,   207 ,   219 ,   228 ,   234 ,   238 ,   240 ,
        238 ,   234 ,   228 ,   219 ,   207 ,   194 ,   178 ,   160 ,
        141 ,   119 ,    97 ,    74 ,    49 ,    25 ,     0 ,   -25 ,
        -49 ,   -74 ,   -97 ,  -120 ,  -141 ,  -160 ,  -178 ,  -194 ,
       -207 ,  -219 ,  -228 ,  -234 ,  -238 ,  -240 ,  -238 ,  -234 ,
       -228 ,  -219 ,  -207 ,  -194 ,  -178 ,  -160 ,  -141 ,  -119 ,
        -97 ,   -74 ,   -49 ,   -25 ,     0 ,    25 ,    49 ,    74 ,
         97 ,   120 ,   141 ,   160 ,   178 ,   194 ,   207 ,   219 ,
        228 ,   234 ,   238 ,   240 ,   238 ,

: graph_bye     ( -- )          \ cleanup stuff when we are all done
                text-mode 0 1 at
   ." Usage: RINGS {distortion-number(0-40)} {max-diameter(2-300)} <enter>"
cr
cr ." RINGS.COM is a public domain example program by Tom Zimmer and Robert Smith."
cr ." RINGS was written in Forth and compiled with the TCOM Target Compiler."
cr
cr ." If you would like to have the source for RINGS and other TCOM example"
cr ." programs, send a check for $60.00 US to:"
cr
cr ." Address: Tom Zimmer            Phone: (408) 263-8859 evenings (7pm-9pm pst)"
cr ."          292 Falcato Drive            (415) 327-8800 days     (9am-5pm pst)"
cr ."          Milpitas, Ca. 95035   Outside US orders add 20 dollars."
cr
cr ." You will receive the TCOM compiler, its source, the source for RINGS and"
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

  0 value ?specified

320 value center-x
175 value center-y
240 value scale-y
 40 value ring-size
  2 value ring-step
 60 value diameter-max
 12 value oblong-max

0 value oblong

: xy-scale      ( 6deg scale -- x1 y1 )
                >r
                dup       2* sintbl + @ dup r@     240 */
                swap 1 and oblong negate * +        center-x +
                swap 15 + 2* sintbl + @ dup r> scale-y */
                swap 1 and oblong        * + negate center-y + ;


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

: ?keyboard     ( -- f1 )
                0 $41A c@L 0 $41C c@L - ;

: .section      ( n1 -- )       \ show one section of samsung logo
                0 1 xy-scale
                rot 10 bounds
                do      2dup i 16 xy-scale line
                loop    2drop ;

: .ur           ( -- )
                ?keyboard ?exit
                 3 .section  20 +!> center-x -16 +!> center-y
                33 .section -20 +!> center-x  16 +!> center-y ;

: .lr           ( -- )
                ?keyboard ?exit
                18 .section  20 +!> center-x  16 +!> center-y
                48 .section -20 +!> center-x -16 +!> center-y ;

: .ul           ( -- )
                ?keyboard ?exit
                48 .section -20 +!> center-x -16 +!> center-y
                18 .section  20 +!> center-x  16 +!> center-y ;

: .ll           ( -- )
                ?keyboard ?exit
                33 .section -20 +!> center-x  16 +!> center-y
                 3 .section  20 +!> center-x -16 +!> center-y ;

: show-samsung  ( -- )
                0 save!> oblong
                red color !
                 55 !> center-x
                 40 !> center-y         .ur .lr .ul .ll
                -40 +!> center-x        .ur .lr
                 40 +!> center-x
                -32 +!> center-y        .lr .ll
                 64 +!> center-y        .ul .ur
                 15 rnd 1+ color !
                restore> oblong ;

0 value ring-cnt

: show-webs     ( -- )          \ show one ring
                save> color 16 rnd color !
                60 0
                do      i ring-size 2/     rnd   xy-scale
                        i ring-size 2/     rnd   xy-scale line
                        i ring-size 2/ dup rnd + xy-scale
                        i ring-size 2/ dup rnd + xy-scale line
         5 rnd +loop
                restore> color ;

: show-ring     ( -- )          \ show one ring
                60 0
                do      i ring-size xy-scale i 1+ ring-size xy-scale line
                loop
                incr> ring-cnt
                ring-cnt 6000 diameter-max 20 * - >
                if      off> ring-cnt
                        ?specified 0=
                        if      30 rnd     !> oblong-max
                                200 rnd 1+ !> diameter-max
                        then
                        show-samsung
                        10 0 do 1 tenths key? ?leave loop
                then
                ring-cnt 3000 diameter-max 6 * - <
                if      ring-cnt 3 and 0=
                        if      16 rnd color !
                        then
                else    black color !
                then    ;

: show-disk     ( -- )          \ while no key pressed, show a disk
                vdots rnd 4 max !> center-y
                hdots rnd 4 max !> center-x
                diameter-max rnd 4 max 2
                do      i !> ring-size
                        show-ring
                        ?keyboard ?leave
     ring-step +loop    ring-step 2 >
                if      show-webs
                then    ;

: process-command-line ( -- )
                bl word ?uppercase number? nip
                if      dup 0max   50 min !> oblong-max
                then    drop
                bl word ?uppercase number? nip
                if      dup 4 max 300 min !> diameter-max
                        on> ?specified
                then    drop ;

: tcom_init     ( -- )
                DECIMAL                         \ always select decimal
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                0 SET_MEMORY                    \ default to minimum
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT  ;                 \ init command specification

: main          ( -- )          \ a simple drawing program
                tcom_init                       \ init I/O
                randomize
                process-command-line
                ?vmode 7 = abort" Sorry, EGA/VGA Color required"
                640x350x16                      \ set graphics mode
                vdots 2/ 1- !> center-y         \ calibrate screen center
                240 240 center-y */ !> scale-y  \ calibrate aspect ratio
                white color !                   \ default color=white
                show-samsung
                begin   oblong-max 2+ oblong - 1 max 0
                        ?do     show-disk
                                12 rnd 1+ !> ring-step
                                ?keyboard ?leave
                     4 +loop
                        oblong-max 6 / rnd 6 * 0max !> oblong
                        ?keyboard
                until   ?keyboard
                if      key drop                \ discard any key pressed
                then    640x350x16              \ re-clear screen
                graph_bye                       \ and terminate the program
                ;


