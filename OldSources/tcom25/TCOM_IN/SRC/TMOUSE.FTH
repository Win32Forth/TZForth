\\ TMOUSE.SEQ    Mouse driver software, requires MOUSE.SYS      by Ray Isaac

  Mouse support for Forth.  Adding mouse support to a program is (if you
have looked at this file) not a trivial problem.  The technique chosen here
is to install a driver at the level of KEY? which monitors the movement of
the mouse and turns on its cursor if it is moved. A press of a key restores
the normal terminal cursor.

  In this system only the outside buttons of a three button mouse are used.
The left button is used to select or trigger an operation, while the right
button is always equivelant to the ESC key, which will usually cancel an
operation.

  This generic mouse driver is enhanced at each application level that wants
to use the mouse with an application specific button driver.  The application
level button drivers are installed into the defered word DOBUTTON.  The
button driver is expected to interpret the button presses, and perform the
appropriate function.  Several button drivers are already present in F-PC,
which can be used as examples for how to make button drivers.  See the
file MOUSEY.SEQ for further information.

  The mouse is automatically initialized at program boot time, if you want
to disable or re-enable the mouse after program boot time, you can use the
following words:

        HIDE.MOUSE      disables mouse operation
        SHOW.MOUSE      enables mouse operation if a mouse driver present

  This code was originally written by Ray Isaac at Calos Systems.

  This code has been extensively modified and extended by Tom Zimmer at
Maxtor.
**************  UPDATE *********************
I changed from the forth generated (cursor) mouse cursor to the mouse
interupts HARDWARE mouse cursor.  Mainly to provide a separate text
cursor and a separate mouse cursor while in the editor. MDC  26/08/90

*************** UPDATE by Tom Zimmer 03/30/91 13:25:13.45 **************
Integrated this file and MOUSEY2.SEQ into F-PC. Made a minor change to
prevent the mouse cursor from showing up on the screen until it is
actually moved.  Some people may have a mouse driver installed, but not a
mouse. It is pretty irritating to have a mouse cursor in the middle of
your screen and not be able to get rid of it.  Thank you Mike Christopher
for this nice mouse driver enhancement.

************** UPDATE by Tom Zimmer 12/09/92 15:56 *********************
        Updated and changed to TMOUSE.SEQ for the TCOM compiler.

{

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

0 value mouseflg        \ is the mouse currently turned on?
0 value havemouse       \ was a good mouse driver present at boot?
0 value badmouse        \ non-zero if bad  driver present
0 value #buttons        \ number of mouse buttons on this mouse

code show.ms    ( -- )          \ turn On the hardware mouse cursor
                push bx
                mov ax, # 1     \ we are using hardware cursor
                int  $33        \ call the mouse driver.
                                \ increments the hide mouse count, and
                                \ actually shows the mouse cursor when the
                                \ hide counter reaches zero.
                pop bx
                mov &> g-enabled? # 0h word
                mov &> g-color    # -1 word
                ret     end-code

code hide.ms    ( -- )          \ turn OFF the hardware mouse cursor
                push bx         \ save top of stack (BX) to return stack
                mov ax, # 2     \ use this to hide mouse before screen updates
                int  $33        \ call the mouse driver.
                                \ decrements the hide mouse counter by one
                pop bx          \ recover saved BX
                mov &> g-enabled? # 0h word
                mov &> g-color    # -1 word
                ret     end-code

code reset.mouse ( --- )        \ Reset the mouse if a good driver present
                push bx
                mov ax, # 0             \ mouse driver reset function code
                int  $33                \ call mouse driver
                cmp ax, # 0             \ if it returns a zero, then no mouse
             0= if      /nostack1
                        mov &> badmouse # true word     \ mark a no mouse
                        pop bx                          \ restore saved BX
                        ret                             \ and return
                then
                                        \ default mouse conditions are:
                                        \ 1. mouse in center of screen
                                        \ 2. display page for mouse is zero
                                        \ 3. mouse pointer is hidden.
                                        \    Forces the hide counter to -1
                                        \ 4. pointer shape arrow in graphics
                                        \ 5. pointer shape block in text mode
                                        \ 6. light pen emulation enabled
                                        \ 7. horizontal mickey ratio 8 to 8
                                        \ 8. vertical mickey ratio 16 to 8
                                        \ 9. mouse pointer limits are set to
                                        \    the current matching the
                                        \    current screen display mode.
                mov &> #buttons bx      \ save the number of mouse buttons
                mov &> badmouse # false word    \ clear bad mouse flag
                mov ax, # 14            \ function code to disable light pen
                                        \ emulation.  Mouse driver turned
                                        \ on emulation as the default in
                                        \ function 0 above.
                int  $33                \ call mouse driver.
                mov &> mouseflg  # false word   \ defaults to hidden
                mov &> havemouse # true word    \ but we have a mouse
                pop bx
                ret     end-code

code getmous    ( --dx dy buttons.status )      \ get mouse information
                                \ button.status is 1, 2 or 4 for left,
                                \ right or middle button.
                                \ dx & dy are in screen pixel resolution
                save_bx
                mov ax, # 03
                int  $33
                sub si, # 4
                mov 2 [si], cx
                mov 0 [si], dx
                ret     end-code

code setmous    ( x y -- )      \ set mouse position in pixels on screen
                mov dx, bx              \ get Y position in pixels
                lodsw
                mov cx, ax              \ get X position in pixels
                mov ax, # $04           \ function four, set mouse position
                int $33
                load_bx
                ret     end-code

: nomouse       ( --- )                 \ mark us as not having a mouse
                off> mouseflg
                off> havemouse ;

code mouse.limit! ( x y -- )            \ adjust mouse scaling for display
                mov cx, # 0
                mov dx, bx
                mov ax, # 08            \ set max Y
                int  $33
                mov cx, # 0
                lodsw
                mov dx, ax
                mov ax, # 07            \ set max x
                int  $33
                load_bx
                ret     end-code

code mouse.sense! ( x y double -- )
                mov     dx, bx
                lodsw
                mov     cx, ax
                load_bx
                mov     ax, # 001Ah
                int     33h
                load_bx
                ret             end-code

code mouse.sense@ ( -- x y double )
                save_bx
                mov     ax, # 001Bh
                int     33h
                save_bx
                mov bx, cx
                save_bx
                mov bx, dx
                ret             end-code

: mousebutton   ( --- n1 )              \ n1=0,1,2,4 or a combination
                mouseflg 0= if false exit then
                getmous nip nip 7 and ;

: hide.mouse    ( --- )                 \ turn off the mouse cursor
                mouseflg 0= ?exit
                hide.ms
                off> mouseflg ;

: show.mouse    ( --- )                 \ enable display of mouse cursor
                havemouse 0= ?exit
                show.ms
                on> mouseflg ;

: initmouse     ( --- )                 \ initialize the mose if present
                nomouse
                0 204 @L 0<>            \ interupt vector $33 may be ok
                                        \ if it is <>0
                if      reset.mouse
                then
                ;

FORTH TARGET >TARGET

