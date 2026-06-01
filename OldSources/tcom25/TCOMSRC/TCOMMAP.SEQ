\ TCOMMAP.SEQ           Generate the .MAP file

0 value m-seg

\ : .map
\         cr ." -------------------"
\         cr segments
\         begin   @ dup                           \ for each segment
\         while   dup 2+ @                        \ get segment start
\                 dup !> m-seg over 4 + @   \ get segment end
\                 over umax                       \ end must be above start
\                 swap - dup
\                 if      over body> >name name> ['] no-name <>
\                         if      over body> >name .id
\                         else    ." Unnamed segment"
\                         then    18 sp>col
\                         m-seg    5 u.r
\                         dup      8 u.r
\                         m-seg +  7 u.r 4 spaces cr
\                 else    drop
\                 then
\         repeat  drop key drop ;

: MERGE-SEGS    ( -- )
                [forth]
        segments
        begin   @ dup !> m-seg
        while   segments @
                begin   dup>r                   \ for each segment
                while   r@ 2+  @                \ get segment start
                        r@ 4 + @                \ get segment end
                        over umax               \ end must be above start
                        swap -                  \ if segment not empty
                        if      r@ 2+ @ m-seg 4 + @ =           \ end=start
                                if      r@ 4 + @ dup            \ get new end
                                        m-seg 4 + !             \ set it
                                        r@ 2 + !                \ zero seg
                                else    r@ 4 + @
                                        m-seg 2+ @ =            \ start=end
                                        if      m-seg 4 + @
                                                dup r@ 4 + !
                                                m-seg 2 + !
                                        then
                                then
                        then    r> @
                repeat  r>drop
                noop m-seg
        repeat  ;


\ : MAKEMAP       ( -- )          \ make a .MAP file
\                 [forth]
\                 merge-segs
\         base @ >r hex
\         segments
\         begin   @ dup                           \ for each segment
\         while   dup 2+ @                        \ get segment start
\                 dup !> m-seg over 4 + @   \ get segment end
\                 over umax                       \ end must be above start
\                 swap - dup
\                 if      m-seg               5 u.r
\                         dup                 8 u.r
\                         dup m-seg + 1- 0max 7 u.r 4 spaces
\                         cr
\                 then    drop
\         repeat  drop
\         r> base !
\         at? atsave 2! ;

