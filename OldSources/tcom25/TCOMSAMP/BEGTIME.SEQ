\\ BEGTIME.SEQ                  Written by Bob Smith  12/07/92 14:20

        .OPTIONS /OPT /DEFINIT

BEGTIME <filename> will append the current date and time to the specified
file.  If no file is specified, a default file name JOBCLOCK.DOC will
be used.  If the file does not exist, one will be created.  The date
and time will be preceeded by the string  START: .

BEGTIME is meant to be used with ENDTIME in a batch file to keep track
of how computer time is being used for specific jobs.  An simple example
of a batch file follows:

        BEGTIME MYJOB.DOC
        MYTASK parameter-list
        ENDTIME MYJOB.DOC
        rem Invoke some editor to more fully document the task just done.
        Z MYJOB.DOC

ENDTIME will calculate the elapsed time and append it to the file.

{


FLOAD C:\TCOM\TFILEIO.SEQ
FLOAD C:\TCOM\SRC\TTIMER.SEQ

HANDLE TIMEKEEP.HAN           \ HANDLE FOR THE .SYJ SYMBOL FILE OF A MODULE
CREATE JOB-CLOCK  ," JOBCLOCK.DOC"
CREATE EOL  $0D C, $0A C,
CREATE LINEBUFFER 65 ALLOT

: INIT   ( -- )
        timekeep.han clr-hcb                    \ preclear our handle
        read-write                              \ the file will be read/write
        bl word c@ 0=                           \ was a filename specified?
        IF      job-clock timekeep.han $>handle \ if not, use default name
        ELSE    here      timekeep.han $>handle \ else use name specified
        THEN    timekeep.han hopen              \ try to open, if it failed
        IF      timekeep.han hcreate            \ then try to create it
                IF      cr ." Can not open file: "
                        timekeep.han count type
                        cr cr ABORT             \ abort on failed to create
                THEN
        THEN    ;

: START-TIMER  ( -- )
        init
        eol 2 linebuffer place                  \ start with crlf
        timekeep.han endfile timekeep.han movepointer
        " START: " linebuffer +place
        getdate form-date count linebuffer +place
        "  " linebuffer +place
        gettime form-time 1+ 5 linebuffer +place
        eol 2 linebuffer +place
        linebuffer count timekeep.han hwrite
        timekeep.han bclose drop ;

: MAIN  ( -- )
\       DECIMAL                         \ always select decimal
\       INIT-CURSOR                     \ get intial cursor shape
\       MARGIN_INIT                     \ initialize margins & TAB
\       50 FUDGE !                      \ init MS timer, GUESS!!
\       CAPS ON                         \ ignore cAsE
\       ?DS: SSEG !                     \ init search segment
\       DOSIO_INIT                      \ init EMIT, TYPE & SPACES
\       $FFF0 SET_MEMORY                \ default to 64k code space
\       DOS_TO_TIB                      \ move command tail to TIB
\       COMSPEC_INIT                    \ init command specification
        START-TIMER ;

