\\ ICON.SEQ             A simple Icon Editor            by Tom Zimmer
        .options /opt /noinit

  This program runs in 640x480x16 graphics mode, and allows the creation
and editing of 40x40 pixel 16 color icons.  Icons are little pictures.
It also contains fast assembly code routines that can be extracted to
other programs, that will move the icons to the screen very quickly.

  I want to thank Dr. Ting, for the basis on which these graphics
routines are written.  They use direct register control to move thing
very quickly to the screen.  While this is not as compatible as BIOS
graphics, it is much faster.

{

needs graph.seq

        208 constant iorgL
         80 constant iorgT
iorgL 320 + constant iorgR
iorgT 320 + constant iorgB
        560 constant corgL
         79 constant corgT
    40 40 * constant iconsize

handle savehndl
handle filehndl
handle dirhndl

15 value curcolor
 0 value bgcolor
-1 value prev_x
-1 value prev_y

green value bg1
cyan  value bg2

 0 value icon_pos
variable byteAddr
2variable prev_mouse

create  AN_ICON iconsize 80 + allot
create DIR_ICON iconsize 80 + allot

create icz-spec ," *.ICZ" 55 allot

\ code vgaByteMove ( a1 -- )
\         mov     di, bx                  \ di=a1, the byte address
\         mov     bx, byteAddr
\         push    es                      \ save es
\         mov     dx, # 0A000h            \ use es to address graphic memory
\         mov     es, dx
\         mov     dx, # 03CEh             \ ega register base
\
\         push    si                      \ save si
\         xor     al, al                  \ al=0, ega_sr
\         mov     si, # 0108h             \ pixel mask and command
\         mov     cx, # 8
\    0 $: mov     ah, 0 [di]              \ ah=color, al=0
\         out     dx, ax                  \ set color into register
\         xchg    ax, si                  \ ah=mask, al=8
\         out     dx, ax                  \ set it into the register
\         shl     ah, # 1                 \ shift to next bit in mask
\         xchg    ax, si
\         inc     es: 0 [bx]              \ read/write a dummy pixel
\         inc     di                      \ bump to color of next pixel
\         loop    0 $                     \ loop till 8 pixels are done
\
\         pop     si                      \ restore si
\         pop     es                      \ restore es
\         load_bx
\         ret             end-code

code IconMove   ( a1 a2 -- )    \ move from memory a1 to screen byte a2
        lodsw
        mov     di, ax                  \ di=a1, the byte address
        push    es                      \ save es
        mov     es, &> vid.seg
        mov     dx, # 03CEh             \ ega register base

        push    si                      \ save si
        push    bp                      \ save bp
        mov     cx, # 40                \ icon is 40 pixels high
   2 $: push    cx
        mov     cx, # 5                 \ icon is 5 bytes wide
   1 $: mov     bp, cx
        xor     al, al                  \ al=0, ega_sr
        mov     si, # 8008h             \ pixel mask and command
        mov     cx, # 8
   0 $: mov     ah, 0 [di]              \ ah=color, al=0
        out     dx, ax                  \ set color into register
        xchg    ax, si                  \ ah=mask, al=8
        out     dx, ax                  \ set it into the register
        shr     ah, # 1                 \ shift to next bit in mask
        xchg    ax, si
        inc     es: 0 [bx]              \ read/write a dummy pixel
        inc     di                      \ bump to color of next pixel
        loop    0 $                     \ loop till 8 pixels are done
        inc     bx
        mov     cx, bp                  \ bump to next byte address
        loop    1 $
        add     bx, # 75                \ adjust to start of next row
        pop     cx                      \ recover outer loop counter
        loop    2 $

        pop     bp                      \ restore bp
        pop     si                      \ restore si
        pop     es                      \ restore es
        load_bx
        ret             end-code

code IconDMove  ( a1 a2 -- )    \ move from memory a1 to screen byte a2
        lodsw
        mov     di, ax                  \ di=a1, the byte address
        push    es                      \ save es
        push    ds                      \ save ds
        mov     ds, &> vid.seg
        pop     es                      \ load es from saved ds
        mov     dx, # 03CEh             \ ega register base

        mov     ax, # FF08h             \ pixel mask and command
        out     dx, ax                  \ set color into register
        xor     al, al                  \ al=0, ega_sr
        mov     cx, # 40                \ icon is 40 pixels high
   2 $: push    cx
        mov     cx, # 40                \ icon is 40 bytes wide
   1 $: mov     ah, es: 0 [di]          \ ah=color, al=0
        out     dx, ax                  \ set color into register
        inc       0 [bx]             \ read/write a dummy pixel
        inc      80 [bx]             \ read/write a dummy pixel
        inc     160 [bx]             \ read/write a dummy pixel
        inc     240 [bx]             \ read/write a dummy pixel
        inc     320 [bx]             \ read/write a dummy pixel
        inc     400 [bx]             \ read/write a dummy pixel
        inc     480 [bx]             \ read/write a dummy pixel
        inc     560 [bx]             \ read/write a dummy pixel
        inc     di                      \ bump to color of next pixel
        inc     bx
        loop    1 $
        add     bx, # 80 7 * 40 +       \ adjust to start of next row
        pop     cx                      \ recover outer loop counter
        loop    2 $

        push    es                      \ save es for restoral to ds
        pop     ds                      \ restore ds
        pop     es                      \ restore es
        load_bx
        ret             end-code

code vgaByteFill ( a1 n1 -- )   \ fill n1 bytes at a1 with current color
        mov     ax, color               \ has the color changed?
        cmp     ax, &> g-color
    0<> if                      /nostack1
                mov     &> g-color ax   \ if so, then set the color
                mov     ah, al          \ ah=color
                xor     al, al          \ al=0, ega_sr register
                mov     dx, # 03CEh     \ ega register base
                out     dx, ax          \ set the color planes
                mov     ax, # 0F01h     \ ega_sre
                out     dx, ax
        then
        mov     cx, bx                  \ cx=count of bytes
        load_bx                         \ bx=starting address
        mov     ax, # 0F02h
        mov     dx, # 03C4h             \ mmr
        out     dx, ax                  \ enable all bit planes
        mov     dx, # 03CEh             \ ega register base
        mov     ax, # 0F01h             \ enable ega_sre
        out     dx, ax
        mov     di, ds                  \ save ds
        mov     ds, &> vid.seg
        mov     ax, # FF08h             \ bit mask all bits
        out     dx, ax
   0 $: inc     0 [bx]                  \ write dummy pixel
        inc     bx
        loop    0 $                     \ loop till all bytes filled
        mov     ds, di                  \ restore ds
        load_bx
        ret             end-code

\ Palette, select colors for VGA display, 14oct92cht

create paletteBuffer 17 allot
                    170 allot \ 10 more sets of color palettes

: palette       ( n -- addr )
                17 * paletteBuffer + ;

code readPalette ( addr -- )
                mov     dx, bx
                push    es
                push    ds
                pop     es
                mov     ax, # 1009h
                int     10h
                pop     es
                load_bx
                ret             end-code

code writePalette ( addr -- )
                mov     dx, bx
                push    es
                push    ds
                pop     es
                mov     ax, # 1002h
                int     10h
                pop     es
                load_bx
                ret             end-code

: defaultPalette ( -- )
                0 palette 1 palette 17 cmove
                1 palette writePalette
                ;

: rotatePalette ( -- )
                1 palette dup 15 + C@
                over 1+ dup 1+ 14 cmove>
                over 1+ c!
                writePalette
                ;

: reversePalette ( -- )
                1 palette dup 1+ C@
                over 2+ dup 1- 14 cmove
                over 15 + c!
                writePalette
                ;

: init_palette  ( -- )          \ initialize the palette buffers
                paletteBuffer readPalette
                1 palette readPalette ;


: ?keyboard     ( -- f1 )
                0 $41A c@L 0 $41C c@L - ;

: ?color-set    ( x y &color -- x y )
                >r
                2dup 8 / swap 8 / swap prev_mouse 2@ d= 0=
        [long]  if      2dup corgT corgT 16 21 * + between
                        swap corgL corgL    21   + between and
                        if      dup corgT - 21 / 15 min r@ !
                                hide.mouse
                                frameColor
                                show.mouse
                                2dup 8 / swap 8 / swap prev_mouse 2!
                        then
                then    r>drop ;

: ?shiftkey     ( --- f1 ) 0 $417 c@l $03 and 0<> ;
: ?ctrlkey      ( --- f1 ) 0 $417 c@l $04 and 0<> ;

: ?pixel-set    ( x y color -- x y )
                >r
                ?shiftkey
                if      prev_y 0<
                        if      dup !> prev_y
                        else    drop prev_y
                        then
                then
                ?ctrlkey
                if      prev_x 0<
                        if      over !> prev_x
                        else    nip prev_x swap
                        then
                then
                2dup 8 / swap 8 / swap prev_mouse 2@ d= 0=
        [long]  if      2dup iorgT iorgB between
                        swap iorgL iorgR between and
                        if      2dup iorgT - 8 / 40 *
                                swap iorgL - 8 / 39 min + an_icon +
                                r@ swap c!
                                hide.mouse
                                showIcon
                                show.mouse
                                2dup 8 / swap 8 / swap prev_mouse 2!
                        then
                then    r>drop ;

: dirbutton     ( -- <n1> f1 )    \ directory, mouse button handler
                show.mouse
                begin   begin   ?keyboard
                                if      hide.mouse
                                        key drop false
                                        EXIT    \ ***** EXITS HERE *****
                                then
                                mousebutton ?dup
                                broken @ if ( text-mode ) bye then
                        until
                        dup 1 =                         \ left mouse button
                        if      getmous drop
                                2dup 36 < swap 32 < or
                                if      2drop
                                else         36 - 64 / 8 *
                                        swap 32 - 72 / +
                                        NIP     \ delete extra copy of mouse
                                                \ button value
                                        hide.mouse
                                        true EXIT   \ ***** EXITS HERE *****
                                then
                        then
                        2 =                             \ right mouse button
        [long]          if      getmous drop
                                2dup 36 < swap 32 < or
                                if      2drop
        [long]                  else         36 - 64 / 8 *
                                        swap 32 - 72 / +
                dup #fls <
        [long]  if      hide.mouse
                        >fadr countl dirhndl placeL
                        dirhndl count + off
                        2 1 at space dirhndl count type
                        ."  <- Delete this file? [Y/N] (N) "
                        key upc 'Y' =
                        if      dirhndl hdelete 0=
                                if      ."  DELETED!" 3 tenths
                                else    ."  FAILED!" beep
                                        ."  Press a key" key drop
                                then    icz-spec $getdir
                        then    .icons
                        show.mouse
                else    drop beep
                then
                                then
                        then
                again   ;

: mbutton       ( --- )         \ mouse button handler
                mousebutton
                case    1 of    getmous drop
                                &> curcolor ?color-set
                                   curcolor ?pixel-set 2drop
                                endof
                        2 of    getmous drop
                                &> bgcolor ?color-set
                                   bgcolor ?pixel-set 2drop
                                endof
                                drop
                                -1. prev_mouse 2!
                                -1  !> prev_y
                                -1  !> prev_x
                endcase ;

: mouse.key     ( -- )
                begin   mbutton key? until
                bioskey dup 127 and 0=
                if      flip dup 3 =
                        if      drop 0          \ allow a null
                        else    127 and 128 or
                        then
                else    255 and
                then    ;

: tcom_init     ( -- )
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                30 !> rows
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                bg1 8 or color !
                INITMOUSE ;                     \ init the mouse

: icon_init     ( -- )
                ?vmode 7 = abort" VGA Color needed!"
                640x480x16
                " ICZ" defext place
                ;

: showIcon      ( -- )          \ show the icon, in big and small window
                ?planes_enable
                an_icon iorgL      8 / iorgT 80 * + IconDMove
                an_icon iorgL 64 - 8 / iorgT 80 * + IconMove  ;


: frameColors   ( -- )
                black color !
                corgL  1 - corgT   1 - corgL 21 + corgT    1 - line
                corgL  1 - corgT   1 - corgL  1 - corgT  335 + line
                corgL 21 + corgT   1 - corgL 21 + corgT  335 + line
                corgL  1 - corgT 335 + corgL 21 + corgT  335 + line
                15 0
                do      corgL      corgT i 21 * + 1-
                        corgL 20 + corgT i 21 * + 1- line
                loop    ;

: frameColor    ( -- )
                frameColors
                curcolor 15 -
                if      white  color !
                else    yellow color !
                then
                corgT curcolor 21 * + >r        \ top of color to hilight
                corgL  1 - r@  1 - corgL 21 + r@  1 - line
                corgL  1 - r@  1 - corgL  1 - r@ 20 + line
                corgL 21 + r@  1 - corgL 21 + r@ 20 + line
                corgL  1 - r@ 20 + corgL 21 + r@ 20 + line
                r>drop
                white color !
                corgL  1 -  corgT 33 - corgL 21 + corgT 33 - line
                corgL  1 -  corgT 33 - corgL  1 - corgT 12 - line
                corgL 21 +  corgT 33 - corgL 21 + corgT 12 - line
                corgL  1 -  corgT 12 - corgL 21 + corgT 12 - line
                bgcolor color !
                20 0
                do      corgL      corgT i + 32 -
                        corgL 20 + corgT i + 32 - line
                loop    ;

: showFrame     ( -- )
                \ double line white border on big icon
                white color !
                iorgL 2 - iorgT 2 - iorgR 1 + iorgT 2 - line
                iorgL 1 - iorgB 1 + iorgR 1 + iorgB 1 + line
                iorgL 2 - iorgT 2 - iorgL 2 - iorgB 1 + line
                iorgR 1 + iorgT 1 - iorgR 1 + iorgB 1 + line

                iorgL 3 - iorgT 3 - iorgR 2 + iorgT 3 - line
                iorgL 2 - iorgB 2 + iorgR 2 + iorgB 2 + line
                iorgL 3 - iorgT 3 - iorgL 3 - iorgB 2 + line
                iorgR 2 + iorgT 2 - iorgR 2 + iorgB 2 + line
                \ single line black border inside double white for big icon
                black color !
                iorgL 1 - iorgT 1 - iorgR     iorgT 1 - line
                iorgL     iorgB     iorgR     iorgB     line
                iorgL 1 - iorgT 1 - iorgL 1 - iorgB     line
                iorgR     iorgT     iorgR     iorgB     line
                \ single line black border inside single white for small icon
                iorgL 65 - iorgT  1 - iorgL 24 - iorgT  1 - line
                iorgL 65 - iorgT 40 + iorgL 24 - iorgT 40 + line
                iorgL 65 - iorgT  1 - iorgL 65 - iorgT 40 + line
                iorgL 24 - iorgT  1 - iorgL 24 - iorgT 40 + line
                \ single line white border for small icon
                white color !
                iorgL 66 - iorgT  2 - iorgL 23 - iorgT  2 - line
                iorgL 66 - iorgT 41 + iorgL 23 - iorgT 41 + line
                iorgL 66 - iorgT  2 - iorgL 66 - iorgT 41 + line
                iorgL 23 - iorgT  2 - iorgL 23 - iorgT 41 + line
                \ frame screen with a white line
                white color !
                0       0       639     0       line
                0       0       0       479     line
                0       479     639     479     line
                639     0       639     479     line
                \ display our title
                 1  1 at
        ."     An ICON EDITOR written in Forth by Tom Zimmer and compiled with TCOM.     "
                74  4 at ."  BG "
                74  6 at ."  FG "
                17  4 at ."  Normal "
                36  4 at ."  Enlarged 8 times "

                 2 10
                1+ 2dup at ."                      "
                1+ 2dup at ."  Q-Quit Icon to DOS  "
                1+ 2dup at ."     컴컴컴컴컴       "
                1+ 2dup at ."  F-Flood FILL Icon   "
                1+ 2dup at ."    with the FG color "
                1+ 2dup at ."     컴컴컴컴컴       "
                1+ 2dup at ."  L-Load Icon file    "
                1+ 2dup at ."  S-Save Icon file    "
                1+ 2dup at ."     컴컴컴컴컴       "
                1+ 2dup at ."  -Left  shift Icon  "
                1+ 2dup at ."  -Right shift Icon  "
                1+ 2dup at ."  -Up    shift Icon  "
                1+ 2dup at ."  -Down  shift Icon  "
                1+ 2dup at ."     컴컴컴컴컴       "
                1+ 2dup at ."    Mouse Buttons     "
                1+ 2dup at ."  Left  - FG color    "
                1+ 2dup at ."  Right - BG color    "
                1+ 2dup at ."                      "

                2drop
                \ show color blocks
                16 0
                do      i color !
                        20 0
                        do      corgL      corgT i + j 21 * +
                                corgL 20 + corgT i + j 21 * + line
                        loop
                loop
                frameColor ;

: +color        ( n1 -- )
                curcolor + 15 and !> curcolor
                frameColor ;

: +bgcolor      ( n1 -- )
                bgcolor + 15 and !> bgcolor
                frameColor ;

: fill-current  ( -- )
                an_icon iconsize curcolor fill
                showIcon ;

: right-icon    ( -- )
                an_icon dup 1+ iconsize cmove>
                showIcon ;

: left-icon     ( -- )
                an_icon dup 1+ swap iconsize cmove
                showIcon ;

: up-icon       ( -- )
                an_icon dup 40 + swap iconsize cmove
                showIcon ;

: down-icon     ( -- )
                an_icon dup 40 + iconsize cmove>
                showIcon ;

: clr_screen    ( -- )    \ clear screen to colors bg1 and bg2
                ?planes_enable
                bg1 color !
                $9600 0
                do      i 80 vgaByteFill
           160 +loop
                bg2 color !
                $9600 80
                do      i 80 vgaByteFill
           160 +loop    ;

: .info         ( -- )
                1 32 at cols 2- spaces
                1 32 at ."  Current Icon: "
                filehndl count type ;

: lineedit-key   ( -- )
                at? t-height * swap t-width *
                insertmode @
        if      1- swap               over over t-height 1- +
        else       swap t-height 1- + over      t-width     + over
        then
                begin   ?keyboard 0=
                while           1 tenths 2over 2over white color ! line
                        ?keyboard 0=
                        if      1 tenths 2over 2over black color ! line
                        then
                repeat                       black color ! line
                bioskey dup 127 and 0=
                if      flip dup 3 =
                        if      drop 0          \ allow a null
                        else    127 and 128 or
                        then
                else    255 and
                then    ;


: mydirinit     ( --- )                 \ try to initialize the directory
                dlen ?exit
                rows forgy - 4 - =: dlen
                " *.ICZ" ">$ dirspec$ $>handle
                " *.ICZ"  defdirspec$ place
                0istk 0fl
                ['] noop is winkey
                ['] noop is winmsg ;

: .icon         ( {name_seg offset} {screen_index} -- )
                >r                              \ save screen index
                dirhndl clr-hcb
                countl dirhndl placeL
                dirhndl hopen 0=
        [long]  if      dir_icon iconsize dirhndl hread iconsize =
        [long]          if      dir_Icon
                                r@ 8 /mod 5120 * swap 9 * + 2884 +
                                ?planes_enable
                                IconMove
                                r@ 8 /mod 64 * 80 + swap        \ vertical
                                          72 * 16 + swap p-at   \ horizontal
                                dirhndl >pathend" 2dup '.' scan nip -
                                ltgray >bg white >fg
                                dup>r space type 9 r> - spaces
                        then
                        dirhndl hclose drop
                then    r>drop ;

: .icons        ( -- )
                save> attrib
                clr_screen
                #fls ?dup
                if      48 min 0
                        ?do     i >fadr i .icon
                        loop
                else    8 12 at
                        ."  Sorry, there are no icons matching the file specification: "
                        8 14 at
                        icz-spec count type
                then
                2 32 at
."  Click: LEFT button to select an icon or the RIGHT button to delete an icon "
                restore> attrib ;

0 value selected-icon

: .playicon     ( -- )
                getmous drop 2>r
                hide.mouse
                dirhndl clr-hcb
                selected-icon >fadr countl dirhndl placeL
                dirhndl hopen 0=
        [long]  if      dir_icon iconsize dirhndl hread iconsize =
        [long]          if      dir_Icon
                                2r@     40 / 40 * 80 *
                                swap     8 /  5 /  5 * +
                                ?planes_enable
                                IconMove
                        then
                        dirhndl hclose drop
                then    2r> 2drop
                show.mouse ;

: playbutton    ( -- )    \ Play screen mouse button handler
                show.mouse
                begin   mousebutton
                        1 =                     \ left mouse button
        [long]          if      getmous drop
                                     16 - 0max 42 / 12 *
                                swap 32 - 0max  6    8 * /
                                + dup #fls <
                                if      \ select new icon
                                        !> selected-icon
                                else    \ draw selected icon
                                        drop .playicon
                                then
                        then
                        broken @ if bye then
                        ?keyboard
                until   hide.mouse key drop ;

: .picon        ( {name_seg offset} {screen_index} -- )
                >r                              \ save screen index
                dirhndl clr-hcb
                countl dirhndl placeL
                dirhndl hopen 0=
        [long]  if      dir_icon iconsize dirhndl hread iconsize =
        [long]          if      dir_Icon
                                r@ 12 /mod 42 80 * * swap 6 * + 16 80 * 4 + +
                                ?planes_enable
                                IconMove
                        then
                        dirhndl hclose drop
                then    r>drop ;

: play-icons    ( -- )
                diralloc
                0istk 0fl
                " *.icc" ">$ $getdir
                clr_screen
                #fls ?dup
                if      48 min 0
                        ?do     i >fadr i .picon
                        loop
                else    8 6 at
                        ."  Sorry, there are no icons matching the file specification: "
                        8 8 at ." *.ICC"
                then
                playbutton
                dirrelease
                .screen
                .info showIcon ;

: pick-icon     ( -- a1 n1 f1 )
\                #fls 0=
\                if      " UNTITLED.ICZ"
\                        false EXIT
\                then
                .icons
                dirbutton 0=
                #fls 0= or
                if      " UNTITLED.ICZ" false
                else    >fadr countl dirhndl placeL
                        dirhndl count   true
                then    ;

                                       \ a1,n1=prompt text string
: set_image_name ( a1 n1 -- f1 )        \ f1=true  if accepted filename
                2>r                     \ f1=false if canceled save or load
                1 32 at cols 2- spaces
                filehndl count                   \ else full path
                savehndl place
                1 32 at 2r> type
                on> autoclear                   \ allow easy new name entry
                ['] lineedit-key save!> key
                at? savehndl 60 lineeditor
        [long]  if      savehndl count '*' scan nip
                        savehndl count '?' scan nip or
                        if      savehndl count 59 min icz-spec place
                                savehndl off
                        then
                        savehndl c@ 0=
                        if
                                diralloc
                                0istk 0fl
                                icz-spec $getdir
                                pick-icon >r savehndl place r>
                                dirrelease
                                .screen
                        else    true
                        then    dup
                        if      savehndl count bl skip savehndl place
                                savehndl filehndl $>handle
                        then
                else    false
                then
                restore> key ;

: %update-icon   ( -- )
                filehndl hcreate 0=
                if      an_icon iconsize filehndl hwrite iconsize -
                        if      beep
                        then    filehndl hclose drop
                else    beep
                then    ;

: save-icon     ( -- )
                "  Save Icon: " set_image_name
                if      %update-icon
                then    .info ;

: update-icon   ( -- )
                filehndl c@ 0=
                if      beep
                        save-icon
                else    %update-icon
                then    .info ;

: %load_icon    ( -- )
                filehndl hopen
                if      beep EXIT
                then
                an_icon iconsize filehndl hread iconsize -
                if      beep
                then    filehndl hclose drop ;

: auto-load-icon ( -- )
                bl word c@ 0= ?exit
                here filehndl $>handle
                %load_icon .info ;

: load-icon     ( -- )
                "  Load Icon: " set_image_name
                if      %load_icon
                then    .info showIcon ;

: leave-icon    ( -- )
                text-mode
                0 0 at
                cr ." Stack "
                depth ?dup
                if      ." Depth: " .
                else    ." Empty"
                then    bye ;

: .screen       ( -- )
                clr_screen
                showFrame
                .info
                showIcon ;

: areacolor     ( -- )          \ set screen colors to match current colors
                curcolor !> bg1
                bgcolor  !> bg2
                bg1 8 or color !
                .screen ;

: main          ( -- )
                tcom_init
                icon_init
                clr_screen
                show.mouse
                hide.mouse
                showFrame
                auto-load-icon
                .info
                showIcon
                BEGIN   show.mouse
                        mouse.key
                        hide.mouse
                        CASE
                ( PgUp )       201 of   -1 +color               endof
                ( PgDn )       209 of    1 +color               endof
                ( ^PgUp )      132 of   -1 +bgcolor             endof
                ( ^PgDn )      246 of    1 +bgcolor             endof
                ( right )      205 of   right-icon              endof
                ( left )       203 of   left-icon               endof
                ( up )         200 of   up-icon                 endof
                ( down )       208 of   down-icon               endof
                ( ESC )         27 of   showIcon                endof
                ( F2 )         188 of   areacolor               endof
                ( alt-S )      159 of   update-icon             endof
                        upc    'F' of   fill-current            endof
                               'L' of   load-icon               endof
                               'S' of   save-icon               endof
                               'P' of   play-icons              endof
                               'Q' of   leave-icon              endof
                                drop
                        ENDCASE
                AGAIN
                ;

