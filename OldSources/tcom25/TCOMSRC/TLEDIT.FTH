\ LEDIT.SEQ     Line Editor Utility                     by Tom Zimmer

comment:

  Here is a relatively simple editor for editing one line strings.

  Support is provided for strings up to 126 characters in length, with
full word and character operations using keypad or WordStar keys as follows:

        Ctrl-A                  Left word
        Ctrl-S                  Left character
        Ctrl-D                  Right character
        Ctrl-F                  Right word
        Ctrl-G                  Forward delete
        Ctrl-T                  Word delete
        Ctrl-Y                  Line delete or clear
        Left arrow              Left character
        Ctrl-Left arrow         Left word
        Right arrow             Right character
        Ctrl-Right arrow        Right word
        Home                    Beginning of line
        End                     End of line
        ESC                     Discard changes and leave
        Return/Enter            Save changes and leave

  The parameters needed by LINEEDIT are as follows:

        lineeditor    ( x y a1 n1 --- )

                x = char pos on row,    zero = left edge
                y = row number,         zero = top line
                a1 = counted string
                n1 = edit limit length, maximum value = 80

  Here is an example of a command that would edit a line of text in
SAMPLEBUFFER, with a maximum length of 12 characters, at location
row 10 column 5 on the screen.

                5 10 samplebuffer 12 lineedit

  Two auto resetting flags can be used to control the behavior of the
line editor in special ways.

        The STRIPING_BL'S boolean "VALUE" determines whether the line
        editor will strip trailing blanks from an edited string at
        the completion of the edit. this VALUE defaults to TRUE, do
        strip trailing blanks.

                OFF> STRIPPING_BL'S     will prevent line edit from
                                        stripping spaces.

        The AUTOCLEAR boolean "VALUE" determines whether the line
        edit buffer will be automatically cleared if the first
        character you enter on starting an edit is a normal text
        char. This is used to ease the users life in the situation
        where you want to give them the option of re-using a string
        or easily entering a new one without having to delete the old
        string first. This VALUE defaults to FALSE, no autoclear.

                ON> AUTOCLEAR           will cause line edit to
                                        automatically clear the edit
                                        string if a letter if the
                                        first thing entered.

comment;

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

true     value stripping_bl's           \ are we stripping trailing blanks?
false    value autoclear                \ automatically clear line if first
                                        \ type entered is a letter;
      variable insertmode               \ insert/overwrite mode flag

HTARGET DEFINITIONS TARGET      \ hidden from target application

      variable saveflg                  \ are we saving the results

    0    value ?ldone                   \ is line edit done?
    0    value lchar                    \ recent line edit character
    0    value ex                       \ where we are editing X
    0    value ey                       \ where we are editing Y
    0    value ecursor                  \ edit cursor position
    0    value lenlimit                 \ line edit length limit

132 constant maxedit
[forth] maxedit 2+ [target] array editbuf       \ our edit buffer,
\            editbuf off                        \ 132 characters max

: .ecursor      ( --- )                         \ show the cursor
                ex ecursor + ey at ;

: .eline        ( --- )                         \ redisplay edit line
                ex ey at
                editbuf count type
                save> attrib >rev
                lenlimit editbuf c@ - 0MAX
                COLS 1- #out @ - 0MAX min spaces
                restore> attrib ;

: doldel        ( --- )                         \ Line delete
                0 editbuf c!
                off> ecursor ;

: ichar         ( c1 --- )
                autoclear               \ should we clear the line on the
                if      doldel          \ first character typed?
                        off> autoclear
                then
                insertmode @
                if      editbuf 1+ ecursor + dup 1+
                        maxedit ecursor - cmove>
                        editbuf c@ 1+ lenlimit min editbuf c!
                then
                editbuf 1+ ecursor + c!
                ecursor 1+ lenlimit min COLS 1- min =: ecursor
                ecursor editbuf c@ max editbuf c! ;

: ?char         ( --- )                 \ handle normal keys, insert them
                lchar   bl '~' between
                if      lchar ichar
                then    ;

: dohome        ( --- )                         \ beginning of line
                off> ecursor ;

: doend         ( --- )                         \ End of line
                editbuf c@ =: ecursor ;

: doright       ( --- )                         \ right a character
                ecursor 1+ editbuf c@ min COLS 1- min =: ecursor ;

: doleft        ( --- )                         \ left a character
                ecursor 1- 0MAX =: ecursor ;

: edone         ( --- )      \ flag edit is finished, save changes
                on> ?ldone
                saveflg on ;

: equit         ( false --- true )      \ flag edit is finished, discard chngs
                on> ?ldone
                saveflg off ;

: dofdel        ( --- )                         \ Forward delete
                ecursor 1+ editbuf c@ max editbuf c!
                editbuf 1+ ecursor + dup 1+ swap maxedit ecursor - cmove
                -1 editbuf c+! ;

: >to=bl        ( --- )                         \ forward to a blank
                editbuf 1+ dup maxedit + swap ecursor +
                ?do     i c@ bl = ?leave
                        1 +!> ecursor
                loop    editbuf c@ ecursor min =: ecursor ;

: >to<>bl       ( --- )                         \ forward to a non blank
                editbuf 1+ dup maxedit + swap ecursor +
                ?do     i c@ bl <> ?leave
                        1 +!> ecursor
                loop    editbuf c@ ecursor min =: ecursor ;

: dorword       ( --- )                         \ Forward to next word
                >to=bl
                >to<>bl ;

: <to=bl+1      ( --- )                         \ back to char following BL
                ecursor 1- 0MAX =: ecursor
                editbuf 1+ dup ecursor + 1- editbuf 1+ max
                ?do     i c@ bl = ?leave
                        -1 +!> ecursor
            -1 +loop    ;

: <to<>bl       ( --- )                         \ Back to non blank
                ecursor 1- 0MAX =: ecursor
                editbuf 1+ dup ecursor + 1- editbuf 1+ max
                ?do     i c@ bl <> ?leave
                        -1 +!> ecursor
                loop    ;

: dolword       ( --- )                         \ back a word
                <to<>bl
                <to=bl+1 ;

: dobdel        ( --- )                         \ back delete
                ecursor editbuf c@ max editbuf c!
                ecursor         ( --- f1 )
                doleft
    ( --- f1 )  if      insertmode @            \ if we are in insertmode
                        if      dofdel          \ then delete the character
                        else    bl editbuf 1+ ecursor + c!
                                                \ else change char to blank
                        then
                else    beep
                then    ;

: dowdel        ( --- )                         \ word delete
                begin   ecursor editbuf c@ <
                        editbuf 1+ ecursor + c@ bl <> and
                while   dofdel
                repeat
                begin   ecursor editbuf c@ <
                        editbuf 1+ ecursor + c@ bl = and
                while   dofdel
                repeat  ;

: strip_bl's    ( --- )                         \ strip blanks from editbuf
                ecursor >r
                doend
                begin   doleft
                        editbuf 1+ ecursor + c@ bl =
                        ecursor 0<> and
                while   dofdel
                repeat  editbuf c@ r> min 0MAX =: ecursor
                editbuf @               \ get count and first char
                $2001 =                 \ count=1 & char=blank
                if      0 editbuf c!    \ then reset buffer to empty
                then    ;

: doins         ( --- )                         \ toggle insert mode
                insertmode @ 0= dup insertmode !
                if      big-cursor
                else    norm-cursor
                then    ;

: ?control      ( --- )                         \ handle control characters
                lchar   bl >= ?exit
                off> autoclear          \ no auto clear now
                lchar exec:
\               0 null  1 a     2 b     3 c     4 d     5 e     6 f
                noop    dolword noop    noop    doright noop    dorword
\               7 g     8 h     9 i     LF      11 k    12 l    Enter
                dofdel  dobdel  noop    noop    noop    noop    edone
\               14 n    15 o    16 p    17 q    18 r    19 s    20 t
                noop    noop    noop    noop    noop    doleft  dowdel
\               21 u    22 v    23 w    24 x    25 y    26 z    Esc
                noop    doins   noop    noop    doldel  noop    equit
\               28 \    29 ]    30 ^    31 _
                noop    noop    noop    noop ;

: ?func         ( --- )                         \ handle function keys
                lchar   199 < ?exit
                off> autoclear          \ no auto clear now
                lchar 199 - 0MAX 46 min exec:
\       HOME
        dohome
\       UP      PgUp    202     LEFT    204     RIGHT   206     END
        noop    noop    noop    doleft  noop    doright noop    doend
\       DOWN    PgDn    INS     DEL     SF1     SF2     SF3     SF4
        noop    noop    doins   dofdel  noop    noop    noop    noop
\       SF5     SF6     SF7     SF8     SF9     SF10    CF1     CF2
        noop    noop    noop    noop    noop    noop    noop    noop
\       CF3     CF4     CF5     CF6     CF7     CF8     CF9     CF10
        noop    noop    noop    noop    noop    noop    noop    noop
\       AF1     AF2     AF3     AF4     AF5     AF6     AF7     AF8
        noop    noop    noop    noop    noop    noop    noop    noop
\       AF9     AF10    242     CLEFT   CRIGHT
        noop    noop    noop    dolword dorword noop    noop ;

                                                \ c1 = keyboard character
                                                \ f1 = true for done editing
: dokey         ( c1 --- )                      \ process a key
                =: lchar
                ?char                           \ handle normal ascii
                ?func                           \ function characters
                ?control ;                      \ control chars

TARGET DEFINITIONS

                                                \ x = char pos on row
                                                \ y = line number
                                                \ a1 = counted string
                                                \ n1 = edit limit length
: <ledit>       ( x y a1 n1 --- )       \ Edit line currently in EDITBUF.
                save> lenlimit
                savecursor cursor-on
                over c@ ecursor min =: ecursor
                maxedit min =: lenlimit         \ save max edit length
                dup >r                          \ save source address
                editbuf over c@ lenlimit min 1+ cmove
                editbuf c@ lenlimit min editbuf c!
                =: ey =: ex                     \ save origin
                doins   doins
                off> ?ldone
                begin   .eline
                        .ecursor key dokey
                        ?ldone
                until   saveflg @ dup           \ proper save exit
                if      stripping_bl's          \ do we want to strip blanks?
                        if      strip_bl's
                        then    on> stripping_bl's      \ force it next time
                        editbuf r@ over c@ lenlimit min 1+ cmove
                then    r>drop
                restcursor              ( --- f1 )
                restore> lenlimit
                off> autoclear ;                \ no automatic line clear

                                        \ x = char pos on row
                                        \ y = line number
                                        \ a1 = counted string
                                        \ n1 = edit limit length
                                        \ f1 = true for saved changes
                                        \ f1 = false for canceled with ESC
: lineeditor    ( x y a1 n1 --- f1 )    \ Edit line in a1
                off> ecursor
                insertmode off
                <ledit> ;

FORTH TARGET >TARGET

\s

variable samplebuffer 128 allot

: sample        ( --- )
                " Zimmer, Harold" ">$
                samplebuffer over c@ 1+ cmove
                on> autoclear
                27 04 samplebuffer 24 lineeditor drop ;

