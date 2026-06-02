\\ CARDFILE.SEQ  A simple cardfile program for F-PC      by Tom Zimmer
.options /opt /noinit /nostack  \ compiler directives for this program

  ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
  ³ Here is a simple Card File type database, as an example of how to make ³
  ³ a relatively small application.                                        ³
  ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

                Compile with: TCOM CARD <Enter>

  **************************************************************************

{

: ebuffer       ( -- )
                empty-buffers ;

16 constant l/blk
64 constant c/l

 0 value rolo-blk       \ current record #
 0 value rolo-maxblk    \ highest valid record #
 8 value rolo-x         \ left side of window
 5 value rolo-y         \ right side of window
 0 value rolo-curx      \ cursor positon column
 0 value rolo-cury      \ cursor positon line
 0 value rov/ins        \ overwrite/insert flag
 0 value multi?         \ are we displaying multiple cards

4 array curpossave      \ really a 2variable
4 array rrecloc

32 array rlook.buf
0 value rfound

: ?ropen        ( --- f1 )      \ return bool true if ON FILE IS OPEN
                blkhndl >hndle @ 0< dup
                if      24 6 56 9 box&fill
                        ."  There must be a file open to" bcr
                        ."     perform this operation."
                then    ;

: set_curfound  ( a1 n1 -- )
                =: rolo-blk
                c/l /mod =: rolo-cury =: rolo-curx
                on> rfound ;

                \ ** It wasn't in current record, search the rest ***
: rfind_rest    ( -- )
                rolo-maxblk 1+ rolo-blk 1+ over min
                ?do     rrecloc 2@ at i 3 .r
                        rlook.buf count i block b/buf
                        search
                        if      i set_curfound
                                leave
                        else    drop
                        then
                loop    ;

: set_found     ( a1 -- )
                1+ c/l /mod +!> rolo-cury +!> rolo-curx
                rolo-curx c/l /mod +!> rolo-cury =: rolo-curx
                on> rfound ;

: rfnext        ( --- )
                ?ropen ?exit
                cursor-off
                savescr
                15 11 60 13 box&fill
                space >rev ."   Searching for .... "
                rlook.buf count type 59 #out @ - spaces >norm
                off> rfound
                rlook.buf count                 \ look for this
                rolo-blk block                  \ address of record
                                                \ in this space
                rolo-curx 1+ c/l 1- min
                rolo-cury c/l * + b/buf 1- min
                dup>r + b/buf r> - 0max search
                if      \ *** we found text in current record, step to it ***
                        set_found
                else    drop
                        rfind_rest
                then
                rfound 0=
                if      29 14 50 16 box&fill
                        space >rev ."   Text Not found  " >norm beep
                        1 seconds
                then    restscr cursor-on ;

: rfind         ( --- )
                ?ropen ?exit
                savescr
                15 06 64 09 box&fill
                space >rev ."  Text to look for: " >norm
                ."   <Enter>=accept ESC=cancel"
                17 8 at rlook.buf count 20 swap over 1- min #expect
                span @ rlook.buf c!
                esc_flg @ 0= ( --- f1 )
                if      rfnext
                then restscr ;

handle rhndl

: empty_file    ( -- )          \ make the file new and empty
                flush
                rhndl blkhndl b/hcb cmove
                0 buffer b/buf blank
                update flush
                blkhndl hclose drop
                blkhndl hopen drop ;

: rnew          ( --- )
                savescr
                15 6 64 09 box&fill
                space >rev ."  Open/make a file: " >norm
                ."   <Enter>=accept ESC=cancel"
                rhndl clr-hcb
                17 8 at rhndl 1+ 29 expect
                esc_flg @
                if      restscr exit
                then    span @ rhndl c!
                rhndl c@ 0=
                if      " UNTITLED.BLK" ">$ rhndl $>handle
                then    0 rhndl count + c!
                rhndl hopen
                if      rhndl hcreate 0=
                        if      empty_file
                        else    20 6 60 8 box&fill
                                ." Could not CREATE file!" beep
                                1 seconds
                        then
                else    20 6 60 8 box&fill
                        ."  That file already exists, switching"
                        1 seconds
                        flush
                        rhndl blkhndl b/hcb cmove
                then
                rhomer
                restscr
                init-rolodex ;

: rnewr         ( --- )         \ Append a new record to current database
                ?ropen ?exit
                rolo-maxblk 1+ buffer b/buf blank
                update flush
                init-rolodex
                rolo-maxblk =: rolo-blk
                rhome rhome ;

: rtoblk        ( --- )
                ?ropen ?exit
                savescr
                20 6 60 9 box&fill
                ."  Edit what record number? "
                tib 6 expect span @ #tib ! >in off
                bl word number? nip
                if      1- 0max rolo-maxblk min =: rolo-blk
                        bcr ."  Selecting record " rolo-blk 1+ 3 .r 5 tenths
                else    bcr space >rev ."  INVALID RECORD# " >norm
                        1 seconds
                then    restscr ;

: rdtgl         ( --- )         \ switch between display modes
                ?ropen ?exit
                multi? 0= =: multi? ;

: rquit         ( --- )         \ close the file and leave cardfile.
                0 23 at
                flush                   \ write any updated records to disk
                blkhndl hclose drop    \ close the file
                restscr                 \ restore the screen
                curpossave 2@ at
                cursor-on
                ABORT ;                   \ and leave

: rdos          ( --- )
                flush
                savescr                 \ save the screen
                dark
                cr >rev ."  Type EXIT to return to F-PC. " >norm cr
                here dup off $sys dup 2 =
                if      ."  Couldn't find COMMAND.COM  "
                then    8 =
                if      ." Not enough memory to run DOS"
                then
                restscr ;

: .stat-rolodex ( --- )
                5 rolo-y 3 - at
                ."  Current Record is " #out @ #line @ rrecloc 2!
                rolo-blk 1+ 3 .r
                ."  of " rolo-maxblk 1+ 3 .r ."  Records"
                ."   Cursor is at Column " rolo-curx 2 .r
                ."  Line " rolo-cury 2 .r ;

: init-rolodex  ( --- )
                blkhndl endfile b/buf um/mod nip 1- 0max =: rolo-maxblk
                empty-buffers
                off> multi?
                off> rolo-blk
                off> rolo-curx
                off> rolo-cury
                rlook.buf off
                -1 =: mcol
                .menubar                        \ display the menubar
                 off> mcol
                                                \ make status line
                4 rolo-y 4 - 2dup 72 2 d+ box&fill
                                                \ make edit border
                rolo-x 1- dup>r rolo-y 1- 2dup c/l 2+ l/blk 1+
                d+ dup>r box&fill
                r> r> 2dup 2+ swap at >rev ."  ESC=MENU " >norm
                3 - swap 2+ 2dup at eeol at
                ." Currently editing "
                blkhndl >hndle @ 0<
                if      ." NO FILE "
                else    blkhndl count type
                then    ;

: rchaddr       ( --- a1 )              \ address of current character
                rolo-curx rolo-cury c/l * + rolo-blk block + ;

: rfdel         ( --- )                 \ forward delete a character
                ?ropen multi? or ?exit
                rchaddr dup 1+ swap c/l rolo-curx - 2dup 2>r
                1- 0max cmove 2r> + 1- bl swap c! update ;

: rdel<>bl's    ( --- )                 \ delete NON-blanks to the right
                64 0
                do      rchaddr c@ bl = ?leave
                        rfdel
                loop    ;

: rdelbl's      ( --- )
                64 0            \ delete blanks to the right
                do      rchaddr c@ bl <> ?leave
                        rfdel
                loop    ;

: rwdel         ( --- )                 \ right word delete
                ?ropen multi? or ?exit
                rchaddr c@ bl <>
                if      rdel<>bl's
                then    rdelbl's ;

: rins          ( --- )                 \ insert toggle
                rov/ins 0= =: rov/ins
                rov/ins
                if      big-cursor
                else    norm-cursor then ;

: rhome         ( --- )
                off> rolo-curx ;

: rrhome        ( --- )                 \ go to BEGINNING of line
                rolo-curx 0=
                if      off> rolo-cury
                else    rhome
                then    ;

: rend          ( --- )                 \ go to END of line
                c/l 1- =: rolo-curx
                c/l 1- 0
                do      rchaddr 1- c@ bl <> ?leave
                        rolo-curx 1- 0max =: rolo-curx
                loop    ;

: rhomer        ( --- )                 \ go to first record
                off> rolo-blk
                rrhome rrhome ;

: rendr         ( --- )                 \ go to last record
                rolo-maxblk =: rolo-blk
                rrhome rrhome ;

: rldel         ( --- )                 \ line delete
                ?ropen multi? or ?exit
                rhome  rchaddr dup c/l + swap
                rolo-blk block b/buf +
                dup>r over - cmove
                   r> c/l - c/l blank update ;

: rnext         ( --- )
                rolo-blk 1+ rolo-maxblk min =: rolo-blk ;

: rprev         ( --- )
                rolo-blk 1- 0max =: rolo-blk ;

: rup           ( --- )                 \ go UP
                multi?
                if      rprev
                else    rolo-cury 1- 0max =: rolo-cury
                then    ;

: rdown         ( --- )                 \ go DOWN
                multi?
                if      rnext
                else    rolo-cury 1+ l/blk 1- min =: rolo-cury
                then    ;

: rnext2         ( --- )
                multi?
                if      l/blk 2/ 0 do rnext  loop
                else    rnext
                then    ;

: rprev2         ( --- )
                multi?
                if      l/blk 2/ 0 do rprev  loop
                else    rprev
                then    ;

: rret          ( --- )                 \ down to beginning of next line
                multi?
                if      rdtgl exit
                then    rov/ins         \ we are in insert mode
                                        \ and last line empty
                rolo-blk block l/blk 1- c/l * + c/l bl skip nip 0= and
                if      rolo-curx 0=
                        if      rchaddr dup c/l +
                                rolo-blk block b/buf +
                                over - 0max cmove>
                                rchaddr c/l blank update
                        then
                then    rhome  rdown ;

: rright        ( --- )                 \ go RIGHT
                rolo-curx 1+ c/l 1- >
                if      rhome  rdown
                else    incr> rolo-curx then ;

: rleft         ( --- )                 \ go LEFT
                rolo-curx 1- 0<
                if      rolo-cury 0>
                        if    rup rend then
                else    decr> rolo-curx
                then    ;

: rlword        ( --- )
                rleft
                begin   rchaddr c@ bl =         \ while on a blank
                        rolo-curx rolo-cury or
                        and                     \ and not at start of record
                while   rleft                   \ skip spaces
                repeat
                begin   rchaddr 1- c@ bl <>
                        rolo-curx rolo-cury or
                        and
                while   rleft
                repeat  ;

: rrword        ( --- )
                begin   rchaddr c@ bl <>
                        rolo-curx c/l 1- =
                        rolo-cury l/blk 1- = and 0= and
                while   rright
                repeat
                begin   rchaddr c@ bl =
                        rolo-curx c/l 1- =
                        rolo-cury l/blk 1- = and 0= and
                while   rright
                repeat  ;

: rinschar      ( c1 --- )      \ insert the character c1 in current record
                multi?
                if      drop
                else    rchaddr >r
                        rov/ins
                        if      r@ dup 1+ c/l rolo-curx - 1- cmove>
                        then    r> c! update rright
                then    ;

: rbdel         ( --- )                 \ back delete
                ?ropen multi? or ?exit
                rolo-curx 0= rov/ins and
                if      rolo-cury 0<>
                        rup rend rolo-curx 0= and
                        if      rldel
                        then
                else    rleft
                        rov/ins
                        if      rfdel
                        else    bl rchaddr c! update
                        then
                then    ;

: rtab          ( --- )
                ?ropen multi? or ?exit
                rolo-curx 8 mod 8 swap - 0
                ?do     rov/ins
                        if      bl rinschar
                        else    rright
                        then
                loop    ;

: show_rolo_line ( a1 n1 -- a1 )
                over + dup rolo-maxblk <=
                if      dup rolo-blk = if >rev then
                        block c/l type >norm
                else    drop c/l spaces
                then    ;

: show-roloblock ( -- )
                0 23 at         \ in case there is an error
                rolo-blk block
                l/blk 0
                do      rolo-x i rolo-y + at dup c/l type
                        c/l +
                loop    drop ;

: show-rolodex  ( --- )
                cursor-off
                multi?
        [long]  if      rolo-blk l/blk 2/ - 0max
                        l/blk 0
                        do      rolo-x i rolo-y + at
                                i show_rolo_line
                        loop    drop
                else    show-roloblock
                        cursor-on
                then    ;

: rolo-show-cur ( --- )
                rolo-curx rolo-cury rolo-x rolo-y d+ at ;

: ?rcontrol     ( c1 --- c1 )           \ handle control characters
                dup bl >= ?exit
                dup 31 min exec:
\               0 null  1 a     2 b     3 c     4 d     5 e     6 f
                noop    rlword  noop    rnext2  rright  rup   rrword
\               7 g     8 h     9 i     LF      11 k    12 l    Enter
                rfdel   rbdel   rtab    noop    noop    noop    rret
\               14 n    15 o    16 p    17 q    18 r    19 s    20 t
                noop    rnew    noop    noop    rprev2  rleft   rwdel
\               21 u    22 v    23 w    24 x    25 y    26 z    Esc
                noop    rins    noop    rdown   rldel   noop    menu
\               28 \    29 ]    30 ^    31 _
                noop    noop    noop    noop ;

: ?rfunc        ( c1 --- c1 )           \ handle function keys
                dup 128 < ?exit
                dup 142 max 248 min 142 -
                exec:
\ 142                   baktab  AltQ    AltW    AltE    AltR    AltT
                noop    noop    noop    noop    noop    noop    noop
\ 149           AltY    AltU    AltI    AltO    AltP
                noop    noop    noop    rnew    noop    noop    noop
\ 156                           AltA    AltS    AltD    AltF    AltG
                noop    noop    noop    noop    rdtgl   noop   rtoblk
\ 163           Alt-H   AltJ    AltK    AltL
                noop    noop    noop    noop    noop    noop    noop
\ 170                           AltZ    AltX    AltC    AltV    AltB
                noop    noop    noop    noop    noop    noop    noop
\ 177           AltN    AltM
                noop    noop    noop    noop    noop    noop    noop
\ 184                                   F1      F2      F3      F4
                noop    noop    noop    noop    rdtgl   noop    rnewr
\ 191           F5      F6      F7      F8      F9      F10
                noop    rfind   noop    noop    noop    rquit   noop
\ 198                   Home    Up      PgUp            Left
                noop    rrhome  rup     rprev2  noop    rleft   noop
\ 205           Right           End     Down    PgDn    Insert  Delete
                rright  noop   rend     rdown   rnext2  rins    rfdel
\ 212           SF1     SF2     SF3     SF4     SF5     SF6     SF7
                noop    noop    noop    noop    noop    noop    noop
\ 219           SF8     SF9     SF10    ^F1     ^F2     ^F3     ^F4
                noop    noop    noop    noop    noop    noop    noop
\ 226           ^F5     ^F6     ^F7     ^F8     ^F9     ^F10    AF1
                noop    noop    noop    noop    noop    noop    noop
\ 233           AF2     AF3     AF4     AF5     AF6     AF7     AF8
                noop    noop  ebuffer   noop    rfnext  noop    noop
\ 240           AF9     AF10            ^Left   ^Right  ^END
                noop    noop    noop    rlword  rrword  rendr   noop
\ 247           ^HOME   248
                rhomer  noop ;

: ?rchar        ( c1 --- c1 )           \ handle any character entry
                dup bl '~' between
                if      dup rinschar
                then    ;

                                                \ c1 = keyboard character
: rolokey       ( c1 --- )                      \ process a key
                ?rchar                          \ handle normal ascii
                ?rfunc                          \ function characters
                ?rcontrol                       \ control chars
                drop ;

: edit-rolodex  ( --- )
                begin   .stat-rolodex
                        show-rolodex
                        rolo-show-cur
                        key rolokey
\                        50 24 at ." Depth is = " depth h.
                again   ;

: rolodex       ( --- )
                read-write def-rwmode
                at? curpossave 2!               \ save cursor position
                empty-buffers
                savescr                         \ and screen contents
                dark                            \ clear the screen
                ?ds: sseg !                     \ initialize search segment
                tib 20 blank span off #tib off >in off
                blkhndl clr-hcb
                ?cs: dos_cmd_tail c@L 0<>
                if      dos_to_tib              \ move dosline to tib
                        bl word blkhndl $>handle
                        blkhndl hopen drop
                then
                init-menu
                init-rolodex
                10 rolo-x + l/blk 2/ rolo-y + at
                >rev ."   Press F then O to select a file to edit  " >norm
                13 rolo-x + l/blk 2/ rolo-y + 2+ at
                >rev ."   or Press F then Q to Quit Cardfile " >norm
                begin   blkhndl >hndle @ 0<
                while   menu
                repeat
                init-rolodex
                edit-rolodex ;

\       ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
\       ³ This section contains the menus for the rolodex ³
\       ³ This is a good example of menu usage.           ³
\       ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ

5 newmenu rfile$                \ the FILE menu
        menuline"  Open/make a file  Ctrl-O " rnew
        menuline" ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ" noop
        menuline"  DOS commands             " rDOS
        menuline" ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ" noop
        menuline"  Quit Cardfile        F10 " rquit
endmenu

2 newmenu redit$              \ the EDIT menu
        menuline"  Create record           F4 " rnewr
        menuline"  Revert to OLD Rec   Alt-F4 " empty-buffers
endmenu

6 newmenu rselect$              \ the SELECT menu
        menuline"  Goto record#       Alt-G " rtoblk
        menuline" ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ" noop
        menuline"  alt Display           F2 " rdtgl
        menuline" ÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ" noop
        menuline"  Find text             F6 " rfind
        menuline"  Next find         Alt-F6 " rfnext
endmenu

3 newmenubar rbar ," File "     \ the menu bar contains only two items
                  ," Edit "
                  ," Select "
endmenu
create rlist    rfile$ ,        \ and two lists of functions
                redit$ ,
                rselect$ ,

\ initialize the default condition of the menu bar

: init-menu     ( --- )         \ the rolodex7 menu driver
                rbar        =: menubar
                rlist       =: menulist
                ['] rolokey is doother  ;      \ handle keys while in menu

: main          ( -- )
                vmode.set
                300 fudge !
                rolodex ;

?DEFINIT 0= #IF         \ if the /NOINIT option enabled, then include this

: remain        ( -- )
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                main ;

#THEN


