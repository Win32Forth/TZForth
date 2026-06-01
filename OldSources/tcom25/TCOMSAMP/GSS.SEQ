\\ gss.seq              A Graphics Screen Saver         by Tom Zimmer

  Draw seemingly random squares on a 640x480x16 graphic screen very
quickly!

{

.options /opt /noinit

needs graph.seq

create sintbl
          0 ,    25 ,    49 ,    74 ,    97 ,   120 ,   141 ,   160 ,
        178 ,   194 ,   207 ,   219 ,   228 ,   234 ,   238 ,   240 ,
        238 ,   234 ,   228 ,   219 ,   207 ,   194 ,   178 ,   160 ,
        141 ,   119 ,    97 ,    74 ,    49 ,    25 ,     0 ,   -25 ,
        -49 ,   -74 ,   -97 ,  -120 ,  -141 ,  -160 ,  -178 ,  -194 ,
       -207 ,  -219 ,  -228 ,  -234 ,  -238 ,  -240 ,  -238 ,  -234 ,
       -228 ,  -219 ,  -207 ,  -194 ,  -178 ,  -160 ,  -141 ,  -119 ,
        -97 ,   -74 ,   -49 ,   -25 ,     0 ,    25 ,    49 ,    74 ,
         97 ,   120 ,   141 ,   160 ,   178 ,   194 ,   207 ,   219 ,
        228 ,   234 ,   238 ,   240 ,   238 ,

320 value center-x
175 value center-y
240 value scale-y
0 value oblong

: xy-scale      ( 6deg scale -- x1 y1 )
                >r
                dup       2* sintbl + @ dup r@     240 */
                swap 1 and oblong negate * +        center-x +
                swap 15 + 2* sintbl + @ dup r> scale-y */
                swap 1 and oblong        * + negate center-y + ;

\ A full screen fill in 640x480x16 color mode takes only 40 milliseconds

code video_fill ( a1 n1 n2 -- )         \ fill n1 bytes of video memory
                                        \ starting at offset a1 with color n2
               lodsw
               mov cx, ax               \ count of bytes to fill
               lodsw
               mov di, ax               \ address of image byte
               mov     ax, bx           \ get the fill color
               mov     ah, al           \ color to high byte of AX
               sub     al, al           \ clear low byte of AX
               push    es               \ save ds
               mov     es, &> vid.seg   \ use ds to address graphic memory
               mov     dx, # $03CE      \ ega register base
               mov     bx, # $FF08      \ bit mask for ALL bits = 8 pixels
               xchg    ax, bx           \ ah=color, al=0
               out     dx, ax           \ set color we are using
               xchg    ax, bx           \ ah=mask, al=8
               out     dx, ax           \ set bits we will effect
               rep     stosb            \ repeated store to video memory
               pop     es               \ restore ds
               load_bx
               ret     end-code

0 value SEED1
0 value SEED2
0 value SEED3

CODE (RANDOMIZE) ( -- u )
                save_bx
                MOV AH, # 0
                INT 26
                mov bx, dx
                ret     END-CODE

: RANDOMIZE     ( -- )
                (RANDOMIZE)        !> SEED1
                (RANDOMIZE) 2* 1-  !> SEED2
                (RANDOMIZE) 2/ 1+  !> SEED3 ;

: RND           ( n1 -- n2 )
                1 max
                SEED1 177 /MOD  2*    SWAP  171 *  SWAP  - DUP  !> SEED1
                SEED2 176 /MOD  35 *  SWAP  172 *  SWAP  - DUP  !> SEED2
                SEED3 178 /MOD  63 *  SWAP  170 *  SWAP  - DUP  !> SEED3
                +  + SWAP  MOD  ;

: ?keyboard     ( -- f1 )
                0 $41A c@L 0 $41C c@L - ;

: .section      ( n1 -- )       \ show one section of samsung logo
                0 1 xy-scale
                rot 10 bounds
                do      2dup i 16 xy-scale line
                loop    2drop ;

: .ur           ( -- )
                ?keyboard ?exit
                 3 .section  20 +!> center-x -16 +!> center-y
                33 .section -20 +!> center-x  16 +!> center-y ;

: .lr           ( -- )
                ?keyboard ?exit
                18 .section  20 +!> center-x  16 +!> center-y
                48 .section -20 +!> center-x -16 +!> center-y ;

: .ul           ( -- )
                ?keyboard ?exit
                48 .section -20 +!> center-x -16 +!> center-y
                18 .section  20 +!> center-x  16 +!> center-y ;

: .ll           ( -- )
                ?keyboard ?exit
                33 .section -20 +!> center-x  16 +!> center-y
                 3 .section  20 +!> center-x -16 +!> center-y ;

: show-samsung  ( -- )
                ltred color !
                 55  !> center-x
                 40  !> center-y        .ur .lr .ul .ll
                -40 +!> center-x        .ur .lr
                 40 +!> center-x
                -32 +!> center-y        .lr .ll
                 64 +!> center-y        .ul .ur
                ;

0 value delay-value
0 value size-max
0 value size-max2
0 value ?next-size

: main          ( -- )
                50 FUDGE !                      \ init MS timer, GUESS!!
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                randomize
                bl word ?uppercase number? nip
                if      dup 0max 100 umin !> size-max
                then    drop
                bl word ?uppercase number? nip
                if      dup 1 max 30000 umin !> delay-value
                then    drop
                ?vmode 7 = abort" Must have COLOR VGA graphics"
                640x350x16
\                gtext-off                       \ disable drawn text
                vdots 2/ 1- !> center-y         \ calibrate screen center
                240 240 center-y */ !> scale-y  \ calibrate aspect ratio
                ?planes_enable
                0 $9600 blue video_fill
                ?text_enable
\               show-samsung                    \ display samsung logo
                white >fg blue >bg
                12 2 at ."  Tom's - Graphic Squares! "
                gtext-off
                ( 10 ) 3 tenths                 \ and pause for a bit
                ?planes_enable                  \ reenable planes
                0 $9600 blue video_fill
                size-max 1 max !> size-max2
                begin   time-reset
                        begin   15 rnd 1+ color c!
                                28000 size-max2 200 * - rnd      \ origin
                                size-max2 rnd 1+                 \ width
                                size-max2 3 * rnd 1+ 0           \ height
                                ?do     over i 80 * + over color c@ video_fill
                                loop    2drop
                                10th-elapsed 02 >
                                ?keyboard or
                                size-max or
                        until
                        size-max 0=
                        if      size-max2 dup 8 / + 1+ !> size-max2
                                size-max2 72 >
                                if      1 !> size-max2
\                                       ?text_enable
\                                       show-samsung    \ display samsung logo
\                                       15 tenths       \ and pause for a bit
\                                       ?planes_enable  \ reenable planes
                                then
                        then
                        delay-value 0
                        ?do     key? ?leave
                        loop    ?keyboard
                until
                key drop
                text-mode 0 0 at >norm
        cr ." Usage:  GSS {size_value(0-100[20]) {delay_value(2-32000[0])}} <enter>"
        cr
        cr ."    GSS (Graphic SAMSUNG Squares) by Tom Zimmer V2.01"
        cr
        cr ."    GSS draws random colored squares on the screen in 640x350x16 graphics"
        cr ."    mode very quickly."
        cr
        cr ."    GSS was written in Forth and assembly language."
        cr
        cr ."    GSS was compiled with TCOM, an optimizing (space & speed) Forth compiler."
        cr
        cr ."    If you want information about GSS or TCOM, contact:
        cr
        cr ."    Order: Tom Zimmer              Info Phone:"
        cr ."           292 Falcato Drive               Home (408) 263-8859"
        cr ."           Milpitas, CA. 95035             Work (415) 327-8800"
        cr
        cr ."    TCOM with GSS is available with full source for a donation of US$60"
        cr ."    postage paid.  Outside US orders add 20 dollars."
        cr ;

