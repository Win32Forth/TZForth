\\ DOODLE.SEQ     A simple Graphics Drawing program        by Tom Zimmer

  Simple drawing program, runs in 320x200 mode


                .options /opt /noinit
{

needs graph.seq

8 constant drawtop

0 value passcnt
0 value wasdown?                \ was mouse down last time around the loop?

: wait_mouse_up ( -- )
                begin   getmous         \ wait till mouse
                        nip nip 0=      \ button is released
                until   ;

: show_color    ( n1 -- )       \ show the current drawing color
                drawtop 1- 0
                do      dup dup 5 + i hline
                loop    drop ;

: show_colors   ( -- )
                save> color
                #colors 16 min 0
                do      i color !
                        160 i 6 * + show_color
                loop
                restore> color ;

: .draw_info    ( -- )
                save> color
                ltgray color !
                8 0 at
                ." ³QUIT³CLEAR³            ³COLOR "
                white color !
                0       hdots 1-  drawtop  hline
                0       hdots 1-  vdots 1- hline
                drawtop vdots 1-        0  vline
                drawtop vdots 1-  hdots 1- vline
                show_colors
                restore> color
                hdots 14 - show_color ;

: .help_info    ( -- )
                hide.mouse
\                " +-+||+-+" drop !> boxchars
                1 2 38 20 box&fill \ true <box>
                bcr
                bcr ."   DOODLE  is a demo program for"
                bcr ."  the TCOM Forth Compiler"
                bcr
                bcr ."  Click with the left mouse button"
                bcr ."  on the color bar to select a color,"
                bcr ."  then draw using the left mouse
                bcr ."  button."
                bcr
                bcr ."  Middle button clears the screen."
                bcr
                bcr ."  Right button draws with an four"
                bcr ."  pixel high line."
                bcr
                bcr ."  Click |CLEAR| above to erase scrn."
                show.mouse ;

: clear_window  ( -- )
                hide.ms
                320x200x16
                .draw_info
                show.ms ;

: #.position    ( x y n1 -- x y )       \ and show mouse position
                passcnt and 0=
                if      hide.mouse
                        2dup swap 0 0 at 3 .r 4 .r
                        show.mouse
                then    incr> passcnt ;

: graph_bye     ( -- )          \ cleanup stuff when we are all done
                text-mode 0 1 at
cr ." DOODLE.COM is a public domain example program by Tom Zimmer."
cr
cr ." DOODLE was written in Forth and compiled with the TCOM Target Compiler."
cr
cr ." If you would like to have the source for DOODLE and other TCOM example"
cr ." programs, send a check for $60.00 US to:"
cr
cr ." Address: Tom Zimmer            Phone: (408) 263-8859 evenings (7pm-9pm pst)"
cr ."          292 Falcato Drive            (415) 327-8800 days     (9am-5pm pst)"
cr ."          Milpitas, Ca. 95035   Outside US orders add 20 dollars."
cr
cr ." You will receive the TCOM compiler, its source, the source for DOODLE and"
cr ." the source for a many other TCOM example programs on 3.5 inch 1.44 meg disks."
cr
cr ." Example programs include:
cr
cr ."   ZLIST file viewer       SZ    small editor      VED    Virtual Editor"
cr ."   LOOK  file searcher     ZTREE disk space util   TIMEIT elapse timer"
cr ."   CLOCK Roman num clock   TETRA a game            VMODE  video mode set"
cr
cr ." and several others, plus F-PC, the FULL Forth system on which TCOM is built."
cr ." This package totals almost five megabytes installed, with full source."
cr              bye ;

: button_left   ( x y -- x y )
                2dup dup drawtop <
                wasdown? 0= and
 [long] if      drop
                dup 152 <                       \ less than color bar?
                if      dup 71 104 between      \ in range of Quit bar
                        if      drop
                                graph_bye       \ then terminate program
                        else    111 >=          \ in range of Clear Screen
                                if      clear_window    \ clear window
                                then                    \ else do nothing
                        then
                else                            \ then must be in color bar
                        160 - 0max 6 /  #colors 16 min 1- min color !
                        hdots 14 - show_color
                then
                wait_mouse_up
                off> wasdown?
        else    swap         1  max hdots 2- min
                swap drawtop 1+ max vdots 2- min
                wasdown? 0=             \ first time mouse dn
                if      2dup moveto     \ set start location
                        on> wasdown?    \ mark as down already
                then                    \ then draw a line
                255 #.position
                hide.ms nline show.ms
        then    ;

2variable fromto

: button_right  ( x y -- x y )          \ right button
                dup drawtop 3 + <
                if      button_left exit
                then
                hide.ms
                swap         1   max hdots 2-  min
                swap drawtop 3 + max vdots 3 - min
                wasdown? 0=             \ first time mouse dn
                if      2dup fromto 2!  \ set start location
                        on> wasdown?    \ mark as down already
                then
                2 -2
                do      fromto 2@ i + moveto
                        2dup      i + nline
                loop    2dup fromto 2!
                63 #.position
                show.ms ;

: button_middle ( -- )
                clear_window
                wait_mouse_up ;

: ?stack_ok     ( -- )
                depth 0= ?exit
                text-mode 0 1 at
                ." Stack DEPTH was NON-ZERO: " depth . bye ;

: ?terminate    ( f1 -- )
                abort" Sorry, VGA Color and a mouse are required!" ;

: tcom_init     ( -- )
                DECIMAL                         \ always select decimal
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                0 SET_MEMORY ;                  \ default to minimum

: graph_draw    ( -- )          \ a simple drawing program
                tcom_init                               \ init I/O
                ?vmode 7 = ?terminate                \ init graphics
                320x200x16                              \ set graphics mode
                8x8font
                initmouse                               \ init mouse
                havemouse 0= ?terminate                 \ leave if no mouse
                show.mouse                              \ show the mouse
                50 vdots 25 - setmous                   \ set default position
                white color !                           \ default color=white
                .draw_info                              \ draw screen
                .help_info                              \ show help window
                begin   getmous                         \ get mouse status
                        rot 2/ -rot
                        CASE
                        1 of    button_left     endof   \ left button
                        2 of    button_right    endof   \ right button
                        4 of    button_middle   endof   \ middle button
                                drop                    \ discard button info
                                4095 #.position         \ show mouse position
                                off> wasdown?           \ reset mouse down
                        ENDCASE 2drop                   \ discard x & y now
                        ?stack_ok
                        key?  dup                       \ till key pressed
                        if      drop key                \ check for our
                                CASE                    \ special keys
                                        27 of  true             endof   \ ESC
                                       187 of  .help_info false endof   \ F1
                                                drop      false
                                ENDCASE
                        then
                until                                   \ till we are done
                hide.mouse                              \ remove mouse cursor
                graph_bye
                ;


