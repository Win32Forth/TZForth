\\ gt.seq        A graphics test for screen flood fill  by Tom Zimmer

  Test the bandwidth of the memory on your computers video card. Switches
to VGA mode $10 (640x480x16) and fills video memory with all colors from
black to white. Displays the resulting performance figure in millions of
pixels/second.

{

.options /opt /noinit

variable color          white color !           \ drawing color
variable vid.seg        $A000 vid.seg !         \ graphics segment

code totext     ( -- )
                mov ax, # $0003
                int $10
                ret     end-code

code 640x480    ( -- )
                mov vid.seg # $A000 word
                mov ax, # $0012
                int $10
                mov     ax, # $0F02
                mov     dx, # $03C4             \ mmr
                out     dx, ax                  \ enable all bit planes
                mov     dx, # $03CE             \ ega register base
                mov     ax, # $0F01             \ enable ega_sre
                out     dx, ax
                ret     end-code

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
               mov     es, vid.seg      \ use ds to address graphic memory
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

10 value iter_cnt

: test          ( -- )
\                dosio_init
                caps on
                ?ds: sseg !
                vmode.set
                DOS_TO_TIB                      \ move command tail to TIB
                bl word ?uppercase number? nip
        if      dup 1 max 100 min !> iter_cnt
 [long] else    cls
                cr
                cr ."  GT measures the flood fill performance of your "
                red >bg white >fg ."  VGA " >norm ."  graphics card."
                cr
                cr ."        Usage: GT [iteration_count] <enter>"
                cr
                cr ."  [iteration_count] can be in the range 1 to 100, default is 10."
                cr
                cr ."        This test will use: " iter_cnt .
                cr
                cr ."  GT is a public domain program.  GT was written by Tom Zimmer using TCOM."
                cr ."  TCOM is a public domain space and speed optimizing compiler for the
                cr ."  Forth computer language."
                cr
                cr ."        For information contact:    Tom Zimmer"
                cr ."                                    292 Falcato Drive"
                cr ."        (home) 408/263-8859         Milpitas, CA. 95035"
                cr
                red >bg white >fg
                cr 78 spaces
                cr ."   WARNING: Watching the flashing of this test for a prolonged period of time  "
                cr ."            can cause headachs." 78 sp>col
                cr 78 spaces
                >norm
                cr
                cr ."  Press Enter to start, or ESC to cancel"
                cr
                key 27 = ?exit
        then    drop
                640x480
                time-reset
                iter_cnt 0
                do      16 0
                        do      0 $9600 i video_fill
                        loop
                loop    totext cls cr
                cr ." The Video flood fill rate for this computer: "
                49152 iter_cnt um*
                time-elapsed drop um/mod nip 0
                <# # # '.' hold #s #> 6 over - spaces type
                ."  million pixels/second"
cr
cr ." For comparison:"
cr
cr ."                     TRIDENT on a 50 mhz 486:   7.85 million pixels/second."
cr ."          Orchid Prodesigner on a 33 mhz 386:  18.64 million pixels/second."
cr ."      Diamond Speed Star 24X on a 40 mhz 386:  24.54 million pixels/second."
cr ."  Tseng Labs Local Bus video on a 33 mhz 486:  64.84 million pixels/second."
                cr ;


