\ MAN486.SEQ MANDELBROT PLOT WITH MATH COPPROCESSOR 21oct92cht

.options /opt /noinit /tailopton

needs graph.seq

variable fpstatus

create aa2 16 allot
create bb2 16 allot
create 4.02 16 allot
create aa3 16 allot
create bb3 16 allot
create 4.03 16 allot

variable maxRow
variable maxColumn
variable maxRow/2
variable maxColumn/2

variable bottomMargin
variable rightMargin

\ **********************************************************************
\ a group of variables to save with each graphic image  128 bytes
\ **********************************************************************
here                    /nostack1
create zoom 16 allot    \ here+16 is after this array
create xx   16 allot    \ here+32 is after this array
create yy   16 allot    \ here+48 is after this array
create aa   16 allot    \ here+64 is after this array
create bb   16 allot    \ here+80 is after this array
variable iteration      \ here+82 is after this variable
variable shiftPixel     \ here+84 is after this variable
variable zoomFactor     \ here+86 is after this variable
variable zoomPower      \ here+88 is after this variable
0 value ?coarse         \ here+90 is after this value
variable vid_row_save   \ here+92 is after this variable
0 value ?cont           \ here+94 is after this value

\ **********************************************************************
here swap - 128 swap - 0max allot       \ allocate upto 128 byte boundry
\ **********************************************************************

variable vid_col
variable vid_row
variable vid_row2
variable vid_row3

0 value ?skip
0 value ?center

handle manhndl

code 8vgaDots ( color7 ... color0 -- )
        save_bx                         \ BX has color
        mov     dx, vid_row             \ y
        mov     cx, # 8                 \ 8 dots
        add     vid_col # 8 word
   0 $: xchg    cx, vid_col             \ x
        lodsw                           \ color
        and     al, # 07Fh              \ mask to SET, not XOR
        mov     ah, # 0Ch               \ draw dot
        xor     bx, bx                  \ page
        dec     cx
        int     10h
        xchg    cx, vid_col             \ next column
        loop    0 $
        add     vid_col # 8 word
        load_bx
        ret             end-code

code 4vgaDots ( color -- )
                                        \ BX has color
        mov     dx, vid_row             \ y
        mov     cx, # 4                 \ 4 dots
        add     vid_col # 4 word
        mov     al, bl
        and     al, # 07Fh              \ mask to SET, not XOR
        mov     ah, # 0Ch               \ draw dot
        xor     bx, bx                  \ page
   0 $: xchg    cx, vid_col             \ x
        dec     cx
        int     10h
        xchg    cx, vid_col             \ next column
        loop    0 $
        add     vid_col # 4 word
        load_bx
        ret             end-code

code vgaDot ( x y color -- )
                                        \ BX has top of stack
        lodsw   mov dx, ax              \ y
        lodsw   mov cx, ax              \ x
        mov     al, bl                  \ color to al
        mov     ah, # 0Ch
        xor     bx, bx                  \ page
        int     10h
        load_bx
        ret             end-code

code Dotvga16 ( color x y -- )
                                        \ BX has top of stack
        mov dx, bx                      \ y
        lodsw
        mov cx, ax                      \ x
        lodsw                           \ color in al
        and     al, # 7Fh
        mov     ah, # 0Ch
        xor     bx, bx                  \ page
        int     10h
        inc     cx
        int     10h
        inc     cx
        int     10h
        inc     cx
        int     10h
        sub cx, # 3
        inc dx
        int     10h
        inc     cx
        int     10h
        inc     cx
        int     10h
        inc     cx
        int     10h
        sub cx, # 3
        inc dx
        int     10h
        inc     cx
        int     10h
        inc     cx
        int     10h
        inc     cx
        int     10h
        sub cx, # 3
        inc dx
        int     10h
        inc     cx
        int     10h
        inc     cx
        int     10h
        inc     cx
        int     10h
        inc cx
        inc dx
        load_bx
        ret             end-code

code getDot ( x y -- color )
                                        \ BX has top of stack
        mov     dx, bx                  \ y
        lodsw   mov cx, ax              \ x
        mov     ah, # 0Dh
        xor     bx, bx                  \ page
        int     10h
        mov     bl, al
        sub     bh, bh
        ret             end-code

code vgaDotW ( x y -- )
                                        \ BX has top of stack
        mov     dx, bx                  \ y
        lodsw   mov cx, ax              \ x
        xor     bx, bx                  \ page
        mov     ax, # 0C0Fh             \ draw dot in XOR mode
        int     10h
        load_bx
        ret             end-code

: ?shiftkey     ( --- f1 ) 0 $417 c@l $03 and 0<> ;
: ?ctrlkey      ( --- f1 ) 0 $417 c@l $04 and 0<> ;

0 value special_mode

: 640x480x256_special ( -- )
                special_mode 640 480 256 $A000 $FA00 cmode! ;

0 value vcard

0 value xsens
0 value ysens
0 value dspeed


: gg            ( -- )
                vcard
                case
                       -1 of    640x480x256_special     endof
                        0 of    640x480x256_trident     endof
                        1 of    640x480x256_paradise    endof
                        2 of    640x480x256_tseng       endof
                        3 of    640x480x256_tseng       endof
                        4 of    640x480x256_ati         endof
                        5 of    640x480x256_paradise    endof
                        6 of    640x480x256_genoa       endof
                        7 of    640x480x256_video7      endof
                                drop
                endcase
                gtext-off               \ disable graphics drawn text
                mouse.sense@ !> dspeed !> ysens !> xsens
                640 8 * 480 8 * mouse.limit!
                xsens 2* ysens 2* dspeed mouse.sense!
                set.mouse
                ;

: get_mouse     ( -- x y b )
                getmous >r u8/ swap u8/ swap r> ;

create vcards   ," tri dia orc tse ati par gen vid "

: ?voption      ( -- )
                bl word 1+ 3 vcards count search
                here c@ 2 > and
                if      4 / !> vcard
                else    save> base hex
                        here ?uppercase number? nip 0=
                        if      drop signon
                        else       !> special_mode
                                -1 !> vcard
                        then
                        restore> base
                then    ;

code initzoom   ( --)
                fld1
                fadd    st, st(0)               \ 2.0
                fdiv    maxRow/2 integer*2      \ 2.0/320
                fstp    zoom temp_real
                fldz
                fld     st, st(0)
                fstp    temp_real xx
                fstp    temp_real yy
                ret             end-code

code inAdjust   ( -- )
                fld     temp_real zoom
                fdiv    integer*2 zoomFactor
                fstp    temp_real zoom
                ret             end-code

code outAdjust  ( -- )
                fld     temp_real zoom
                fmul    integer*2 zoomFactor
                fstp    temp_real zoom
                ret             end-code

code OnePoint   ( f: 4.0 aa bb -- 4.0 aa+zoom bb; s: -- count )
                save_bx
                xor     cx, cx
                fld     st(1)                   \ 4 a b x
                fld     st(1)                   \ 4 a b x y
        1 $:    fld     st(1)                   \ 4 a b x y x
                fmul    st, st(2)               \ 4 a b x y xx
                fld     st(1)                   \ 4 a b x y xx y
                fmul    st, st(2)               \ 4 a b x y xx yy
                fld     st(1)                   \ 4 a b x y xx yy xx
                fadd    st, st(1)               \ 4 a b x y xx yy xx+yy
                fcomp   st(7)                   \ 4 a b x y xx yy
                fstsw   fpstatus                \ xx+yy > 4?
                mov     ax, fpstatus
                wait
                sahf
                jnc     2 $
                fsubrp  st(1), st               \ 4 a b x y xx-yy
                fadd    st, st(4)               \ 4 a b x y xx-yy+a
                fxch    st(2)                   \ 4 a b xx-yy+a y x
                fmulp   st(1), st               \ 4 a b xx-y+a xy
                fadd    st, st(0)               \ 4 a b xx-yy+a 2xy
                fadd    st, st(2)               \ 4 a b xx-yy+a 2xy+b
                inc     cx
                cmp     cx, iteration
                jnz     1 $
        3 $:    mov     bx, cx          \ push    cx
                fcompp                          \ 4 a b
                fld     temp_real zoom             \ 4 a b zoom
                faddp   st(2), st               \ 4 a+zoom b
                ret
        2 $:    fcompp                          \ 4 a b x y
                jmp     3 $
                end-code

code NoPoint    ( f: 4.0 aa bb -- 4.0 aa+zoom bb; s: count -- count count )
                save_bx
                fld     temp_real zoom             \ 4 a b zoom
                faddp   st(2), st               \ 4 a+zoom b
                ret             end-code

code SkPoint    ( f: 4.0 aa bb -- 4.0 aa+zoom bb; s: -- )
                fld     temp_real zoom             \ 4 a b zoom
                faddp   st(2), st               \ 4 a+zoom b
                ret             end-code

code initTop    ( -- ; f: -- 4.0 aa0 bb0 )
                fld1
                fadd    st, st(0)
                fadd    st, st(0)               \ 4.0
                fld     temp_real zoom
                fmul    integer*2 maxRow/2
                fchs                            \ -320*zoom, aa
                fld     temp_real xx
                faddp   st(1), st
                fld     st, st(0)
                fstp    temp_real aa
                fld     temp_real zoom
                fmul    integer*2 maxColumn/2
                fchs                            \ -240*zoom, bb
                fld     temp_real yy
                faddp   st(1), st
                fld     st, st(0)
                fstp    temp_real bb
                ret             end-code

code saveTop2   ( -- ; f: 4.0 aa0 bb0 -- )
                fstp    temp_real bb2
                fstp    temp_real aa2
                fstp    temp_real 4.02
                mov     cx, vid_row
                mov     vid_row2 cx
                ret             end-code

code saveTop3   ( -- ; f: 4.0 aa0 bb0 -- )
                fstp    temp_real bb3
                fstp    temp_real aa3
                fstp    temp_real 4.03
                mov     cx, vid_row
                mov     vid_row3 cx
                ret             end-code

code loadTop2   ( -- ; f: 4.0 aa0 bb0 -- )
                fld     temp_real 4.02
                fld     temp_real aa2
                fld     temp_real bb2
                mov     cx, vid_row2
                mov     vid_row cx
                ret             end-code

code loadTop3   ( -- ; f: 4.0 aa0 bb0 -- )
                fld     temp_real 4.03
                fld     temp_real aa3
                fld     temp_real bb3
                mov     cx, vid_row3
                mov     vid_row cx
                ret             end-code

code clearFstack ( -- ; f: 4.0 aa bb -- )
                fcomp   st(1)
                fcompp
                ret             end-code

code nextRow    ( -- ; f: 4.0 aa bb -- 4.0 aa0 bb+zoom )
                fld     temp_real zoom
                faddp   st(1), st
                fld     temp_real aa               \ aa0
                fstp    st(2)
                ret             end-code

code prevRow    ( -- ; f: 4.0 aa bb -- 4.0 aa0 bb+zoom )
                fld     temp_real zoom
                fsubrp   st(1), st
                fld     temp_real aa               \ aa0
                fstp    st(2)
                ret             end-code

code initBottom ( -- ; f: -- 4.0 aa0 bbBottom )
                fld1
                fadd    st, st(0)
                fadd    st, st(0)               \ 4.0
                fld     temp_real zoom
                fmul    integer*2 maxRow/2
                fchs                            \ -320*zoom, aa
                fld     temp_real xx
                faddp   st(1), st
                fld     st, st(0)
                fstp    temp_real aa
                fld     temp_real zoom
                fmul    integer*2 bottomMargin
                fld     temp_real yy
                faddp   st(1), st
                fld     st, st(0)
                fstp    temp_real bb
                ret             end-code

code initRight  ( -- ; f: -- 4.0 aaRight bb0 )
                fld1
                fadd    st, st(0)
                fadd    st, st(0)               \ 4.0
                fld     temp_real zoom
                fmul    integer*2 rightMargin
                fld     temp_real xx
                faddp   st(1), st
                fld     st, st(0)
                fstp    temp_real aa
                fld     temp_real zoom
                fmul    integer*2 maxColumn/2
                fchs                            \ -240*zoom, bb
                fld     temp_real yy
                faddp   st(1), st
                fld     st, st(0)
                fstp    temp_real bb
                ret             end-code

code nextRight  ( -- ; f: 4.0 aa bb -- 4.0 aa+304*zoom bb+zoom )
                fld     temp_real zoom
                faddp   st(1), st
                fld     temp_real aa
                fstp    st(2)
                ret             end-code

code +vid_row  ( n1 -- )
                add     vid_row bx
                load_bx
                ret             end-code

: ?keyboard     ( -- f1 )
                0 $41A c@L 0 $41C c@L - ;

: Scan_Image_rough ( -- )
                initTop                         \ initialize coproc
                16 0 DO                         \ skip to the middle
                        nextRow                 \ of the screen
                        ?keyboard ?leave
                LOOP
                ?keyboard ?EXIT
                480 16
                DO      640 0
                        DO      onePoint SkPoint SkPoint SkPoint
                                i j Dotvga16
                     4 +LOOP
                        nextRow
                        nextRow
                        nextRow
                        nextRow
                        ?keyboard ?leave
                        broken @ if text-mode bye then
             4 +LOOP    clearFstack ;

: scanBline     ( -- )          \ scan only black dots
                vid_row @ 16 < ?exit
                off> vid_col
                80 0 DO
                        8 0 DO  vid_col @ i + vid_row @ getDot dup 0=
                                if      drop onePoint
                                else    Skpoint
                                then
                        LOOP                    ( p7 p6 p5 ... p0 -- )
                        8vgaDots
                        broken @ if text-mode bye then
                LOOP    ;

: fscan1line    ( -- )          \ scan all dots of a line
                vid_row @ 16 < ?exit
                off> vid_col
                80 0 DO
                        onePoint onePoint onePoint onePoint
                        onePoint onePoint onePoint onePoint
                                                ( p7 p6 p5 ... p0 -- )
                        8vgaDots
                        broken @ if text-mode bye then
                LOOP    ;

: qscan1line    ( -- )
                vid_row @ ?center 4 * < ?exit
                vid_row @ 480 ?center 4 * - > ?exit
                off> vid_col
                ?center 0 DO
                        SkPoint SkPoint SkPoint SkPoint
                        SkPoint SkPoint SkPoint SkPoint
                        black   black   black   black
                        black   black   black   black
                        8vgaDots
                LOOP
                80 ?center 2* - 0max 0 ?DO
                        onePoint onePoint onePoint onePoint
                        onePoint onePoint onePoint onePoint
                                                ( p7 p6 p5 ... p0 -- )
                        8vgaDots
                        ?keyboard ?leave
                        broken @ if text-mode bye then
                LOOP    ?keyboard ?exit
                ?center 0 DO
                        SkPoint SkPoint SkPoint SkPoint
                        SkPoint SkPoint SkPoint SkPoint
                        black   black   black   black
                        black   black   black   black
                        8vgaDots
                LOOP    ;

defer scan1line ' fscan1line is scan1line
defer scanaline ' scan1line  is scanaline

: skip1line     ( -- )
                vid_row2 @ vid_row_save @ < ?exit
                off> ?cont
                ?skip
                if      ['] scanBline is scanaline
                        off> ?center
                else    ?center
                        if      ['] qscan1line is scan1line
                        else    ['] fscan1line is scan1line
                        then
                        @> scan1line !> scanaline
\                        ['] scan1line is scanaline
                then    scan1line ;

: Scan_Image_fine ( -- )
                off> vid_row
                off> vid_col
                initTop                         \ initialize coproc
                241 0 DO                                \ skip to the middle
                        1 +vid_row nextRow              \ of the screen
                        ?keyboard ?leave
                LOOP    saveTop2                        \ setup for scan down
                loadTop2 prevRow -1 +vid_row saveTop3 \ setup for scan up
                ?keyboard 0=
        if      240 0 DO
                        loadTop2 scanaline nextRow  1 +vid_row saveTop2
                        ?keyboard ?leave
                        loadTop3 scanaline prevRow -1 +vid_row saveTop3
                        ?keyboard ?leave
                LOOP
        then    vid_row2 @ ( 1- 0max ) vid_row_save !
                ?keyboard !> ?cont ;

: %scanImage    ( -- )
                ?cont
                if      ['] skip1line is scanaline
                else
                        @> scan1line !> scanaline
\                       ['] scan1line is scanaline
                then
                ?coarse
                if      off> ?coarse
                        Scan_Image_rough
                        off> ?cont
                        @> scan1line !> scanaline
\                        ['] scan1line is scanaline
                then
                ?keyboard ?exit
                Scan_Image_fine
                ;

: scanImage     ( -- )
                .info
                %scanImage
                ?keyboard 0=
                if      2000 1 tone
                else      30 1 tone
                then    .info ;

\ : topStripe     ( -- )
\                 plane_enable
\                 off> byteAddr                   \ initial image byte addr
\                 initTop
\                 16 0 DO
\                     80 0 DO
\                         onePoint onePoint onePoint onePoint
\                         onePoint onePoint onePoint onePoint
\                                                 ( p7 p6 p5 ... p0 -- )
\                         vgaByte
\                         1 +byteAddr             \ next byte
\                     LOOP
\                         nextRow
\                         ?keyboard ?leave
\                 LOOP    clearFstack
\                 ;

\ : bottomStripe  ( -- )
\                 plane_enable
\                 464 80 * !> byteAddr            \ initial image byte addr
\                 initBottom
\                 480 464 DO
\                     80 0 DO
\                         onePoint onePoint onePoint onePoint
\                         onePoint onePoint onePoint onePoint
\                                                 ( p7 p6 p5 ... p0 -- )
\                         vgaByte
\                         1 +byteAddr             \ next byte
\                     LOOP
\                         nextRow
\                         ?keyboard ?leave
\                 LOOP    clearFstack
\                 ;

\ : leftStripe    ( -- )
\                 plane_enable
\                 off> byteAddr                   \ initial image byte addr
\                 initTop
\                 480 0 DO
\                         onePoint onePoint onePoint onePoint
\                         onePoint onePoint onePoint onePoint
\                                                 ( p7 p6 p5 ... p0 -- )
\                         vgaByte
\                         1 +byteAddr             \ next byte
\                         onePoint onePoint onePoint onePoint
\                         onePoint onePoint onePoint onePoint
\                                                 ( p7 p6 p5 ... p0 -- )
\                         vgaByte
\                         79 +byteAddr             \ next byte
\                         nextRow
\                         ?keyboard ?leave
\                 LOOP    clearFstack
\                 ;

\ : rightStripe   ( -- )
\                 plane_enable
\                 78 !> byteAddr                  \ initial image byte addr
\                 initRight
\                 480 0 DO
\                         onePoint onePoint onePoint onePoint
\                         onePoint onePoint onePoint onePoint
\                                                 ( p7 p6 p5 ... p0 -- )
\                         vgaByte
\                         1 +byteAddr             \ next byte
\                         onePoint onePoint onePoint onePoint
\                         onePoint onePoint onePoint onePoint
\                                                 ( p7 p6 p5 ... p0 -- )
\                         vgaByte
\                         79 +byteAddr             \ next byte
\                         nextRight
\                         ?keyboard ?leave
\                 LOOP    clearFstack
\                 ;

: start         ( -- )
                initZoom
                on> ?coarse
                0 zoomPower !
                2 zoomFactor !
                64 iteration !
                hide.xmouse
                scanImage
                show.xmouse ;

code rightAdjust ( -- )
                fld     temp_real xx
                fld     temp_real zoom
                fmul    integer*2 shiftPixel
                fsubrp  st(1), st
                fstp    temp_real xx
                ret             end-code

: %right ( -- )
\                moveRight
                rightAdjust ;

: right ( -- )
                %right
\                 leftStripe
                ;

code leftAdjust ( -- )
                fld     temp_real xx
                fld     temp_real zoom
                fmul    integer*2 shiftPixel
                faddp   st(1), st
                fstp    temp_real xx
                ret             end-code

: %left         ( -- )
\                moveLeft
                leftAdjust
                ;

: left ( -- )
                %left
\                 rightStripe
                ;

code upAdjust ( -- )
                fld     temp_real yy
                fld     temp_real zoom
                fmul    integer*2 shiftPixel
                fsubrp  st(1), st
                fstp    temp_real yy
                ret             end-code

code downAdjust ( -- )
                fld     temp_real yy
                fld     temp_real zoom
                fmul    integer*2 shiftPixel
                faddp   st(1), st
                fstp    temp_real yy
                ret             end-code

: %up           ( -- )
\                moveUp
                downAdjust ;

: up            ( -- )
                %up
\                 bottomStripe
                .info
                ;

: %down         ( -- )
\                moveDown
                upAdjust ;

: down          ( -- )
\                 topStripe
                %down
                .info
                ;

: #s,           ( d -- 0 0 )
                begin   3 0
                        do      # 2dup  or 0= ?leave
                        loop    2dup or
                        if      ',' hold
                        then
                        2dup  or  0=
                until  ;

: ud.,          ( d1 -- )
                <# #s, #> type ;

0 value ?outing
2variable info_save

: .info         ( -- )
                0 0 at cols sp>col      \ erase top messages area
                0 0 at
                ." Iterations=" iteration @ 0 ud.,
                ." , Zoom=2^" zoomPower @ 1 .r
                at? info_save 2!
                ." , ESC: Stop redraw, Q: Quit, F1: HELP "
                ?cont
                if      ." (partial)"
                then
                ?skip   if ." B"                then
                ?center if ." C " ?center 8 * . then
                ;

: in            ( -- )
                zoomPower @ 60 > ?exit
                zoomPower incr
                inAdjust
\                expand
                off> ?cont
                .info
                ;

: out           ( -- )
                zoomPower @ -8 < ?exit
                zoomPower decr
                outAdjust
\                compress
                off> ?cont
                .info
                ;

: iteration0
                64 iteration !
                ;

: iteration+
                iteration @ dup 1024 u>=
                if      256 +
                else    16 +
                then    32768 umin iteration !
                .info ;

: iteration-
                iteration @ dup 1024 u>
                if      256 -
                else    16 -
                then    16 max iteration !
                .info ;

: mandel_help   ( -- )
        dark
        CR ."  Interactive Mandelbrot Plot For 486 PC"
        CR ."  Written by C. H. Ting, 1992, released to the public domain 01/23/93."
        CR ."  Mouse support and conversion to TCOM done by Tom Zimmer"
        CR ."  ษออออหออออหออออหออออป  Arrow: Move Plot        MOUSE buttons:"
        CR ."  บ    บ    บ *  บ    บ  D-,D+: Iteration +/-16      Left: Zoom in at cursor"
        CR ."  ฬออออฮออออฮออออฮออออน     D0: Iteration=64       Middle: Pan to cursor"
        CR ."  บ D0 บ   บ    บ    บ      I: show plot info      Right: Redraw"
        CR ."  ฬออออฮออออฮออออน    บ      Q:  Exit                   L: Load from file"
        CR ."  บ   บ    บ   บ    บ     F1: Help                    S: Save to   file"
        CR ."  ฬออออฮออออฮออออฮออออน      *: Reset image             B: toggle paint of"
        CR ."  บ D- บ   บ D+ บ E  บ     Z-: Zoom Out                   only black pixels"
        CR ."  ฬออออสออออฮออออน n  บ     Z+: Zoom In                 R: force low resolution"
        CR ."  บ   Z+    บ Z- บ t  บ  Enter: Redraw Plot (continue)     plot first"
        CR ."  ศอออออออออสออออสออออผ ^Enter: Full Redraw Plot"
        CR ."                             C: Center area, clips the plot area each"
        CR ."                                key press to the center of the screen"
        CR ."                         Alt-C: Expand Center plot area"
        ;

: signon ( -- )
        mandel_help
CR ." This is a Mandelbrot Plot Program for DOS PC with a 486."
CR ." It uses the floating point math coprocessor to compute colors."
CR ." Happy Mandelbrotting!  Send comments and suggestions to: "
CR ."   Offete Enterprises, 1306 South B Street, San Mateo, CA 94402"
CR ."   or Call (415) 574-8250"
CR ." Supported VGA cards: TRIDENT DIAMOND ORCHID TSENG ATI PARADISE GENOA VIDEO7"
CR ." Type: MANGEN {video_card_name | HEX_mode_number} [file {file..}]" BYE ;

: helping
        text-mode mandel_help
        cr cr
        cr cr ."  Press a key to redraw the mandelbrot, or Q to Quit"
        key upc 'Q' = if bye then
        gg
        off> ?cont
        scanImage
        ;

: lineedit-key   ( -- )
                insertmode @
        if      at? 16 * swap 8 * 1- swap over over 15 +
        else    at? 16 * swap 8 * swap 15 + over 8 + over
        then    save> color
                begin   ?keyboard 0=
                while           1 tenths 2over 2over white color ! line
                        ?keyboard 0=
                        if      1 tenths 2over 2over black color ! line
                        then
                        broken @ if text-mode bye then
                repeat                       black color ! line
                restore> color
                bioskey dup 127 and 0=
                if      flip dup 3 =
                        if      drop 0          \ allow a null
                        else    127 and 128 or
                        then
                else    255 and
                then    ;

640 array save_buf

                                        \ a1,n1=prompt text string
: set_image_name ( a1 n1 -- f1 )        \ f1=true  if accepted filename
                2>r                     \ f1=false if canceled save or load
                .info info_save 2@ at cols sp>col       \ show info, but
                                                        \ erase the help part
                manhndl c@ 42 >                         \ if name too long
                if      manhndl >pathend"               \ then use name only
                else    manhndl count                   \ else full path
                then    save_buf place
                info_save 2@ at ."   " 2r> type
                on> autoclear                           \ allow easy new name
                                                        \ entry
                ['] lineedit-key save!> key
                at? save_buf 42 lineeditor
                restore> key
                if      save_buf manhndl $>handle
                        true
                else    .info
                        false
                then    ;

: %save_image   ( -- )
                manhndl hcreate
                if      beep exit
                then
                ."   File: " manhndl >pathend" type cols sp>col
                zoom 128 manhndl hwrite 128 -   \ write image parameters
                if      beep
                        manhndl hclose drop
                        exit
                then
                480 0
                do      640 0
                        do      i J cpoint save_buf i + c!
                        loop
                        save_buf 640 manhndl hwrite 640 -
                        if      beep
                                manhndl hclose drop
                                leave
                        then
                        i 1+ 63 and 0=
                        if      50 1 tone
                        then
                        broken @ if text-mode bye then
                loop    manhndl hclose drop
                2000 1 tone .info ;

: save_image    ( -- )
                " Save File: " set_image_name 0= ?exit
                .info info_save 2@ at
                %save_image ;

: %load_image   ( -- )
                manhndl hopen
                if      beep .info off> ?cont EXIT
                then
                save_buf 128 manhndl hread 128 =   \ read image parameters
                if      save_buf zoom 128 cmove
                then
                off> vid_row
                480 0
                do      save_buf 640 manhndl hread 640 -
                        if      beep off> ?cont
                                manhndl hclose drop
                                leave
                        then
                        off> vid_col
                        680 0
                        do      i 8 bounds
                                do      save_buf i + c@
                                loop    8VgaDots
                     8 +loop    1 +vid_row
                        key? ?leave
                        broken @ if text-mode bye then
                loop
                manhndl hclose drop ;

: load_image    ( -- )
                " Load File: " set_image_name 0= ?exit
                %load_image
                2000 1 tone .info ;

: ?load_image   ( -- f1 )       \ f1=true if tried to load an image
                bl word c@ dup
                if      here manhndl $>handle
                        %load_image
                        2000 1 tone
                then    .info ;

: center_image  ( x y -- )
                240  - swap 320 - swap
                save> shiftPixel
                dup 0<
                if      abs     !> shiftPixel upAdjust
                else            !> shiftPixel downAdjust
                then
                dup 0<
                if      abs     !> shiftPixel rightAdjust
                else            !> shiftPixel leftAdjust
                then
                restore> shiftPixel ;

: mbutton       ( -- )         \ mouse button handler
                get_mouse
                case
[long]        1 of      get_mouse drop          \ zoom and redraw
                        hide.xmouse
                        center_image
                        in
                        off> ?cont
                        ScanImage
                        show.xmouse
                    endof
[long]        2 of      hide.xmouse             \ continue drawing
                        off> ?cont
                        ScanImage
                        show.xmouse
                    endof
              4 of      get_mouse drop          \ center and redraw
                        hide.xmouse
                        center_image
                        off> ?cont
                        ScanImage
                        show.xmouse
                    endof
                        drop
                endcase ;

0 value msavex
0 value msavey
0 value ?hidden

: set.mouse     ( -- )
                get_mouse drop !> msavey !> msavex
                on> ?hidden
                show.xmouse
                hide.xmouse ;

16 array mdots

0 value mcnt

: +mousedots!   ( n1 -- )       \ save color n1 in mdots array
                mdots mcnt + c!
                incr> mcnt ;

: +mousedots@   ( -- n1 )       \ get a color n1 from the mdots array
                mdots mcnt + c@
                incr> mcnt ;

: save.mouse    ( -- )
                off> mcnt
                msavex     msavey     getDot +mousedots!
                msavex 1-  msavey     getDot +mousedots!
                msavex 2-  msavey     getDot +mousedots!
                msavex 3 - msavey     getDot +mousedots!
                msavex 1+  msavey     getDot +mousedots!
                msavex 2+  msavey     getDot +mousedots!
                msavex 3 + msavey     getDot +mousedots!
                msavex     msavey 1-  getDot +mousedots!
                msavex     msavey 2-  getDot +mousedots!
                msavex     msavey 3 - getDot +mousedots!
                msavex     msavey 1+  getDot +mousedots!
                msavex     msavey 2+  getDot +mousedots!
                msavex     msavey 3 + getDot +mousedots!
                ;

: rest.mouse    ( -- )
                off> mcnt
                msavex     msavey     +mousedots@ vgaDot
                msavex 1-  msavey     +mousedots@ vgaDot
                msavex 2-  msavey     +mousedots@ vgaDot
                msavex 3 - msavey     +mousedots@ vgaDot
                msavex 1+  msavey     +mousedots@ vgaDot
                msavex 2+  msavey     +mousedots@ vgaDot
                msavex 3 + msavey     +mousedots@ vgaDot
                msavex     msavey 1-  +mousedots@ vgaDot
                msavex     msavey 2-  +mousedots@ vgaDot
                msavex     msavey 3 - +mousedots@ vgaDot
                msavex     msavey 1+  +mousedots@ vgaDot
                msavex     msavey 2+  +mousedots@ vgaDot
                msavex     msavey 3 + +mousedots@ vgaDot
                ;

: white.mouse   ( -- )
                msavex     msavey     vgaDotW
                msavex 1-  msavey     vgaDotW
                msavex 2-  msavey     vgaDotW
                msavex 3 - msavey     vgaDotW
                msavex 1+  msavey     vgaDotW
                msavex 2+  msavey     vgaDotW
                msavex 3 + msavey     vgaDotW
                msavex     msavey 1-  vgaDotW
                msavex     msavey 2-  vgaDotW
                msavex     msavey 3 - vgaDotW
                msavex     msavey 1+  vgaDotW
                msavex     msavey 2+  vgaDotW
                msavex     msavey 3 + vgaDotW
                ;

: hide.xmouse   ( -- )
                ?hidden ?exit
                on> ?hidden
                rest.mouse ;

: show.xmouse   ( -- )
                ?hidden 0= ?exit
                off> ?hidden
                save.mouse
                white.mouse ;

: domouse       ( -- )
                mbutton msavex msavey d= ?exit
                hide.xmouse
                get_mouse drop !> msavey !> msavex
                show.xmouse ;

: mouse.key     ( -- )
                begin   domouse key? until
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
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                INITMOUSE                       \ init the mouse
                ?vmode 7 = abort" VGA color required!" ;

: m486_init     ( -- )
                16 shiftPixel !
                0 zoomPower !
                2 zoomFactor !
                640 maxRow !
                480 maxColumn !
                320 maxRow/2 !
                240 maxColumn/2 !
                224 bottomMargin !
                304 rightMargin !
                64 iteration !
                -2 !> vcard
                " MANIMAGE.TMP" manhndl ">handle
                ;

: main  ( -- )
        tcom_init
        m486_init
        ?voption
        gg
        ?load_image 0=
        if      start
        else    ?cont                   \ If not done drawing image
                if      ScanImage       \ then continue drawing
                then
        then
        BEGIN   broken @ if text-mode bye then
                show.xmouse
                mouse.key
                hide.xmouse
                CASE
                 13 of  ScanImage       endof           \ Enter
                 10 of  off> ?cont
                        ScanImage       endof           \ Control Enter
                210 of  in              endof           \ Ins
                211 of  out             endof           \ Del
                207 of  iteration-      endof           \ End
                208 of  down            endof           \ down arrow
                209 of  iteration+      endof           \ PgDn
                203 of  left            endof           \ left arrow
                205 of  right           endof           \ right arrow
                199 of  iteration0      endof           \ Home
                200 of  up              endof           \ up arrow
                174 of  ?center 1- 0max !> ?center      \ Alt-C
                        ?center 0=
                        if      ['] fscan1line is scan1line
                                @> scan1line !> scanaline
                        then
                        .info           endof           \ center test toggle
               187  of  helping         endof           \ F1
                42  of  gg start        endof           \ *
            upc 'I' of  .info           endof           \ I
                'B' of  ?skip 0= !> ?skip
                        ?skip
                        if      off> ?center
                                ['] fscan1line is scan1line
                                @> scan1line !> scanaline
                        then
                        .info           endof           \ black test toggle
                'C' of  ?center 1+ 36 min !> ?center
                        off> ?skip
                        .info           endof           \ Center test toggle
                'L' of  load_image      endof           \ L=load
                'Q' of  text-mode
                        xsens ysens dspeed mouse.sense!
                        bye             endof           \ Q=Quit
                'R' of  on> ?coarse                     \ Redraw image coarse
                        off> ?cont
                        ScanImage       endof           \ Control Enter
                'S' of  save_image      endof           \ S=save
                drop
                ENDCASE
        AGAIN
        ;

\                 201 of  defaultPalette  endof           \ PgUp
\                 43  of  rotatePalette   endof           \ +
\                 45  of  reversePalette  endof           \ -
\                  9  of  palgray         endof           \ TAB


