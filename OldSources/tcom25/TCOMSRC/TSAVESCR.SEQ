\ SAVESCR.SEQ   Routine to save and restore screen.     by Tom Zimmer

FORTH DECIMAL TARGET >LIBRARY           \ A Library file

0 value cur_svseg                       \ segment of previous saved screen
0 value svsize                          \ size of screen in bytes

: new_svseg     ( --- seg )             \ Get a segment to save screen in
                rows cols 2* * dup =: svsize    \ size of screen
                2+ paragraph alloc 8 =          \ allocate the space
                if      2drop
                        at? 0 0 at
                        ." Failed to allocate memory for screen save! "
                        beep
                        at 0
                else    nip
                then    ;

\ nestable save and restore up to memory allowable times

: savescr       ( --- )
                video-seg @ 0= if vmode.set then
                new_svseg ?dup 0= ?exit                 \ leave if failed
                cur_svseg over 0 !L                     \ save prev in cur
                dup =: cur_svseg                        \ set current
                video-seg @ 0 rot 2 svsize cmovel ;     \ save the screen

: discardscr    ( -- )
                cur_svseg 0= ?exit
                cur_svseg dup 0 @L =: cur_svseg
                dealloc
                if      at? 0 0 at
                        ." Failed to de-allocate memory from screen save! "
                        beep
                        at
                then    ;

: restscr       ( --- )
                cur_svseg 0= ?exit
                cur_svseg 2 video-seg @ 0 svsize cmovel \ Restore screen
                discardscr ;

: prevscr       ( -- )          \ save current scr, and copy previous scr
                cur_svseg 0= ?exit
                cur_svseg >r
                savescr
                r> 2 video-seg @ 0 svsize cmovel ;      \ Restore screen

: origscr       ( -- )
                cur_svseg 0= ?exit
                cur_svseg 0 @L 0= ?exit
                cur_svseg 0 @L
                video-seg @ 0 rot 2 svsize cmovel       \ save the screen
                restscr ;

: recoverscr    ( --- )         \ get a copy of the current saved screen
                cur_svseg 0= ?exit
                cur_svseg 2 video-seg @ 0 svsize cmovel ;

: recoverline   ( n1 --- )      \ get a copy of line n1 from saved screen
                cur_svseg 0= if drop exit then
                dup 0 rows 1- between
                if      cols 2* * >r            \ Restore line n1
                        cur_svseg r@ 2+ video-seg @ r> cols 2* cmovel
                else    drop
                then    ;

FORTH TARGET >TARGET

