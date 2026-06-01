\\ TIMEIT.SEQ     A DOS command performance measurer      by Tom Zimmer
.options /opt /noinit           \ compiler directives for this program

  This simple little program can be used to measure the amount of time
it takes for various DOS operations or commands to execute. Use TIMEIT
as follows:

                C:>TIMEIT <DOS_command_line> <enter>

  You can time programs, batch files, or anything that executes and
returns to DOS. The execution time is measured in Hours, Minutes,
Seconds, and hundreths. The program load time is also included.

  TIMEIT compiles to around 3.5k, and uses only about 4k of your DOS
program memory, so its no memory hog.

  Compile TIMEIT with the following command line:

                TCOM TIMEIT /OPT /NOINIT <enter>

{

64 array tofile$

: ?/file        ( -</f>- )     \ test for redirect to a file
                >in @
                bl word 1+ " /F" caps-comp 0=
                if      drop
                        bl word c@ 0= abort" No redirection file specified"
                        here count tofile$ place
                else    >in !
                then    ;

: main          ( -- )
                DECIMAL                         \ always select decimal
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                PAD 100 + SET_MEMORY            \ minimize memory usage
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                ?/file                          \ redirect to a file?
                tofile$ c@ 0=
                if      .date space .time
                then
                time-reset
                0 word  c@
                if      tofile$ c@
                        if      "  >" here +place
                                tofile$ count here +place
                        then
                        here $sys drop
                then    at? at
                tofile$ c@ 0=
                if      cr .date space .time
                then    .elapsed cr ;

}
