\\ LINES.SEQ     A simple graphic demo, draws lines on CGA or HERCULES

  Here is an example file that will work on either CGA/EGA/VGA or HERCULES.

        Compile with the following command line:

                TCOM LINES /OPT /NOINIT <Enter>

{

needs graph.seq
needs herc.seq

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

1 value dinc
0 value -hdots
0 value -vdots

M: ?keyboard    ( -- f1 )
                0 $41A c@L 0 $41C c@L - ;

: ?kexit        ( -- )
                15 rnd 2 <
                if      #colors 1- rnd 1+ color !       \ reset color
                then
                ?keyboard if text-mode bye then ;


: dolines       ( -- )
        begin   -hdots rnd -vdots rnd -hdots rnd -vdots rnd
                -vdots 0
                do      i + swap i - 2swap
                        i - swap i + 2swap
                        2over 2over line
                        ?kexit
                loop    2drop
        again   ;

: draw_lines    ( -- )
                vdots 1- =: -vdots
                hdots 1- =: -hdots
                dolines ;

: lines         ( -- )
                randomize
                ?vmode 7 <>
                if      640x480x16
                else    hercules
                then
                #colors 1- rnd 1+ color !
                draw_lines ;

