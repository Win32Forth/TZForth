\\ KOKO.SEQ      KOKO by Koller, modifications for TCOM  by Tom Zimmer

 koko (frepeat) 9.4.92.
 Modifications for compatibility with both F-PC & TCOM 05/23/93 by Tom Zimmer.

{

\tcom   needs tfloat
\tcom   needs graph

\fpc    fload sfloat
\fpc    fload \tcom\graph.seq

\fpc    : [F#] ; immediate

0 value SEED1
0 value SEED2
0 value SEED3

CODE (RANDOMIZE) ( -- u )
\tcom           save_bx
                MOV AH, # 0
                INT 26
\fpc            push dx
\fpc            next
\tcom           mov bx, dx
\tcom           ret
                END-CODE

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

fvariable a
fvariable bb
fvariable c
fvariable x
fvariable y
fvariable xx
fvariable yy
fvariable fheight/2
fvariable fwid/2

0 value ix
0 value iy

65535 constant #iterationen

#iterationen 0 15 um/mod nip constant countcolor

create paltable 0 c, 15 allot 0 c,

code set-pal    ( -- )
                push es
                mov ax, # $1002
                push ds
                pop es
                mov dx, # paltable
                int $10
                pop es
\fpc            next
\tcom           ret
                end-code

: set-paltable 16 1 do 63 rnd 1+ paltable i + c! loop set-pal ;

code in-bounds? ( x y -- x y true | false)
\fpc            pop dx
\fpc            pop cx
\tcom           mov dx, bx
\tcom           load_bx
\tcom           mov cx, bx
                xor ax, ax
                cmp dx, &> vdots                \ height
                jge 1 $
                        cmp cx, &> hdots        \ wid
                jge 1 $
                        xor bx, bx
                        cmp dx, bx
                jl 1 $
                        cmp cx, bx
                jl 1 $
                        dec ax
\fpc            push cx
\fpc            push dx
\tcom           mov bx, cx
\tcom           save_bx
\tcom           mov bx, dx
\tcom           save_bx
        1 $:
\fpc            1push
\tcom           mov bx, ax
\tcom           ret
                end-code

: "f#in         ( D: a1 n1 --   F:--r)
                2>r
                begin   2r@ type
                        pad 1+ 12 expect
\tcom                   esc_flg @ if koko-abort then    \ leave if requested
                        bl pad 1+ span @ + c!  span @ pad c!
                        pad (fnumber?) ?dup 0=
                while   ."  <- BAD INPUT!" cr
                repeat  0< if float then
                2r> 2drop ;

: koko-abort    ( -- )
                text-mode bye ;

: get-var       ( -- )
                text-mode
                cr ." KOKO  by KOnrad KOller"
                cr
                cr ."          Konrad's interesting (Fractal?) graphics program."
                cr
                cr ." Try a set of numbers (ESC=NO)? [Y] "
                key upc 27 = if koko-abort then
                cr
                cr ."  A = "  a f@ f. 20 sp>col " or new value: " "f#in
                fdup [F#] 0.02e0 f> if  a f! else fdrop then
                cr ." BB = " bb f@ f. 20 sp>col " or new value: " "f#in
                fdup [F#] 0.02e0 f> if bb f! else fdrop then
                cr ."  C = "  c f@ f. 20 sp>col " or new value: " "f#in
                fdup [F#] 0.02e0 f> if  c f! else fdrop then
                ;

: fsign         ( F:r--1.0|-1.0)
                f0< if [F#] -1.0e0 else f1.0 then ;

: graphics-mode ( -- )
                640x350x16 ;

: ?keyboard     ( -- f1 )
                0 $41A c@L 0 $41C c@L - ;

: tcom-init     ( -- )
\tcom           DECIMAL                         \ always select decimal
\tcom           ?DS: SSEG !                     \ init search segment
\tcom           DOSIO_INIT                      \ init EMIT, TYPE & SPACES
\tcom           0 SET_MEMORY                    \ default to minimum
\tcom           DOS_TO_TIB                      \ move command tail to TIB
                ;

: koko
        tcom-init
\fpc    floats
\tcom   ['] koko-abort is abort_func
        [F#] 57.23e0  a f!
        [F#] 12.3e0  bb f!
        [F#] 43.23e0  c f!
        graphics-mode
        randomize
        vdots 2/ 0 float fheight/2 f!
        hdots 2/ 0 float fwid/2 f!
        begin   get-var
                f0.0 x f!  f0.0 y f!
                graphics-mode
                0 color !
                set-paltable
                #iterationen 0
                do      i countcolor mod 0=
                        if      color incr
                        then
                        fheight/2 f@ y f@ f+ fix drop !> iy
                        fwid/2    f@ x f@ f+ fix drop !> ix
                        ix iy in-bounds?
                        if      plot
                        then
                        x f@  bb f@
                        y f@  f*  c f@  f-  fabs  fsqrt
                        y f@  fsign  f*  f- yy f!
                        a f@  y f@  f-  x f!  yy f@  y f!
                        c f@  fnegate  c f!
\tcom                   broken @ if koko-abort then
                        ?keyboard ?leave
                loop    c f@ fabs c f!
                ?keyboard 0=
                if      2000 1 tone
                then    key drop
        again   ;

 