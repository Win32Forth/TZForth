\\ DRAW.SEQ     A simple Graphics Drawing program        by Tom Zimmer

  Simple drawing program, runs in 640x480 mode


                .options /opt /noinit
{

needs graph.seq

16 constant drawtop

0 value passcnt
0 value wasdown?                \ was mouse down last time around the loop?

: wait_mouse_up ( -- )
                begin   getmous         \ wait till mouse
                        nip nip 0=      \ button is released
                until   ;

: show_color    ( n1 -- )       \ show the current drawing color
                14 3
                do      dup dup 10 + i hline
                loop    drop ;

: show_colors   ( -- )
                save> color
                16 0
                do      i color !
                        330 i 12 * + show_color
                loop
                restore> color ;

: .draw_info    ( -- )
                save> color
                ltgray color !
                64 1 p-at
    ." ³ ESCape to quit ³ Erase Screen ³                        ³ Draw Color  "
                ltgray color !
                67      638        0 hline
                white color !
                0       639  drawtop hline
                0       639      479 hline
                drawtop 479        0 vline
                0       479      639 vline
                show_colors
                restore> color
                620 show_color ;


: .help_info    ( -- )
                hide.mouse
                10 3 70 24 box&fill
        bcr ."     DRAW is a demo program for the TCOM Forth Compiler"
        bcr
        bcr ."     It has limited capabilities, but illustrates the"
        bcr ."     limited graphics support of the TCOM compiler."
        bcr
        bcr ."    Click with the left mouse button on the color bar to"
        bcr ."     select the DrawColor, then draw on the screen using "
        bcr ."     the left mouse button."
        bcr
        bcr ."    The middle button clears the screen."
        bcr
        bcr ."    The right button draws with an 8 pixel high line."
        bcr
        bcr ."    Click Erase Screen above to erase this message"
        bcr
        bcr ."    F1  will display this help window again, but will"
        bcr ."         also overwrite any drawing you have made on the"
        bcr ."         screen."
                   show.mouse ;

: clear_window  ( -- )
                hide.mouse
                640x480x16
                .draw_info
                show.mouse
                ;

: #.position    ( x y n1 -- x y )       \ and show mouse position
                passcnt and 0=
                if      hide.mouse
                        2dup swap 0 1 p-at 3 .r 4 .r
                        show.mouse
                then    incr> passcnt ;

: graph_bye     ( -- )          \ cleanup stuff when we are all done
                text-mode 0 1 at
cr ." DRAW.COM is a public domain example program by Tom Zimmer."
cr
cr ." DRAW was written in Forth and compiled with the TCOM Target Compiler."
cr
cr ." If you would like to have the source for DRAW and other TCOM example"
cr ." programs, send a check for $60.00 US to:"
cr
cr ." Address: Tom Zimmer            Phone: (408) 263-8859 evenings (7pm-9pm pst)"
cr ."          292 Falcato Drive            (415) 327-8800 days     (9am-5pm pst)"
cr ."          Milpitas, Ca. 95035   Outside US orders add 20 dollars."
cr
cr ." You will receive the TCOM compiler, its source, the source for DRAW and"
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
                dup 320 <                       \ less than color bar?
                if      dup 70 200 between      \ in range of Quit bar
                        if      drop
                                graph_bye       \ then terminate program
                        else    200 >=          \ in range of Clear Screen
                                if      clear_window    \ clear window
                                then                    \ else do nothing
                        then
                else                            \ then must be in color bar
                        330 - 0max 12 /  15 min color !
                        620 show_color
                then
                wait_mouse_up
                off> wasdown?
        else    swap         1  max 638 min
                swap drawtop 1+ max 478 min
                wasdown? 0=             \ first time mouse dn
                if      2dup moveto     \ set start location
                        on> wasdown?    \ mark as down already
                then                    \ then draw a line
                hide.mouse
                255 #.position
                nline show.mouse
        then    ;

2variable fromto

: button_right  ( x y -- x y )          \ right button
                dup drawtop <
                if      button_left exit
                then
                hide.mouse
                swap         1   max 638 min
                swap drawtop 4 + max 478 min
                wasdown? 0=             \ first time mouse dn
                if      2dup fromto 2!  \ set start location
                        on> wasdown?    \ mark as down already
                then
                4 -4
                do      fromto 2@ i + moveto
                        2dup      i + nline
                loop    2dup fromto 2!
                127 #.position
                show.mouse
                ;

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
                ?vmode 7 = ?terminate                   \ init graphics
                640x480x16                              \ set graphics mode
                initmouse                               \ init mouse
                havemouse 0= ?terminate                 \ leave if no mouse
                show.mouse                              \ show the mouse
                40 50 setmous                           \ set default position
                white color !                           \ default color=white
                .draw_info                              \ draw screen
                .help_info                              \ show help window
                begin   getmous                         \ get mouse status
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


