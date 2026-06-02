\\ G.SEQ         GO to a directory in a list     by Tom Zimmer

  This little program is actually a ripoff of another public domain
program of unknown origin. It changes from your current directory to a
directory whose alias name is specified in a file GO.DAT. It is very
convenient to be able to go to a long directory path name by specifying a
short string. This function is essentially identical to the public domain
program, but in addition I have added the ability to display both help
and a list of the aliases in your Go.DAT file by typing "G" alone on the
command line. You can also follow "G alias" with a dos commandline and
it will be performed after changing to the directory. If "/R" is placed
between the alias and the commandline, then G will return to the
original directory after performing the commandline.

  The format of GO.DAT is very simple, it consists of a series of lines
where the first word is the alias and the second string (space delimited)
is the drive and directory.  The drive should always be specified with
the directory for proper operation.

{
handle prevdir
handle newdir
0 value dirreturn
64 array endbuf

: %.help        ( -- )
        ." ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿" cr
        ." ³ Tom's GOTO program (public domain) updated 03/21/94 by Tom Zimmer with TCOM.³" cr
        ." ³   Changes to a drive and directory aliased to a string in GO.DAT,           ³" cr
        ." ³   then performs the <optional command line> with optional return </R>.      ³" cr
        ." ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´" cr
        ." ³ GO.DAT format is (one entry per line, place file in root of boot drive):    ³" cr
        ." ³   alias_directory_name    Drive:\directory <optional command line>          ³" cr
        ." ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´" cr
        ." ³ Usage: G <directory alias> </Return> <optional command line>                ³" cr
                ;

: .help         ( -- )
                cr %.help
        ." ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ" cr
                ;

: g.dat_open    ( -- )
                seqhandle clr-hcb
                comspec$ count seqhandle place          \ use BOOT drive!
                seqhandle dup >pathend over - 1- swap c!
                seqhandle c@ 3 min seqhandle c!
                " GO.DAT" seqhandle +place
                seqhandle hopen
                if      cr ." Couldn't open GO.DAT"
                        .help abort
                then    ibreset ;

: g.dat_close   ( -- )
                seqhandle hclose drop ;

: skiptodir     ( -- a1 n1 )
                outbuf count 2- 0max            \ line addr & length
                bl skip bl scan bl skip         \ skip directory token
                2dup bl scan 2dup 2>r nip -     \ parse out directory spec
                2r> bl skip endbuf place ;      \ save remainder in ENDBUF

: selectdir     ( a1 n1 -- f1 ) \ found token, now change to directory
                over c@ upc 'A' - setdrive          \ select the drive
                newdir ">handle
                newdir setdir 0= dup 0=
                if      ." Invalid directory"
                then    ;

: tabs>spaces   ( -- )          \ change all tabs in outbuf to spaces
                outbuf count
                begin   9 scan dup
                while   over bl swap c! 1 /string
                repeat  2drop ;

: finddir       ( -- )          \ find a directory and go there
                g.dat_open              \ open the data file
                begin   lineread c@ 0=
                        tabs>spaces
                        outbuf 1+ here count 1+ caps-comp 0= or
                until   outbuf c@
                if      skiptodir selectdir
                        endbuf c@ over and
                        if      endbuf $sys drop
                                drop false              \ don't do rest
                                prevdir count selectdir drop
                        then
                else    ''' emit here ?UPPERCASE count type ''' emit
                        ."  was not found in '"
                        seqhandle ?UPPERCASE count type ''' emit
                        cr ." Type:  G ?  for help with Tom's GO program!"
                        false
                then    ;

: dorest        ( -- )          \ do the remaining part of the command line
                >in @ bl word 1+ " /R" caps-comp 0=     \ line has /R?
                if      drop on> dirreturn              \ then turn on return
                else    >in !                           \ else restore >IN
                then    0 word c@               \ get the rest of the line
                if      here $sys drop
                then    dirreturn               \ are we returning
                if      prevdir count selectdir drop
                then    ;

: savecurdir    ( -- )          \ save current drive and path for restoral
                " A:\" prevdir place
                0 25 bdos dup 'A' + prevdir 1+ c! 1+    \ set drive
                prevdir 4 + swap pdos
                abort" Failed to read current directory"
                prevdir 1+ dup 63 0 scan drop swap - prevdir c! ;

: get_1line     ( -- n1 )
                begin   lineread c@ 2 >                 \ maybe only CRLF
                        if      outbuf c@ EXIT          \ leave if good line
                        then    outbuf c@ 0=            \ try again is short
                until   0 ;                             \ else return DONE

: listdir       ( -- )          \ list directories in GO.DAT
                g.dat_open              \ open the data file
                %.help
        ." ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´"
                begin   get_1line
                while   cr ." ³"
                        outbuf crlf>bl's count 39 min type
                        40 sp>col ." ³"
                        get_1line
                        if      outbuf crlf>bl's count 38 min type
                        then    78 sp>col ." ³"
                        ?keypause
                repeat  cr
        ." ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ"
                ;

: main          ( -<directory_token>- ) \ change to directory matching token
                DECIMAL                 \ always select decimal
                CAPS ON                 \ ignore cAsE
                ?DS: SSEG !             \ init search segment
                50 FUDGE !              \ init MS timer, GUESS!!
                DOSIO_INIT              \ init EMIT, TYPE & SPACES
                $0000 SET_MEMORY        \ default to 64k code space
                DOS_TO_TIB              \ move command tail to TIB
                COMSPEC_INIT            \ init command specification
                lineread_init           \ init lineread utility
                savecurdir              \ save current directory for later
                bl word c@              \ get the requested directory token
                if      finddir         \ -- f1 = true if we found the dir
                        if      dorest
                        else    here count '?' scan nip
                                if      .help
                                then
                        then
                else    listdir
                then    g.dat_close ;

