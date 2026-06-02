\\ SS.SEQ  Draw SAMSUNG LOGO in Graphic Mode  by Tom Zimmer & Robert Smith

        .options /opt /noinit /tailopton

{

needs graph.seq

: graph_bye     ( -- )          \ cleanup stuff when we are all done
                text-mode 0 1 at
   ." Usage: SSBLIT <enter>"
cr
cr ." SSBLIT displays the SAMSUNG logo using a memory bit image."
cr
cr ." The image is BIT-BLITed (byte moved) to the screen."
cr
cr ." SSBLIT.COM is a public domain example program by Tom Zimmer."
cr ." SSBLIT was written in Forth and compiled with the TCOM Target Compiler."
cr
cr              bye ;

code IconMove   ( a1 a2 -- )    \ move icon from memory a1
                                \ to screen byte a2
                                        \ bx=a2, screen byte address
        lodsw
        mov     di, ax                  \ di=a1, the byte address
        mov     cx, # 40
        push    es                      \ save es
        mov     es, &> vid.seg
        mov     dx, # 03CEh             \ ega register base

        push    si                      \ save si
        push    bp                      \ save bp
   2 $: push    cx
        mov     cx, # 5                 \ icon is 5 bytes wide
   1 $: mov     bp, cx
        xor     al, al                  \ al=0, ega_sr
        mov     si, # 8008h             \ pixel mask and command
        mov     cx, # 8
   0 $: mov     ah, color               \ get color of this pixel
        out     dx, ax                  \ set color into register
        xchg    ax, si                  \ ah=mask, al=8
        out     dx, ax                  \ set it into the register
        shr     ah, # 1                 \ shift to next bit in mask
        xchg    ax, si
        cmp     0 [di], # 0 byte        \ is color black?
        je      3 $                     \ skip byte if color is black
        inc     es: 0 [bx]              \ read/write a dummy pixel
   3 $: inc     di                      \ bump to color of next pixel
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
                                        \ bx=a2, screen byte address
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
   1 $: cmp     es: 0 [di], # 0
        je      3 $
        mov     ah, es: color           \ ah=color, al=0
        out     dx, ax                  \ set color into register
        inc       0 [bx]             \ read/write a dummy pixel
        inc      80 [bx]             \ read/write a dummy pixel
        inc     160 [bx]             \ read/write a dummy pixel
        inc     240 [bx]             \ read/write a dummy pixel
        inc     320 [bx]             \ read/write a dummy pixel
        inc     400 [bx]             \ read/write a dummy pixel
        inc     480 [bx]             \ read/write a dummy pixel
        inc     560 [bx]             \ read/write a dummy pixel
   3 $: inc     di                      \ bump to color of next pixel
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

create ss_icon
        0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,

create z_icon
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 1 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c, 1 c,
        1 c, 1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c,
        1 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 1 c, 1 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 1 c, 1 c, 1 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,
        0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c, 0 c,


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
                0 $41A c@L  0 $41C c@L - ;

0 value sscnt

122 value sscnt_limit

: show-ss       ( -- )
                ?planes_enable
                sscnt 1+ sscnt_limit mod !> sscnt
                sscnt sscnt_limit 2 - >
        [long]  if      black color !
                        sscnt_limit 10 <
                        if      10 rnd 1 max 0
                                do      z_icon 80 rnd 80 * 80 rnd + IconDMove
                                        z_icon  0                   IconDMove
                                loop
                        then
\                       z_icon 40 rnd 80 * 40 rnd + IconDMove
                        z_icon 80 rnd 80 * 80 rnd + IconDMove
                        sscnt_limit dup 4 / 1 max - 2 max !> sscnt_limit
                else    15 rnd 1+ color !
                        28000 rnd >r
                        ss_icon r@                  IconMove
                        ss_icon 1+ r@ 20 80 * + 3 + IconMove
                        ss_icon 1+ r> 20 80 * - 3 + IconMove
                then    ;

: tcom_init     ( -- )
                ?DS: SSEG !                     \ init search segment
                dosio_init
                0 SET_MEMORY ;                  \ default to minimum

: main          ( -- )          \ a simple drawing program
                tcom_init                       \ init I/O
                randomize
                ?vmode 7 = abort" Sorry, EGA/VGA Color required"
                640x350x16                      \ set graphics mode
                begin   show-ss
                        ?keyboard
                until   ?keyboard
                if      key drop                \ discard any key pressed
                then    graph_bye               \ terminate the program
                ;


