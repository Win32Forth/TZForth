\\ TCOM80 Example                                       by Tom Zimmer

  An example application file for TCOM80.EXE.  When TCOM80 compiles this
application, it includes only the functions needed to perform the
requested operations.  Note the first line of MAIN says "DECIMAL CAPS ON".
This line performs needed initialization to set the number base, and
select case insensitivity.

{

.options /header

3 constant three        INCLUDEWORD THREE
4 constant four         INCLUDEWORD FOUR

: MAIN          ( -- )
                DECIMAL CAPS ON
                three four + drop bye ;

\S      ********************** STOP HERE **************************
\ **********************************************************************

  You might also try this definition for MAIN:

: MAIN          ( -- )
                DECIMAL CAPS ON
                three four + . bye ;

  You will be amazed at how much larger the generated image gets. TCOM80
will automatically include all of the functions needed to perform the
extra "." you added.

\ **********************************************************************

  One last example to build an intaractive Forth kernel.

FLOAD INC80.SEQ                 \ load all library function

: MAIN          ( -- )          \ setup an entry point
                COLD ;

  If you tcom the above lines, TCOM80 will build an image that will
include all of the library functions, and will run an interpretive
Forth system.  Here is the TCOM80 command line:

                TOM80 TEST /HEADER

  The /HEADER option is needed to make TCOM80 include the needed symbols
in the compiled target image.  Without the symbols, you won't be able
to interact with the program.

  After compiling with the above line, startup the Z80 emulator as
follows:

                Z80MU <enter>           the emulator starts up

                READ TEST.CPM           read in the compiled image

                G 100                   go execute at $100

  The interpretive Forth should have signed on, and will be waiting
for you to type in a command. Try typing "WORDS <enter>".  You can leave
by typing "BYE <enter>".


