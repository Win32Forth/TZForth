\\ SETMODE.SEQ           Select a video mode             by Tom Zimmer

  A very simple program that will set the video mode of your computer
  to the HEX number specified on the command line:

        SETMODE 7 <enter>       \ set your computer to video mode 7 (mono)

  Compile SETMODE as follows:

        TCOM SETMODE <enter>

  This will build a file SETMODE.COM in your \TCOM\SAMPLES directory.

{
.options /opt /noinit                           \ default compiler options

: .info         ( -- )          \ cleanup stuff when we are all done
cr ." Usage: SETMODE {video_mode(2-FF)} <enter>"
cr
cr ." SETMODE.COM is a public domain example program by Tom Zimmer."
cr ." SETMODE was written in Forth and compiled with the TCOM Target Compiler."
cr
cr ." If you would like to have the source for SETMODE and other TCOM example"
cr ." programs, send a check for $60.00 US to:"
cr
cr ." Address: Tom Zimmer            Phone: (408) 263-8859 evenings (7pm-9pm pst)"
cr ."          292 Falcato Drive            (415) 327-8800 days     (9am-5pm pst)"
cr ."          Milpitas, Ca. 95035   Outside US orders add 20 dollars."
cr
cr ." You will receive the TCOM compiler, its source, the source for SETMODE and"
cr ." the source for a many other TCOM example programs on 3.5 inch 1.44 meg disks."
cr
cr ." Example programs include:
cr ."   ZLIST  file viewer       SZ    small editor      VED    Virtual Editor"
cr ."   LOOK   file searcher     ZTREE disk space util   TIMEIT elapse timer"
cr ."   MANGEN Mandelbrot draw   TETRA a game            RINGS  screen saver"
cr
cr ." plus more than 40 others, plus F-PC, the FULL Forth system on which TCOM is"
cr ." built. This package totals almost five megabytes installed, with full source."
cr              ;

: main          ( -- )
                DECIMAL                         \ always select decimal
                ?DS: SSEG !                     \ init search segment
                CAPS ON
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                DOS_TO_TIB                      \ move command tail to TIB
                hex                             \ use HEXDECIMAL number base
                bl word c@ 0=
                if      .info bye
                then
                here ?uppercase number? nip  \ get a number, if good
                if      dup vmode!              \ set the video mode
                else    ." The video mode number must be specified in HEX."
                then    2drop ;

