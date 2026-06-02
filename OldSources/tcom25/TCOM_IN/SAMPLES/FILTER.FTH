\\ FILTER.SEQ           A simple file filter program    by Tom Zimmer

  This file illustrates how to make a program that processes all of the
characters in a file, and writes them back out to another file. The program
FILTER.COM is used as follows:

                C>FILTER <myin_file >myout_file [Enter]

"myin_file" contains the characters to be processed, and "myout_file" will
hold the characters after processing.

  If you simply load this file, you will compile the simple and SLOW
version of FILTER, it will proccess all characters of a file, performing
a DOS file read and a DOS file write call for each character processed.
This works just fine, but is quite slow. A second example which is
commented out, uses buffered I/O, and processes text MANY time faster.


{

: main          ( -- )
                raw_stdin
                begin   getchar dup  0<
                                over ^Z = or 0=
                while   putchar
                repeat  drop ;

}

***************************************************************************

  The FAST version of FILTER, for use with FILES ONLY.

  Don't use this one with keyboard input, as you will have to type
2000 characters before it will process the first character entered.

: main          ( -- )
                raw_stdin
                2000 =: gch.max         \ 2k input buffer
                2000 =: pch.max         \ 2k output buffer
                bufio_init              \ initialize buffered I/O
                begin   getchar_b dup  0<
                                  over ^Z = or 0=
                while   putchar_b
                repeat  drop
                flush_b ;               \ flush any un-written characters

***************************************************************************

  Here is another version of FILTER, it is more complex, but also more
flexible. This version uses a table to handle control characters, which
makes it faster. Extra processing can easily be added since you need
only plug the function into the table and recompile it.

: do_exit       ( -- )
                flush_b ABORT ;

: do_cr         ( -- )
                $0D putchar_b
                $0A putchar_b ;

: do_tab        ( -- )
                8 0 do $20 putchar_b loop ;

: do_ctrl       ( c1 --- )              \ handle control characters
                exec:
\               -1 end of file
                do_exit
\               0 null  1 a     2 b     3 c     4 d     5 e     6 f
                noop    noop    noop    noop    noop    noop    noop
\               7 g     8 h     9 i     LF      11 k    12 l    Enter
                noop    noop    do_tab  noop    noop    noop    do_cr
\               14 n    15 o    16 p    17 q    18 r    19 s    20 t
                noop    noop    noop    noop    noop    noop    noop
\               21 u    22 v    23 w    24 x    25 y    26 z    Esc
                noop    noop    noop    noop    noop    do_exit noop
\               28 \    29 ]    30 ^    31 _
                noop    noop    noop    noop ;

: main          ( -- )
                raw_stdin
                2000 =: gch.max         \ 2k input buffer
                2000 =: pch.max         \ 2k output buffer
                bufio_init              \ initialize buffered I/O
                begin   getchar_b dup $20 <
                        if      1+ do_ctrl
                        else    putchar_b
                        then
                again   ;

