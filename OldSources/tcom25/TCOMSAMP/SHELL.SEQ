\\ SHELL.SEQ             A DOS Shell program             by Tom Zimmer
.options /opt /noinit           \ compiler directives for this program

This file demonstrates a simple DOS shell program that will allow directory
traversal, and program execution. Text type filew will be invoked with the
SZ editor in BROWSE mode. Unknown type filew will prompt for a program to
execute with the file as a parameter.

        Compile with: TCOM SHELL /OPT /NOINIT <Enter>

When compiling this program, the "/NOINIT" MUST BE INCLUDED, or SET_MEMORY
will not work properly.

{

0 value dos_buf

: unknown_type  ( a1 -- )
                ?dup 0= ?exit
                cr dup count type
                cr ." I don't know what to do with this file!"
                cr ." Type the name of a program to pass it to,"
                cr ." or press ESC to discard."
                cr ." ->"
                dos_buf 1+ 20 expect span c@ dos_buf c! cr
                esc_flg @ 0= here c@ 0> and
                if      "  "    dos_buf +place
                        count   dos_buf +place
                                dos_buf $dosys
                        key_wait
                else    drop
                then    ;

: $dosys        ( a1 -- )
                dup c@
                if      ." Executing ->" dup count type cr
                then    $sys ?syserror at? 23 min at ;

: key_wait      ( -- )
                cr ." Press a key to return to the shell."
                key drop cr ;

: ?execute_prog ( a1 -- a1 | false )
                dup 0= ?exit
                dup handle>ext
                dup  " .COM" caps-comp 0=
                over " .EXE" caps-comp 0= or
                swap " .BAT" caps-comp 0= or
                if      $dosys false
                        key_wait
                then    ;

handle vhndl

: browse_file   ( a1 -- )
                dup handle>ext 1+ " VID" caps-comp 0=
        if      savescr
                vhndl $>handle
                vhndl hopen 0=
                if      0 4000 vhndl video-seg @ exhread drop
                        vhndl hclose drop
                        key drop
                then
                restscr
        else    " SZ "   dos_buf place
                count   dos_buf +place
                "  /B"  dos_buf +place
                        dos_buf $dosys
        then    ;

: edit_afile    ( a1 -- )
                " SZ "   dos_buf  place
                count   dos_buf +place
                        dos_buf $dosys ;

: DOS_shell     ( a1 -- )
                drop
                dos_buf off
                dos_buf $dosys ;

: ?edit_file    ( a1 -- a1 | false )
                dup 0= ?exit
                dup handle>ext
                dup  " .SEQ" caps-comp 0=
                over " .TXT" caps-comp 0= or
                over " .DOC" caps-comp 0= or
                over " .BAK" caps-comp 0= or
                over " .CFG" caps-comp 0= or
                over " .SYM" caps-comp 0= or
                over " .MAP" caps-comp 0= or
                over " .LST" caps-comp 0= or
                over " .HLP" caps-comp 0= or
                over " .SRC" caps-comp 0= or
                over " .MDF" caps-comp 0= or
                swap @   '.'            = or    \ no extension
                if      browse_file
                        false
                then    ;

: my_winmsg     ( -- )          \ an extra message window to be added to
                                \ the popup window.
                59 06 at ." ÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄ¿"
                59 07 at ."  ³ F1=View file³"
                59 08 at ."  ³ F2=Edit file³"
                59 09 at ."  ³ F3=DOS shell³"
                59 10 at ."  ³F10=Exit prog³"
                59 11 at ."  ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÙ" ;

-1 value spfunc

: ?do_special   ( a1 -- a1 | false )
                spfunc 0< ?exit
                spfunc                  \ get value of spfunc
                -1 =: spfunc            \ reset spfunc to -1
                false -rot              \ ( a1 n1 -- false a1 n1 )
                exec: browse_file edit_afile DOS_shell ;

: my_winkey     ( c1 -- c1 )    \ Extra special functions to be performed
                                \ when specific keys are pressed.
                               -1 =: spfunc
        ( F1 )  dup 187 = if    0 =: spfunc drop 13 exit    then
        ( F2 )  dup 188 = if    1 =: spfunc drop 13 exit    then
        ( F3 )  dup 189 = if    2 =: spfunc drop 00 exit    then
        ( F10)  dup 196 = if                drop 27 exit    then
        ( LF )  dup  10 = if    2 =: spfunc drop 00 exit    then ;

: main          ( -- )          \ the main entry point for the program
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $100 ds:alloc !> dos_buf
                vmode.set
                $0 SET_MEMORY
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                dirinit
                ['] my_winkey is winkey         \ init dirkey function
                ['] my_winmsg is winmsg         \ additional window message
                begin   getfile                 \ -- a1 f1
                while   dup count + off         \ ends in NULL
                        ?do_special
                        ?execute_prog
                        ?edit_file
                        unknown_type
                repeat  drop ;

}

