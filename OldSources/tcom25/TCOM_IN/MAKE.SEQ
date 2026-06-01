\\ MAKE.SEQ                  TCOM Simple MAKE             by Tom Zimmer


        A simple MAKE program.

        .options /opt /noinit
{

: .makehelp     ( -- )
        cr ." MAKE is used in the following .MAK file form:"
        cr
        cr ."         MAKE <makefile>.MAK"
        cr
        cr ." The <namefile>.MAK file contains line sequences like the following:"
        cr ."   ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿"
        cr ."   ³target target ... : {\path;\path;...} dependent dependent ...         ³"
        cr ."   ³        command                                                       ³"
        cr ."   ³        @command                      <- invisible command            ³"
        cr ."   ³        "              '"' emit
                       ." *ERROR*"      '"' emit
                               ."  search_file message <- if string found in file,     ³"
        cr ."   ³        ...                              stop make and issue message  ³"
        cr ."   ³; a comment line starts with a semicolon                              ³"
        cr ."   ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ"
        cr ." When a 'target' either doesn't exist, or is older than any 'dependent'"
        cr ." file, then the 'command' lines following it are performed."
        cr
        cr ."   Target lines ALWAYS begin in the first column of a line."
        cr ."   Command lines NEVER begin in the first column of a line."
        cr ."   Lines beginning with a semicolon (;) are comments."
        cr ."   Blank lines are ignored."
        cr ."   MAKE terminates if the quoted string is found in 'search_file'."
        cr ;

CODE GET_FILE_DATE&TIME       ( handle# -- file-time file-date )
                                                \ handle# is in bx
                mov ax, # $5700                 \ Function ah=$57, al=$00
                int $21                         \ gets the time & date
                dec si
                dec si
                mov 0 [si], cx                  \ the time to the stack
                mov bx, dx                      \ the date over it
                ret      end-code

\ **********************************************************************
\ **********************************************************************

  0 value pathlen
  0 value pathptr
132 array paths$
   handle pathhndl

: PATH1         ( --- A1 )      \ return the first path, always current dir
                paths$ count !> pathlen        \ and length
                             !> pathptr        \ Reset the path pointer
                pathhndl dup>r clr-hcb          \ clear out the handle
                r@ pathset drop r> ;            \ install current directory

: NPATH         ( --- A1 F1 )           \ f1 = true if end of list
                pathptr pathlen                 \ a1 n1
                2dup ';' scan                   \ a1 n1 a2 n2
                1- 0MAX !> pathlen              \ set new length
                dup 1+ !> pathptr               \ and pointer
                nip over - dup pathhndl c!      \ set handle length
                pathhndl 1+ swap cmove          \ move the data
                pathhndl c@ >r
                pathhndl count + 1- c@ '\' <>
                if      " \" pathhndl +place
                then    pathhndl r> 0= ;

: PREPEND.APATH ( a1 hndl --- a1 )
                dup c@ >r                       \ save length of handle
                swap                            \ bring name to top
                dup  2+ c@ ':' =                \ do we already have a drive?
                over 1+ c@ '\' = or             \ or a path specified?
                r> 0= or 0=                     \ or handle is empty
                                                \ skip prepend if we do
             if dup c@ >r >r                    \ save name location & length
                r@ 1+ over c@ r@ + 1+ r@ c@ cmove> \ make room for path
                dup r@ over c@ 1+ cmove         \ move in path
                r> r> over c+!                  \ correct count
             then  nip ;

handle dthndl

64 array $FILE_BUF

: "file         ( a1 n1 -- f1 )         \ f1 = true if failed to open
                2dup 2>r $file_buf place
                $file_buf path1 prepend.apath
                dthndl $>handle
                dthndl hopen dup
                if      0=
                        begin   2r@ $file_buf place
                                npath   0=
                                if      $file_buf swap prepend.apath
                                        dthndl $>handle
                                        dthndl hopen 0=
                                else    drop 0= true
                                then
                        until
                then    2r> 2drop ;

: "filedt       ( a1 n1 -- <date&time> f1 )     \ f1=true if opened
                "file 0=                                \ open the file
                if      dthndl >hndle @                 \ get the handle#
                        get_file_date&time              \ get date&time
                        dthndl hclose drop              \ close the file
                        true
                else    false
                then    ;

handle chkhndl

: check-terminate? ( -- a1 n1 f1 )      \ return file for stop string
                chkhndl clr-hcb                 \ pre-clear our handle
                chkhndl save!> seqhandle        \ setup for line reading
                filepointer 2@ 2>r
                here count 1 /string            \ strip off " symbol
                2dup '"' scan 2dup 2>r nip -    \ parse out " delimited string
                here place                      \ put at here
                2r> 1 /string                   \ strip off trailing " symbol
                bl skip                         \ skip blanks
                2dup bl scan 2dup 2>r nip -     \ parse out filename
                                                \ and save remaining line
                chkhndl place                   \ lay it in our handle
                chkhndl hopen
                if      cr ." Couldn't open: " chkhndl count type abort
                then    ibreset
                false                           \ initially flag not found
                begin   lineread c@             \ while lines in file
                while   here count outbuf count search nip or
                repeat
                chkhndl hclose drop
                2r> rot                 \ remaining line text string and flag
                2r> filepointer 2!
                restore> seqhandle
                filepointer 2@ seqhandle movepointer
                ibreset fillbuff
                lineread drop ;         \ discard this line, already processed

132 array dependents
132 array targets

0 value ?buildall               \ are we rebuilding the entire project?
0 value do-command?             \ should we do any following commands
0 value did-command

: set_paths     ( a1 n1 -- )
                bl skip paths$ place ;

: set_targets   ( a1 n1 -- )
                targets place ;

: set_dependents ( a1 n1 -- )
                bl skip dependents place ;

2variable targetdt
2variable dependdt

: check_targets ( -- )
                $7FFF.FFFF targetdt 2!
                targets count
                begin   2dup bl scan 2dup 2>r nip - dup
                while   "filedt
                        if      targetdt 2@ dmin targetdt 2!
                        else    on> do-command?         \ if not found, then
                                2r> 2drop exit          \ *** EXITS HERE ***
                        then                            \ and do the commands
                        2r> bl skip
                repeat  2r> 2drop 2drop
                0.0 dependdt 2!
                dependents count
                begin   2dup bl scan 2dup 2>r nip - dup
                while   "filedt
                        if      dependdt 2@ dmax dependdt 2!
                        else    cr ." Dependent file doesn't exist: "
                                dthndl >pathend" type
                                on> did-command
                        then
                        2r> bl skip
                repeat  2r> 2drop 2drop
                targetdt 2@ dependdt 2@ d<      \ out of date?
                ?buildall or                    \ or building everything
                dependents c@ 0= or             \ or no dependents specified
                !> do-command? ;

: new_target    ( a1 -- )
                off> do-command?        \ initialize to don't do commands
                count 2dup              \ parse out the target names
                begin   bl scan bl skip                 \ discard all blanks
                        over c@ ':' = over 0= or        \ stop at end of ':'
                until   2dup 2>r nip -
                set_targets
                2r> 1 /string                           \ skip ':' & 1 char
                2dup '{' scan dup                       \ paths?
                if      2swap 2drop                     \ discard prev part
                        1 /string                       \ strip 1 char
                        2dup '}' scan 2dup 2>r nip -
                        set_paths
                        2r> 1 /string
                else    2drop
                then
                set_dependents
                check_targets ;

256 array long_buf

: ?too_long     ( a1 -- )
                c@ 120 >
        if      cr ." ***** The above MAKE line is TOO LONG ************************************** " "
                cr ." Single or concatinated MAKE lines must be no longer than 120 characters."
                cr abort
        then    ;

: do_commandline ( -- )         \ shell to dos and perform a command line
                here count -trailing + 1- c@ '\' =      \ continuation marker?
        [long]  if                      \ Then start appending lines together
                        here count -trailing long_buf place  \ lay in line

                        begin   bl long_buf count + 1- c!    \ '\' to blank
                                lineread count bl skip 2-    \ skip blanks
                                cr ." ++> " 2dup type        \ show line
                                long_buf +place              \ append to buf
                                outbuf c@ 0=                 \ till empty line
                                outbuf count + 3 - c@ '\' <> \ or no '\' char
                                or
                                long_buf ?too_long
        [long]          until
                        long_buf $sys drop
                else    here ?too_long
                        here $sys drop
                then    ;

: new_command   ( a1 -- )
                count bl skip here place
                here c@ 2 >                     \ line len > 2 characters?
                do-command? and 0= ?exit        \ and the command flag true?
                here 1+ c@ '"' =                \ starts with " symbol
                if      check-terminate?        \ if string found in file
                        if      cr type
                                bye             \ then terminate NOW
                        then    2drop EXIT      \ else just exit word now
                then
                here 1+ c@ '@' <>       \ if starts with @, don't disp
                if      at? drop 2 >    \ output CR if not near left
                        if      cr
                        then    ." >>> " here count type
                else    here count 1 /string here place
                then    do_commandline
                on> did-command
                at? at  ;       \ re-syncronize cursor position

0 value just-got?               \ did we just get a target check

: do-make-line  ( a1 -- )       \ process the counted line string a1
                crlf>bl's
                dup  1+ c@ ';' <>                       \ if not comment ';'
                if      dup 1+ c@ bl <>                 \ & starts with non-bl
                        if      just-got? do-command? and 0=
                                if      new_target      \ non blank line start
                                        on> just-got?   \ got a comparison
                                then
                        else    new_command             \ blank line start
                                off> just-got?          \ mark no got target
                        then
                else    drop                        \ discard comments
                then    ;

: ?/build       ( -- )          \ should be rebuild the entire project?
                >in @ bl word 1+ " /B" caps-comp 0=
                if      drop    on>  ?buildall
                else    >in !   off> ?buildall
                then    ;

: make-init     ( -- )
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $0 SET_MEMORY                   \ default to min code space
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                LINEREAD_INIT  ;                \ initialize LINEREAD

: main          ( -<make_filename>- )   \ make the file "make_filename"
                make-init
                at? 1 max at            \ synconize cursor positions
                " MAK" defext place     \ change the default file EXTention
                bl word $hopen
                if      ." Couldn't open .MAK file!"
                        .makehelp
                else    ?/build
                        begin   lineread dup c@
                        while   do-make-line
                        repeat  drop
                        close
                        did-command 0=
                        if  cr ."   ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿"
                            cr ."   ³ THIS PROJECT IS ALREADY UP TO DATE ! ³"
                            cr ."   ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ"
                            cr  3 tenths
                        then
                then    ;

