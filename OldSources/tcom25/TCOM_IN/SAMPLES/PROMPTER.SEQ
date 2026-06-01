\\ PROMPTER.SEQ         A user prompting program        Tom Zimmer

  A program to prompt for user input, and pass that input off to another
program. Useful mostly to apply automatic prompting to programs that
don't automatically prompt for input when the user doesn't supply it.

  You can add as much or as little prettiness to the prompt as you like.

  To compile PROMPTER.SEQ, enter the following command line

       TCOM PROMPTER /OPT /NOINIT <enter>

{

82 array abuf           \ a place to build a command line to execute

: main          ( -- )
                DECIMAL                         \ always select decimal
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                0 SET_MEMORY                    \ minimize memory ueage
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                #tib @ 0=                       \ was input on command line?
                if      ." Enter parameters "   \ if not, then prompt for
                        query                   \ some parameters
                then
                " DIR "         abuf place      \ the command to do
                0 word count    abuf +place     \ append users parameters
                abuf $sys drop ;                \ shell out and doit

}
