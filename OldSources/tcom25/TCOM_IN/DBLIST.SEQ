\\ DBLIST.SEQ           A file LISTer           written by Tom Zimmer

  DBLIST is a sub module to BUG.SEQ, the application debugger for TCOM.

{

 8192   constant listlimit      \ file buffer size limit
 6144   constant listhi         \ hi water mark for buffer fill
 2048   constant listlo         \ lo water mark for buffer fill
   11      value displaylines   \ number of lines to display on screen
   4       value hiloff         \ hilighted line offset from screen top

\ -------------------------------------------------------------------------
\ Some values needed by program.

0 value listblk                 \ 4k block number of lowest block in memory
0 value listlen                 \ quantity of text in buffer
0 value listoff                 \ offset in buffer of top line of display
0 value listoffmax              \ highest allowable line in this file
0 value listblkmax              \ highest allowable block number
0 value listbuf                 \ pointer to 16k text buffer
0 value listscroll              \ horizontal scrolling offset
0 value lfindbuf                \ search text buffer
0 value lfindoff                \ column offset where text last found
0 value lfound                  \ was text found flag
0 value lfound1st
0 value lfcnt
0 value hilight-off
0 value ip-off
0 value hioff
0 value lincur

\ -------------------------------------------------------------------------

: hiloff_limit  ( -- n1 )
                displaylines 3 / 5 max ;

: hiloff_set    ( -- )          \ set HILOFF to the correct number of lines
                hiloff_limit !> hiloff ;

: deeol        ( -- )          \ erase to end of line
                srcright sp>col ;

: cur_char      ( -- c1 )       \ the current cursor position character
                listbuf to_point + lincur + c@ ;

: left_cur      ( -- )
                decr> lincur
                lincur 10 - listscroll <
                if      listscroll 8 - 0max !> listscroll
                then    lincur 0max !> lincur ;

: right_cur     ( -- )
                incr> lincur
                lincur 70 - listscroll >
                if       8 +!> listscroll
                then    ;

: ?hilight_line ( a1 n1 -- a1 n1 f1 )
                2dup over + hilight-off -rot between ;

: ?ip_line      ( a1 n1 -- a1 n1 f1 )
                2dup over + ip-off -rot between ;

: .hilight_line ( a1 n1 -- )
                >cyan                   \ switch to cyan
                >r dup hilight-off over - dup>r
                srcright 1- >type       \ type leading chars
                ip-@ ipaddr =
                if      >bblue
                else    >blue           \ switch hilight
                then
                r> r> swap /string      \ discard begin string
                2dup bl skip bl scan    \ find a blank
                2dup 2>r nip -
                srcright 1- >type       \ type the word
                >cyan                   \ back to cyan
                2r> srcright 1- >type ; \ type remainder

: .ip_line      ( a1 n1 -- )
                >rev                    \ switch to cyan
                >r dup ip-off over - dup>r
                srcright 1- >type       \ type leading chars
                >bblue
                r> r> swap /string      \ discard begin string
                2dup bl skip bl scan    \ find a blank
                2dup 2>r nip -
                srcright 1- >type       \ type the word
                >rev                    \ back to cyan
                2r> srcright 1- >type ; \ type remainder

: .one_line     ( a1 n1 -- a2 n2 )      \ display one line of screen
                dup 0=
                if      >dkgray
                        srcright sp>col >norm
                        exit                    \ leave here
                then    2dup $0D scan 2dup 2>r nip - listscroll /string
                ?hilight_line
                if      .hilight_line
                else    ?ip_line
                        if      .ip_line
                        else    srcright 1- >type
                        then
                then    srcright sp>col >norm
                2r> 2 /string ;

: .buffer       ( a1 n1 -- )    \ show buffer starting at current disp line
                blinkoff
                at? nip displaylines bounds     \ display rest of screen
                do      1 i at
                        hiloff                  \ hilight line offset
                        btop + i =
                        if      >dkgray
                                over listbuf - !> to_point
                        then    .one_line
                loop    2drop ;

: set_ipaddr    ( -- )
                inx-src-low> inx-src-hi> listblk listlo um* listlimit 0 d+ d<
                inx-src-low> inx-src-hi> listblk listlo um* d> and
                %inx-file#> 0> and
                if      inx-src-low> inx-src-hi> listblk listlo um* d-
                        drop dup listbuf + !> hilight-off !> hioff
                else    off> hilight-off
                then ;

: set_ip@       ( -- )
                ipinx 2@ listblk listlo um* listlimit 0 d+ d<
                ipinx 2@ listblk listlo um* d> and
                %inx-file#> 0> and
                if      ipinx 2@ listblk listlo um* d-
                        drop listbuf + !> ip-off
                else    off> ip-off
                then ;

: dolist        ( -- )          \ list current displaylines of file
                set_ip@
                set_ipaddr
                listbuf listlen listoff /string .buffer ;

: %moveto_source ( d1 -- )
                ?ds: save!> sseg
        ( d1 )  listlo um/mod 2- dup 0max !> listblk
                2+ 2 min listlo * +
                listblk listblkmax >
                if      listblk 1- 0max !> listblk
                        listlo +
                then    >r
                listblk listlo um* src-handle movepointer
                listbuf listlimit src-handle hread !> listlen
                r@ listbuf bounds 1 -/string
                $0A -scan 1 -/string            \ to begin of current line
                r> over - 2- 0max !> lincur     \ set line offset
                hiloff 1- 0max 0                \ hilight line offset
                ?do     $0A -scan 1 -/string
                loop
                if      2+                      \ then step to next line
                then    listbuf - !> listoff    \ set list offset
                restore> sseg ;

: moveto_source ( -- )
                %inx-file#> 0= ?exit
                inx-src-low> inx-src-hi> %moveto_source ;

: +refill       ( -- )          \ refill buffer from previous part of file
                                                \ move back low water mark
                listbuf dup listlo + swap listhi cmove
                listblk 4 + listlo um* src-handle movepointer
                listbuf listhi + listlo src-handle hread
                listhi + !> listlen
                incr> listblk
                listlo negate +!> listoff ;

: %+1line       ( -- n1 )               \ forward a line in the file
                                        \ with auto buffer refilling
                listoff listhi >                \ in last 4k block
                listblk listblkmax < and
                if      +refill
                then
                listbuf listlen listoff /string  $0A scan drop 1+ listbuf - ;

: +1line        ( -- )          \ forward a line in file, limit forward
                                \ movement to top of last screen full in file
                off> lfound
                hiloff hiloff_limit <
                if      incr> hiloff
                        exit
                then
                %+1line
                listblk listblkmax =            \ if at end of file
                if      listoffmax umin         \ then limit to last screen
                then    !> listoff ;

: f+1line       ( -- )          \ forward a line in file, no forward limit
                %+1line !> listoff ;

: -refill       ( -- )          \ refill buffer from next part of file
                listbuf dup listlo + listlen listlo - cmove>
                decr> listblk
                listblk listlo um* src-handle movepointer
                listbuf listlo src-handle hread
                listlen + listlimit umin !> listlen
                listlo +!> listoff ;

: -1line        ( -- )          \ back a line in file with auto buffer
                                \ refilling
                off> lfound
                listoff listlo <
                listblk 0> and
                if      -refill
                then
                listoff 0=
                listoff 2- 0= or
                if      off> listoff
                        hiloff 1- 1 max !> hiloff       \ move up screen
                else    listoff 2- listbuf over + swap
                         $0A -scan drop
                        dup c@ $0A =            \ if we found a LINEFEED
                        if      1+              \ then bump to next char
                        then    listbuf - !> listoff
                then    ;

: lpgdn         ( -- )          \ forward "displaylines" into file
                displaylines 0   do  +1line  loop
                off> lfound ;

: %lpgup        ( -- )          \ backward "displaylines" into file
                displaylines 0   do  -1line  loop  ;

: lpgup         ( -- )
                %lpgup
                off> lfound ;

: lhome         ( -- )          \ to top of file
                0 !> listblk
                0.0 src-handle movepointer
                listbuf listlimit src-handle hread !> listlen
                1 !> hiloff
                off> listoff
                off> listscroll
                off> lfound ;

: %lend         ( -- )          \ to bottom of file, actually limited
                                \ to bottom of file minus one page full
                src-handle endfile listlo um/mod nip 3 - 0max !> listblk
                listblk listlo um* src-handle movepointer
                listbuf listlimit src-handle hread !> listlen
                listlen !> listoff ;

: lend          ( -- )
                %lend
                %lpgup
                hiloff_set
                off> lfound ;

: lleftw        ( -- )          \ scroll screen left
                ?shiftkey
                if      off> lfound
                        listscroll 8 - 0max !> listscroll
[long]          else    left_cur
                        listbuf listlen to_point /string 2dup $0A scan
                        nip - 1- 0max lincur min swap bounds
                        bl -skip bl -scan nip dup if 1+ then !> lincur
                then    lincur 8 - 0max listscroll min !> listscroll ;

: lrightw       ( -- )          \ scroll screen right
                ?shiftkey
                if      off> lfound
                        listscroll 8 + listlo min !> listscroll
[long]          else    listbuf listlen to_point /string 2dup $0A scan
                        nip - 1- 0max lincur /string
                        2dup bl scan bl skip nip - nip +!> lincur
                then    lincur 70 - 0max listscroll max !> listscroll ;

             2 constant b/#browse
b/#browse 60 * constant #bmax
#bmax b/#browse + array browstack

0 value #browsed

: bpush         ( n1 -- )
                browstack #browsed + !
                2 +!> #browsed ;

: bpop          ( -- n1 )
                #browsed 0= abort" Browse stack underflow"
                -2 +!> #browsed
                browstack #browsed + @ ;

: unbrowse_word ( -- )
                hiloff_set
                #browsed
                if      bpop !> to-file#
                        ?open-src-file
                        if      bpop !> lincur
                                bpop bpop %moveto_source
                        else    bpop drop bpop bpop 2drop
                        then
                else    beep
                then    ;

: discard_browse ( -- )
                #browsed 0= ?exit
                bpop bpop 2drop
                bpop bpop 2drop ;

: save_browse   ( -- )
                #browsed #bmax >=       \ if full, discard earliest entry
                if      browstack b/#browse 4 * over + swap #bmax cmove
                        -4 b/#browse * +!> #browsed
                then
                listblk listlo um* to_point lincur + 0 d+ bpush bpush
                lincur bpush cur-file# bpush ;

: position_word ( -- )
                to-file# >r
                sym-file#> !> to-file#
                ?open-src-file
                if      sym-file-off-low> sym-file-off-hi>
                        %moveto_source
                else    beep
                        r@ !> to-file#          \ preserve previous file
                        discard_browse
                then    r>drop ;

: scr_word@     ( -- a1 )       \ extract word under cursor to find buffer
                left_cur
                cur_char bl =
                if      lrightw
                else    right_cur lleftw
                then
                save> lincur
                listbuf listlen to_point /string 2dup $0A scan
                nip - 1- 0max lincur /string 2dup bl scan nip -
                lfindbuf place
                restore> lincur
                lfindbuf ;

: browse_word   ( -- )          \ move source to word under cursor
                save_browse
                hiloff_set
                scr_word@ a-function?
                if      drop
                        position_word
                else    a-data?
                        if      drop
                                position_word
                        else    drop beep
                                discard_browse
                        then
                then    ;

: scr_watch     ( -- )          \ add word under cursor to watch list
                scr_word@ a-data?
                if      lfindbuf add_watch
                else    drop beep
                then    ;

: lafind        ( -- )          \ search for already entered text again
                hiloff_set
                listblk listoff
                lfound
                if      hioff !> listoff
                        f+1line
                then    2>r
                off> lfcnt
                off> lfound
                1 1 btop + at >cyan ."   Searching ..." deeol >norm
                begin   lfindbuf count
                        listbuf listlen listoff /string
                        2dup  $0A scan nip - 1- 0max search 0=
                        listoff listlen < and
                while   drop f+1line
                        incr> lfcnt
                repeat  !> lfindoff
                listoff listlen >=
[long]          if      beep
                        2r> !> listoff !> listblk
                        listblk listlo um* src-handle movepointer
                        listbuf listlimit src-handle hread !> listlen
[long]          else    2r> 2drop
                        on> lfound
                        on> lfound1st
                        ?find_position
                        if      moveto_source
                        then
                then    >norm ;

: lfind         ( -- )          \ enter text and search for it
                1 1 btop + at >cyan ."  Text to find:" deeol >bblue
                on> autoclear
                16 1 btop + lfindbuf 32 lineeditor >norm
                                                        \ get text from user
                if      lafind                          \ and go find it
                then    ;

: lendset       ( -- )          \ set end of file markers
                %lend                   \ goto last displayable screen
                -1line
                -1line
                listoff !> listoffmax           \ set max pameters for later
                listblk !> listblkmax
                lhome                           \ go back to top of file
                hiloff_set ;

: dolistkey     ( c1 -- )       \ handle keys entered by user
                case
        ( ^home )       247 of  lhome           endof   \ top of file
        ( ^end )        245 of  lend            endof   \ end of file
        ( up arrow )    200 of  -1line          endof   \ up one line
        ( down arrow )  208 of  +1line          endof   \ down one line
        ( ^left arrow)  243 of  lleftw          endof   \ scan left  WORD
        ( ^right arrow) 244 of  lrightw         endof   \ scan right WORD
        ( left arrow )  203 of  left_cur        endof   \ left cursor
        ( right arrow ) 205 of  right_cur       endof   \ right cursor
        ( pgup )        201 of  lpgup           endof   \ up 22 lines
        ( pgdn )        209 of  lpgdn           endof   \ down 22 lines
( ************* )        ^W of  -1line          endof   \ up one line
( WordStar type )        ^Z of  +1line          endof   \ down one line
( control keys  )        ^E of  -1line          endof   \ up one line
( for cursor    )        ^X of  +1line          endof   \ down one line
( movement      )        ^R of  lpgup           endof   \ up 22 lines
( ************* )        ^C of  lpgdn           endof   \ down 22 lines
        ( F6 )          192 of  lfind           endof   \ find text
        ( Alt-F6 )      237 of  lafind          endof   \ find text again
        ( Ctrl-L )       ^L of  lafind          endof
        ( F9 )          195 of  browse_word     endof
        ( F10 )         196 of  unbrowse_word   endof
                        upc     \ remaining tests are case insensitive
        ( Find )        'F' of  lfind           endof
                                drop beep
                endcase ;

