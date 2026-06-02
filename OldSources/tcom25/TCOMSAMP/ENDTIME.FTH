\\ ENDTIME.SEQ                          by Bob Smith  12/07/92 14:22

        .OPTIONS /OPT /DEFINIT

ENDTIME <filename> will append the current date and time to the specified
file.  If no file is specified, a default file name JOBCLOCK.DOC will
be used.  The date and time will be preceeded by the string  END:    .
Finally the elapsed time will be computed based on the starting time
presumably written to the file from BEGTIME .  It is assumed that the
dates will change by no more than one day.   (Obviously this program
could be easily made smarter than that).  The final elapsed time
is appended to the file.

ENDTIME is meant to be used with BEGTIME in a batch file to keep track
of how computer time is being used for specific jobs.  An simple example
of a batch file follows:

        BEGTIME MYJOB.DOC
        MYTASK parameter-list
        ENDTIME MYJOB.DOC
        rem Invoke some editor to more fully document the task just done.
        Z MYJOB.DOC

{

FLOAD C:\TCOM\TFILEIO.SEQ
FLOAD C:\TCOM\SRC\TTIMER.SEQ

HANDLE TIMEKEEP.HAN           \ HANDLE FOR THE .SYJ SYMBOL FILE OF A MODULE
CREATE JOB-CLOCK  ," JOBCLOCK.DOC"
CREATE EOL  $0D C, $0A C,
CREATE LINEBUFFER 65 ALLOT
CREATE STARTBUFFER 30 ALLOT

: INIT   ( -- )
        timekeep.han clr-hcb
        read-write
        bl word c@ 0=
        IF      job-clock timekeep.han $>handle
        ELSE
                here timekeep.han $>handle
        THEN
        timekeep.han hopen                      \ open the file
        IF      cr ." Can not open file: "
                timekeep.han count type
                cr cr ABORT
        THEN ;

: ASCII>BIN   ( char -- val )   $30 - ;

: BIN>ASCII   ( val -- char )   $0F and $30 + ;

: HH:MM>BIN   ( addr -- val )
        dup c@ ascii>bin 10 *           \ 10 hours
        over 1+ c@ ascii>bin + 60 *     \ unit hours
        over 3 + c@ ascii>bin 10 * +    \ 10 minutes
        swap 4 + c@ ascii>bin + ;       \ unit minutes

CREATE MINBUF  10 allot

: BIN>HH:MM   ( val -- addr cnt )
        0 1440 um/mod drop
        0 60 um/mod             ( minutes hours )
        10 /mod                 ( minutes unit-hrs 10-hrs )
        bin>ascii minbuf c!
        bin>ascii minbuf 1+ c!
        10 /mod                 ( unit-mins 10-mins )
        bin>ascii minbuf 3 + c!
        bin>ascii minbuf 4 + c!
        ':' minbuf 2 + c!
        minbuf 5 ;

: ELAPSED-TIME  ( -- n )
        linebuffer 17 + hh:mm>bin
        linebuffer 8 +
        startbuffer 8 comp
        IF      1440 +          \ if dates are not equal, assume 1 day diff.
        THEN
        startbuffer 9 + hh:mm>bin - ;

: END-TIMER  ( -- )
        init
        timekeep.han endfile 2dup 16 0 d- timekeep.han movepointer
        startbuffer 16 timekeep.han hread 16 <>
        IF      cr ." Bad read of JOBCLOCK.DOC " cr
        THEN
        timekeep.han movepointer
        " END:   " linebuffer place
        getdate form-date count linebuffer +place
        "  " linebuffer +place
        gettime form-time 1+ 5 linebuffer +place
        eol 2 linebuffer +place
        linebuffer count timekeep.han hwrite
        elapsed-time bin>hh:mm
        " ELAPSED TIME:   " linebuffer place
        linebuffer +place
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
        END-TIMER ;

