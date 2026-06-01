\ MAN486.SEQ MANDELBROT PLOT WITH MATH COPPROCESSOR 21oct92cht

.options /opt /noinit

needs graph.seq

\ **********************************************************************
\ a group of variables to save with each graphic image  128 bytes
\ **********************************************************************
here                    /nostack1
create zoom 16 allot
create xx   16 allot
create yy   16 allot
create aa   16 allot
create bb   16 allot
variable iteration
variable shiftPixel
variable zoomFactor
variable zoomPower
0 value ?zoomed
\ **********************************************************************
here swap - 128 swap - 0max allot       \ allocate upto 128 byte boundry
\ **********************************************************************

variable vid_row
variable vid_col

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

0 value special_mode

: 640x480x256_special ( -- )
                special_mode 640 480 256 $A000 $FA00 cmode! ;

0 value vcard

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
                gtext-off ;

create vcards   ," tri dia orc tse ati par gen vid "

: ?voption      ( -- )
                bl word 1+ 2 vcards count search
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

code +vid_row  ( n1 -- )
                add     vid_row bx
                load_bx
                ret             end-code

: start         ( -- )
                on> ?zoomed
                0 zoomPower !
                2 zoomFactor !
                64 iteration !
                ?in 0=
                if      load_image
                then    ;

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
                ." , ESC: Stop redraw, L: Load image, Q: Quit"
                ;

: signon ( -- )
        dark
        CR
        CR ."  Mandelbrot Display Program example for the TCOM Forth compiler"
        CR ."  Written by Tom Zimmer, 02/05/93"
        CR
        CR ."  This public domain program is available from Tom Zimmer at the address"
        CR ."  listed below for US$60.  Included is the sources for MANSHOW, TCOM and"
        CR ."  more than 40 other examples."
        CR ."
        CR ."      Tom Zimmer              Home (408) 263-8859"
        CR ."      292 Falcato Drive       Work (415) 327-8800"
        CR ."      Milpitas, Ca. 95035"
        CR
        CR ."  Supported VGA cards include:"
        CR
        CR ."      TRIDENT DIAMOND ORCHID TSENG ATI PARADISE GENOA VIDEO7"
        CR
        CR ."  Type: MANSHOW {video_card_name | HEX_mode_number} [file {file..}]"
        CR BYE ;

handle manhndl

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
                at? save_buf 42 lineeditor
                if      save_buf manhndl $>handle
                        true
                else    .info
                        false
                then    ;

: %load_image   ( -- )
                bl word c@ 0=
                if      " Load File: " set_image_name 0= ?exit
                else    here manhndl $>handle
                then
                manhndl hopen
                if      beep .info exit
                then
                save_buf 128 manhndl hread 128 =   \ read image parameters
                if      save_buf zoom 128 cmove
                then
                off> vid_row
                480 0
                do      save_buf 640 manhndl hread 640 -
                        if      beep
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
                loop
                manhndl hclose drop
                .info  ;

: load_image    ( -- )
                %load_image
                2000 1 tone ;

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
                ?vmode 7 = abort" VGA color required!" ;

: m486_init     ( -- )
                16 shiftPixel !
                0 zoomPower !
                2 zoomFactor !
                -2 !> vcard
                " MANIMAGE.TMP" manhndl ">handle
                ;

: ?in           ( -- n1 )
                >in @ bl word c@ swap >in ! ;

: main  ( -- )
        tcom_init
        m486_init
        ?voption
        gg start
        BEGIN   begin   key? 0=
                while   ?in
                        if      %load_image                   \ load an image
                                key? 0=
                                if      2 seconds             \ a delay
                                then
                                ?in 0=
                                if      >in off bl word drop  \ reset line
                                then
                        then
                repeat  #tib off                \ reset input buffer
                key
                CASE
            upc 'L' of  load_image      endof           \ L=load
                'Q' of  text-mode bye   endof           \ Q=Quit
                drop
                ENDCASE
        AGAIN
        ;

