\\ TMENU.SEQ     Visual menu selection tool for TCOM     by Tom Zimmer

History:

 01/21/92 08:52:15.05 tjz
        Added additional verification to MENULINE" to detect the use of
        a MACRO as the lines function, and issue an error message.

{

FORTH DECIMAL >FORTH ONLY FORTH ALSO COMPILER ALSO HOST ALSO DEFINITIONS

                                        \ n1 = number of menu entries
                                        \ a1 = address filled by MENULINE"
                                        \ n2 = running total of menu length
: newmenubar    ( n1 | <name> --- a1 )  \ make a menubar of <name>
                0 tarray
                here-d 1+ swap dup c,-d 2* allot-d ;

' newmenubar alias newmenu
' drop       alias endmenu

                                        \ a1 = address of count of strings
                                        \ n1 = current running total of lines
                                        \ string" = menu text line to display
                                        \ function = functio name for line
                                        \ n1+1 = resulting running total
                                        \ compile a new menu line
: menuline"     ( a1 | string" function --- a1 )
                ,"                                      \ lay in string
                F' dup >dtype c@ {s} <>                 \ check func type
                if      0 " MACRO NOT allowed as menu function"  "errmsg
                then    >resaddr @ over !-d 2+ ;        \ lay function in

ONLY FORTH ALSO COMPILER ALSO HOST ALSO HTARGET ALSO TARGET ALSO DEFINITIONS
FORTH DECIMAL TARGET >LIBRARY       \ A Library file

defer doother           \ what to do with other keys

0 value mline           \ display menu starting line
0 value mcolumn         \ display menu starting column

0 value mcol            \ current menu column
0 value mrow            \ Item to hilight in column
0 value menukey
0 value menubar         \ return address of the menubar itself
0 value menulist        \ return address of the menus on bar

: >strings      ( a1 n1 -- a2 n1 )
                tuck 2* + swap ;

: mhoriz   ( a1 --- )              \ display a horizontal menu
                mcolumn mline at
                0 swap count >strings 0
                do      i mcol =
                        if      nip #out @ swap >rev
                        else    >bold
                        then    space count 2dup type +
                loop    drop
                >bold cols #out @ - spaces >norm
                ( col --- ) cursor-on 1+ mline at ;

: mvert     ( a1 --- )              \ display a vertical menu
                >r menubar count 2* + dup >r
                mcol 0max 0
                ?do     count +
                loop    r> -            \ calculate the column of vert menu
                mcolumn +
                mline 1+                \ row number of vertical menu
                r@ count 2* + c@     \ width
                >r over r> + 1+ over r@ c@ + menubox
                0 0     \ default cursor location if not in any menu row.
                r> count >strings 0
                do      tx 1+ ty i + at
                        i 1+ mrow =
                        if      >r 2drop
                                #out @ #line @ r>
                                >rev
                        then    count 2dup type + >norm
      [Llong]  loop    drop at ;

HTARGET DEFINITIONS TARGET

: domfunc       ( col row --- )         \ perform function for menu item
                >r 2* menulist + @ 1+ r> 1- 0max 2* + @
                cursor-on
                execute
                cursor-off ;

                                \ find the first uppercase letter in string
: ucscan        ( a1 --- c1 )   \ a1 is a counted string, c1 = char or NULL
                0 swap count bounds
                ?do     i c@ 'A' 'Z' between
                        i c@ '0' '9' between or
                        if      drop i c@ leave
                        then
                loop    ;

: 1st-rowchar   ( --- c1 )              \ return first char of row message
                mcol 2* menulist + @    \ addr of menu list
                count >strings
                mrow 1- min 0MAX 0
                ?do     count +         \ step to next item
                loop    1+ c@ ;

: ?menu_name    ( a1 -- a1 f1 )
                dup ucscan dup 0= or bl or menukey bl or = ;

: ?menuname     ( c1 f1 -- c1 f2 )
                0 menubar count >strings 0
                do      ?menu_name
                        if      over =: mcol
                                1 =: mrow
                                2swap 2drop 0 0
                                2swap
                                leave
                        else    swap 1+ swap
                                count +
                        then
                loop    2drop ;

: ?found_name   ( a1 -- a1 f1 )
                dup ucscan bl or menukey bl or = menukey bl <> and ;

: ?name_inmenu  ( c1 f1 -- c1 f2 )
                mcol  2* menulist + @         \ addr of menu list
                1 swap count >strings 0
                ?do     ?found_name
                        if      drop =: mrow
                                13              \ 13 = return
                                false           \ process command
                                2swap
                                leave
                        else    swap 1+ swap    \ bump count
                                count +         \ step to next item
                        then
                loop    2drop ;

: ?menukey      ( c1 f1 --- c1 f2 )     \ sets mcol  or mrow
                over =: menukey
                mrow 0=                         \ are we on the menubar
                if      menukey 13 =            \ did we press <enter>
                        if      1 =: mrow       \ pop down menu
                                drop true
                        else    ?menuname       \ else search for menu name
                        then
                else    ?name_inmenu    \ search for name in current menu
                then    ;

: ?mup          ( c1 -- c1 )
                dup 200 <> ?exit        \ UP
                0=
                mrow 1- 0MAX =: mrow
                begin   1st-rowchar 196 =       \ skip over horizontal line
                        mrow 0> and
                while   mrow 1- 0MAX =: mrow
                repeat  ;

: ?mdown        ( c1 -- c1 )
                dup 208 <> ?exit        \ DOWN
                0=
                mrow 1+
                mcol  2* menulist + @ c@ dup>r min =: mrow
                begin   1st-rowchar 196 =       \ skip over horizontal line
                        mrow r@ < and
                while   mrow 1+ r@ min =: mrow
                repeat  r> drop ;

: ?mhome        ( c1 -- c1 )
                dup 199 <> ?exit        \ HOME
                0=
                mrow 0=                 \ if 0 then
                if      0 =: mcol       \ home to left
                else    0 =: mrow
                then    ;

: ?mend         ( c1 -- c1 )
                dup 207 <> ?exit        \ END
                0= mcol  2* menulist + @ c@ =: mrow ;

: ?mright       ( c1 -- c1 )
                dup 205 =               \ RIGHT
                over bl = or 0= ?exit
                0=
                recoverscr
                mcol menubar c@ 1- =
                if      0
                else    mcol   1+ menubar c@ 1- min
                then    =: mcol
                mrow 1 min =: mrow ;

: ?mleft        ( c1 -- c1 )
                dup 203 <> ?exit        \ LEFT
                0=
                recoverscr
                mcol 0=
                if      menubar c@ 1-
                else    mcol   1- 0MAX
                then    =: mcol
                mrow 1 min =: mrow ;

: ?domkey       ( c1 --- c1 | 0 )
                ?mhome  ?mend   ?mright ?mleft  ?mup    ?mdown
                dup 13 = if 0= then ;

TARGET DEFINITIONS

: .menubar      ( --- )
                menubar mhoriz ;

: .menu         ( --- )
                menulist mcol 2* + @ mvert ;

: showmenus     ( --- )
                mrow 0>
                if      .menubar .menu
                else    recoverscr .menubar
                then    ;

: menu          ( --- )
                savecursor              \ save cursor position
                cursor-off
                0 =: mrow
                savescr                 \ Save original screen
                mcol >r
                -1 =: mcol .menubar     \ display menubar without hilite
                r> =: mcol
                savescr                 \ save it again
                begin   showmenus
                        key dup 27 <>           \ while not ESC
                           over 13 <> and       \ and not carraige return
                        ?menukey                \ or menu key
                        if      ?domkey
                        then    ?dup
                until
                restscr restscr                 \ Recover original screen
                restcursor
                dup     13 =                    \ is char a Carraige Return
                if      drop
                        mcol mrow domfunc       \ then do the function
                else    dup 27  =
                        if      drop            \ discard if ESC
                        else    doother         \ else process OTHER key
                        then
                then    ;

FORTH TARGET >TARGET

\s      ******** HERE IS AN EXAMPLE OF A SIMPLE SET OF MENUS ********

: adummy        ( -- )
                beep ;

4 newmenu dfile$
        menuline"  1 Dummy    F1 " adummy
        menuline"  2 Dummy    F1 " adummy
        menuline"  3 Dummy    F1 " adummy
        menuline"  4 Dummy    F1 " adummy
endmenu

3 newmenu dedit$
        menuline"  5 Dummy    F1 " adummy
        menuline"  6 Dummy    F1 " adummy
        menuline"  7 Dummy    F1 " adummy
endmenu

2 newmenubar mymenubar
," File  " ," Edit "
endmenu

create mymenulist    dfile$ , dedit$ ,

: myother       ( c1 -- )
                drop ;

: menuinit      ( -- )          \ MENUINIT must be called before calling
                                \ MENU to startup menu use.
                vmode.set       \ you must use direct video mode for menus
                ['] myother is doother
                mymenubar   =: menubar
                mymenulist  =: menulist ;



