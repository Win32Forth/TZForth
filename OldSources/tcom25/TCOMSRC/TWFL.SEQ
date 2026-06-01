\ TWFL.SEQ      Window file selection.                  by Tom Zimmer

FORTH DECIMAL TARGET >LIBRARY       \ A Library file

   handle dirspec$
 10 array defdirspec$
300 value    maxdir             \ maximum directory files to list

defer winkey
defer winmsg

handle dirhndl

10 array itemstk

variable item#
variable flitem

: setfl         ( n1 --- )
                flitem ! ;

\     Item stack used to hold Directory offsets in window while stepping
\     up and down the directory tree.

: 0istk         ( --- )             \ Clear the item stack
                itemstk 10 erase
                item# off ;

: >istk         ( n1 --- )          \ put an item on the item stack
                item# @ itemstk + c!
                item# @ 1+ 9 min item# ! ;

: istk>         ( --- n1 )          \ get an item from the item stack.
                item# @ 1- 0MAX dup item# !
                itemstk + dup c@ swap off ;

   14 constant b/fnam           \ bytes per filename

: #dirsegs      ( -- n1 )
                b/fnam maxdir * paragraph 16 + ;
                                \ room for directory entries plus a couple

   4 value forgx
   3 value forgy                \ top of file window display
   0 value dlen                 \ directory window length
   0 value dirrow
   0 value curfl                \ current file number
   0 value foff

  16 constant dirattrib         \ directory file attribute
     variable aletter

   0 value #fls                 \ number of files present
   0 value dirseg

: 0fl           ( --- )         \ first file
                0 !> curfl
                0 !> foff ;

: dirinit       ( --- )                 \ try to initialize the directory
                dlen ?exit
                rows forgy - 4 - =: dlen
                " *.*" ">$ dirspec$ $>handle
                " *.*"  defdirspec$ place
                0istk 0fl
                ['] noop is winkey
                ['] noop is winmsg ;

: diralloc      ( -- )
                dirseg ?exit
                #dirsegs alloc 8 =
                if      2drop
\ 01/08/92 15:20:50.15 tjz
\                       at? 0 0 at ." No room for directory buffer!, "
\                           0 1 at ." Can't pop up Dir window. Sorry! "
\                       beep
\                       at
                else    nip =: dirseg
                then    ;

: dirrelease    ( -- )
                dirseg 0= ?exit
                dirseg dealloc drop
                off> dirseg ;

: >fadr         ( name# -- seg name_offset )
                b/fnam * 1+ dirseg swap ;

: dir>pad      ( seg off --- a1 n1 )
                2dup c@l >r ?DS: pad r@ 1+ cmovel pad 1+ r> ;

HTARGET DEFINITIONS TARGET

: .nam          ( n1 --- )
                >fadr dup>r dir>pad dup>r type
                12 r> - spaces
                dirseg r> 1- c@l dirattrib and
                if      #out @ 1- #line @ at
                        ." ì"
                then    ;

: name>buf      ( --- )         \ move name from dta to buffer
                #fls >fadr nip >r
                pad 30 + 12 dup 0
                do      over i + c@ 0=
                        if      drop i leave
                        then
                loop    dup dirseg r@ c!l
                        >r ?DS: swap dirseg r> r@ 1+ swap cmovel
                pad 21 + c@ dirseg r> 1- c!l ;

\ 02/07/92 13:37 tjz added to improve performance

15 array sortn1
15 array sortn2

\ 05/25/90 tjz added from Mike Christopher

TARGET DEFINITIONS

: sortdir ( -- )          \ rearrange directory to ascending ascii order
                #fls 1 >
        [Llong] if      #fls 1- 0 over min
        [Llong]     do  #fls i 1+
        [Llong]         ?do     i >fadr 1- ?ds: sortn1 b/fnam cmovel
                                j >fadr 1- ?ds: sortn2 b/fnam cmovel
                                sortn1 2+ sortn2 2+ b/fnam 2- comp 0<
                                if      ?ds: sortn1 j >fadr 1- b/fnam cmovel
                                        ?ds: sortn2 i >fadr 1- b/fnam cmovel
                                then
        [Llong]         loop
        [Llong]     loop
                then
                ;

: $getdir       ( a1 --- )
                dirhndl $>handle         \ get directory spec
                dirhndl pathset drop
                off> #fls
                pad SET-DTA
                dirhndl >nam $10 find-first
                begin   255 and 0= #fls maxdir > 0= and
                while   name>buf incr> #fls
                        find-next
                repeat  ;

HTARGET DEFINITIONS TARGET

: getdir        ( --- )
                dirspec$ $getdir sortdir ;

: -at           ( col row -- col row+1 )
                2dup at 1+ ;

: showkeys      ( --- )                 \ show some help
                forgx 17 + forgy 1-
                -at ." ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿"
                -at ." ³ Hom ³  ³ PgUp ³"
                -at ." ³ ÄÄÄÄÅÄÄÄÅÄÄÄÄÄ ³"
                -at ." ³ End ³  ³ PgDn ³"
                -at ." ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿"
                -at ." ³ A-Z = Next file starting with Letter ³"
                -at ." ³ ÄÙ = Select file or directory       ³"
                -at ." ³ Esc = Cancel file selection          ³"
                -at ." ³ Del = Delete selected file           ³"
                -at ." ³   \ = Type in a new Directory Spec.  ³"
                 at ." ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ" ;

: pathbox       ( --- )
                forgx 17 + forgy 10 + over 52 + over 2 + box&fill
                ."  Path = " ;

: showpath      ( --- )
                pathbox forgx 26 + forgy 11 + at
                dirspec$ dup pathset 0=
                if      count type
                else    ." Can't read path" drop
                then    ;

: .1dir         ( n1 -- )
                >r curfl r@ foff + =
                if      r@ =: dirrow
                        >rev     ." þ" r@ foff + .nam ." þ"
                        >norm
                else             ."  " r@ foff + .nam ."  "
                then    r>drop ;

: .nodir        ( n1 -- )
                if      ."               "
                else    ." ...No Files..."
                then    ;

: showdir       ( --- )         \ display directory window
                forgx forgy 1- forgx 15 + forgy dlen + box
                forgx 15 + forgy        at ." "
                forgx 15 + forgy dlen + at ." "
                dlen 0
        do      forgx 1+ forgy i + at i foff + #fls >=
                if      i .nodir
                else    i .1dir
                then
        loop    ;

: nfl           ( --- )         \ next file
                curfl #fls 1- 0MAX = if exit then
                curfl 1+ #fls 1- min 0MAX dup !> curfl
                dup #fls < swap dlen 1- - foff = and
                if      foff 1+ #fls 15 - 0MAX min !> foff
                then    ;

: pfl           ( --- )         \ previous file
                curfl 1- 0MAX dup !> curfl
                foff =
                if      foff 1- 0MAX !> foff
                then    ;

: ?lmatch       ( --- f1 )
                curfl >fadr 1+ c@l aletter c@ = ;

: gotofl        ( --- )
                flitem @ 0MAX
                curfl over >
                if      curfl swap do pfl loop
                else    curfl     ?do nfl loop
                then    ;

variable foffsave
variable curflsave

: to_letter     ( n1 -- )
                0fl     0
                ?do     ?lmatch ?leave nfl
                loop    ?lmatch
                if      foffsave @
                        curflsave @ curfl - 1+ dlen >=
                        if      curfl
                        then    =: foff
                then    ;

: find_letter   ( c1 --- c1 )       \ search for a file starting with c1
                95 and dup aletter c! curfl >r
                curfl #fls 1- 0MAX =
                if      0fl
                else    nfl
                then
                begin   ?lmatch curfl #fls 1- 0MAX = or 0=
                while   nfl
                repeat  ?lmatch 0=
                if      r@ to_letter
                else    foff foffsave ! curfl curflsave !
                then    ?lmatch 0= if beep then
                r>drop ;

: efl           ( --- )       \ goto end of file list
                begin nfl curfl #fls 1- 0MAX = until ;

TARGET DEFINITIONS

                                        \ from counted string=a1
: >pathend"     ( a1 --- a2 n1 )        \ return a2 and count=n1 of filename
                count
                begin   2dup '\' scan dup
                while   2swap 2drop 1 /string
                repeat  2drop ;

                                \ a1 = counted string address
: >pathend      ( a1 --- a2 )   \ a2 = the address of the char beyond last \
                >pathend" drop ;

: >pathend-1    ( a1 --- a2 )
                dup c@ >r               \ save old length
                dup>r >pathend          \ find last backslash
                r@ - 2- 0MAX r@ c!     \ adjust to new count
                r@ >pathend             \ find previous backslash
                r> r> swap c! ;         \ restore old length

HTARGET DEFINITIONS TARGET

: del_curfile   ( -- )
                dirspec$ >pathend dirspec$ 1+ - dup dirhndl c!
                dirspec$ 1+ dirhndl 1+ rot cmove
                dirseg r@ dir>pad >r dirhndl count + r@ cmove
                r> dirhndl c+!
                dirhndl count + off
                dirhndl hdelete 5 =
                if      ."  Access denied !      "
                then ;

: delfl         ( --- )                   \ delete the current file
                curfl >fadr dup>r 1- c@l dirattrib and
                forgx 19 + forgy 11 + 2dup at 50 spaces at
                if      ." Can't delete directory !       "
                        r>drop showpath exit
                then    ." Delete '" dirseg r@ dir>pad type ." ' <- Y/N [N] "
                cursor-on key cursor-off bl or 'y' =
                if      del_curfile
                then    curfl foff
                        getdir
                        !> foff !> curfl
                r>drop showpath ;

: ndir          ( --- )             \ Enter a NEW directory spec
                forgx 17 + forgy 14 + at
                ." Edit the Directory Spec, and press Enter. ESC=Cancel"
                cursor-on pathbox
                on> autoclear
                >rev
                forgx 26 + forgy 11 + dirspec$ 41 lineeditor drop
                >norm
                forgx 17 + forgy 14 + at 52 spaces
                dirspec$ count + 1- c@ dup '\' = swap ':' = or
                if      defdirspec$ count >r dirspec$ count + r@ cmove
                             r> dirspec$ c+!
                then    dirspec$ c@ 0=
                if      defdirspec$ dirspec$ over c@ 1+ cmove
                then    0 dirspec$ count + c!
                dirspec$ pathset drop
                cursor-off getdir showpath 0fl ;

: keytests      ( n1 --- )
                dup false = if                          drop exit then
( up arrow )    dup   200 = if pfl                      drop exit then
( down arrow )  dup   208 = if nfl                      drop exit then
( PgUp )        dup   201 = if dlen 2/ 0 ?do pfl loop   drop exit then
( PgDn )        dup   209 = if dlen 2/ 0 ?do nfl loop   drop exit then
( \ )           dup    92 = if ndir                     drop exit then
( 0 to 9)       dup '0' '9' between over bl or
( A to Z)           'a' 'z' between or
                            if find_letter              drop exit then
( Del )         dup   211 = if delfl                    drop exit then
( Home )        dup   199 = if 0fl                      drop exit then
( End )         dup   207 = if efl                      drop exit then
                                                        drop beep ;

: to_root       ( -- )
                dirspec$ 2+ c@ ':' =      \ include drive?
                if      '\' dirspec$ 3 + c! 3 dirspec$ c!
                        defdirspec$ count >r
                        dirspec$ count + r@ cmove r> dirspec$ c+!
                else    defdirspec$ dirspec$ over c@ 1+ cmove
                then    dirspec$ count + off  \ nul term
                begin   item# @ 1 >           \ Clear DIR stack
                while   istk> drop
                repeat  istk> setfl ;         \ set to ROOT

: pop_dir       ( -- )
                \ Now we need to remove a Dir from DIRSPEC$.
                \ so step through DIRSPEC to next to the last
                \ directory.
                dirspec$ >pathend-1 dirspec$ 1+ - dirspec$ c!
                \ Append *.* to current directory specification
                defdirspec$ count dirspec$ +place
                dirspec$ count + off    \ nul terminate
                istk> setfl ;           \ pop DIR stack

: push_dir      ( -- )
                \ Must be on a directory name other than
                \ "." or ".." so step down to that directory
                dirspec$ >pathend dup           \ set dirspec length
                dirspec$ 1+ - dirspec$ c!       \ append DIR from PAD
                                                \ to dirspec
                pad count >r swap r@ cmove
                r> dirspec$ c+!                 \ set length
                " \" >r dirspec$ count + r@ cmove \ append "\"
                r> dirspec$ c+!
                defdirspec$ count >r dirspec$ count + r@ cmove
                r> dirspec$ c+!                 \ append *.*
                dirspec$ count + off            \ null terinate
                curfl >istk                     \ save directory offset
                0 setfl ;                       \ reset offset to zero

: ?setdir       ( c1 --- c2 f1 ) \ return bool false if new dir
                curfl >fadr dup>r 1- c@l dirattrib and 0= \ are we on a DIR
                if      r>drop true exit
                then
                drop                            \ discard char on stack
                dirseg r> dir>pad + off         \ move DIR to PAD, nul term
                pad 1+ @ '.' =                  \ is DIR the ROOT?
                if      to_root
                else    pad 1+ @ " .." drop @ = \ pop one level?
                        if      pop_dir
                        else    push_dir
                        then
                then                    \ get new directory, & show path
                cursor-off getdir showpath gotofl
                false                   \ put false on stack inplace of char
                false ;                 \ return a false flag also

: file_to_pad   ( -- )
                dirspec$ >pathend dirspec$ 1+ - >r
                dirspec$ pad r@ 1+ cmove r> pad c!
                curfl >fadr 2dup c@l >r 1+
                ?DS: pad count + r@ cmovel r> pad c+!
                pad handle>ext c@ '.' <>      \ append '.' if no extension
                if      '.' pad count + c!
                        1 pad c+!
                then  ;

TARGET DEFINITIONS

: ?dir_exit     ( c1 -- c1 f1 )
                dup 0=   if true    exit then   \ return true if NULL
                dup 13 = if ?setdir exit then   \ or false if set directory
                dup 27 = ;                      \ or true if ESC

: getfile       ( --- a1 f1 )       \ return a1 filename addr and boolean
                                    \ return true if terminated by enter
                                    \ return 1 if terminated by NULL key
                dirinit                 \ perform default initialization
                savecursor
                savescr                 \ save cursor and screen
                diralloc
                dirseg 0=               \ if it didn't work, then leave
                if
                        restscr
                        0 1 at ." No room for directory buffer!, "
                        0 2 at ." Can't pop up Dir window. Sorry! "
                        beep
                        restcursor
                        false dup exit
                then
                forgx 2- forgy 2- over 74 + rows 3 - box&fill
                forgx 36 + forgy 1 + at                 \ then my message
                ."  Tom's Window File Selection Tool "
                forgx 20 + forgy 7 + at
                ."  Reading Directory Files... "
                cursor-off getdir           \ clear screen, and get dir
                showkeys showpath       \ show the keys and dir path
                forgx 17 + forgy 16 + at     \ and som help information
                ." Use  to pick a file, or press the first letter of"
                forgx 17 + forgy 17 + at
                ." the file you want, then press Return to select it."
                winmsg
                begin   showdir 0 0 at      \ show the directory
                        key
                        winkey
                        ?dir_exit       \ setup exit if enter & not DIR
                        0=
                while   keytests        \ if neither then try to find a file
                repeat  dup 13 = swap 0= or
                file_to_pad                     \ move file to pad
                pad swap
                #fls 0<> and                    \ return boolean
                dirrelease                      \ release mem for dir list
                restscr                         \ restore screen
                restcursor  ;                   \ restore cursor position

FORTH TARGET >TARGET

