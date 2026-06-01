\\ GRAPH.SEQ    Simple graphics support.

    select a graphics mode from the list (for example 320x200x16). After
    this is done, you can set the COLOR of plotting, and start plotting
    points.

    For hercules graphics, load HERC.SEQ after GRAPH.SEQ
    Execute GRAPH-INIT, then HERCULES to enter graphics mode.
    Set COLOR to 1 and start plotting.

    The VALUE's HDOTS, VDOTS and #COLORS are initialized for the maximum
    horizontal resolution, vertical resolution and colors of the graphics
    mode selected.
{

FORTH DECIMAL
\tcom TARGET >LIBRARY       \ A Library file

\fpc  ' noop alias [Llong] immediate

0 VALUE VDOTS           \ vertical dots in screen
0 VALUE HDOTS           \ horizontal dots in screen
0 VALUE #COLORS         \ # of colors in current graphics mode
0 VALUE VID.SEG         \ video buffer segment address
0 VALUE VID.SIZE        \ video buffer size
0 value t-width         \ pixel width of text
0 value t-height        \ pixel height of text
0 value ?direct         \ direct to memory plotting flag

\ g-enabled? and g-color have been moved into LIBRARY.SEQ,
\ so it can be accessed by others

VARIABLE COLOR          \ color of the DOT

-1 VALUE VMODE-SAVE

DEFER PRIMITIVE-EMIT    ( char -- )          \ emit func before graphics mode
DEFER PLOT              ( col row -- )       \ Plot point at pixel 'col row'.
DEFER POINT             ( col row -- color ) \ Get pixel color at 'col row'.
DEFER TEXT-MODE         ( -- )               \ return to text mode.

: gfill ( n -- ) \ fill video page with byte value n
        >r vid.seg 0 vid.size r> lfill  ;

: gdark ( -- ) \ graphics dark
        0 gfill ;

: glight ( -- ) \ graphics light, opposite of dark.
        $ff gfill  ;

\tcom }         \ load ONLY for F-PC, NOT TCOM!
CODE VIDEO ( DX CX BX AX -- DX AX )     \ perform a VIDEO interrupt call.
                POP AX  POP BX  POP CX  POP DX
                PUSH SI         PUSH BP
                INT $10
                POP BP          POP SI
                2push           END-CODE

\ use VMODE! to set video modes.
\ n1 is the desired mode number.
\ For example 6 VMODE! will select 640x200 black & white graphics.
: VMODE!        ( n1 -- )
                >R 0 0 0 R> VIDEO 2DROP ;

0 VALUE G-ENABLED?
0 VALUE G-COLOR

{

: V7VMODE!      ( n1 -- )
                >R 0 0 R> $6F05 VIDEO 2DROP ;       \tcom NO-INTERPRET

code vgaCDot    ( x y -- )
        cmp &> g-enabled? # 0 word
     0= if      mov     &> g-enabled? # -1 word \ mark as enabled
                mov     ax, # 0F02h
                mov     dx, # 03C4h             \ mmr
                out     dx, ax                  \ enable all bit planes
                mov     dx, # 03CEh             \ ega register base
                mov     ax, # 0F01h             \ enable ega_sre
                out     dx, ax
                mov     ax, # FF08h             \ pixel mask and command
                out     dx, ax
        then
        mov     ax, color               \ has the color changed?
        cmp     ax, &> g-color
    0<> if      mov     &> g-color ax   \ if so, then set the color
                mov     ah, al          \ ah=color
                xor     al, al          \ al=0, ega_sr register
                mov     dx, # 03CEh     \ ega register base
                out     dx, ax          \ set the color planes
                mov     ax, # 0F01h     \ ega_sre
                out     dx, ax
        then
\fpc    pop     bx
        mov     ax, bx                  \ ax=y
        mov     dx, # 50h               \ bytes per row
        mul     ax, dx                  \ calc row start address
        mov     cx, ax                  \ cx=row start address
\fpc    pop     ax
\tcom   lodsw                           \ ax=x
        or      bx, ax
\tcom   cmp     bx, bp                  \ check for below zero point
\fpc    cmp     bx, # 0h
      > IF  mov     bx, ax              \ move x to bx for pixel in byte calc
            shr     bx, # 1             \ divide x by 8 for byte in row
            shr     bx, # 1
            shr     bx, # 1
            add     bx, cx              \ address of byte holding our pixel
            mov     cl, al              \ get low byte of x into cl
            and     cl, # 7             \ bit mask
            mov     ah, # 80h
            shr     ah, cl
            mov     al, # 8             \ Al=8, ega_bitmask register
            mov     dx, # 03CEh         \ ega register base
            out     dx, ax              \ set the pixel mask

            mov     di, es              \ save ES
            mov     es, &> vid.seg      \ use ES to address graphic mem seg
            inc     es: 0 [bx]          \ do a dummy read/write of byte
            mov     es, di              \ recover ES
        THEN
\tcom   load_bx
\tcom   ret
\fpc    next
        end-code

code ?planes_enable
        cmp &> g-enabled? # 0 word
     0= if      mov     &> g-enabled? # -1 word \ mark as enabled
                mov     ax, # 0F02h
                mov     dx, # 03C4h             \ mmr
                out     dx, ax                  \ enable all bit planes
                mov     dx, # 03CEh             \ ega register base
                mov     ax, # 0F01h             \ enable ega_sre
                out     dx, ax
                mov     ax, # FF08h             \ pixel mask and command
                out     dx, ax
        then
\tcom   ret
\fpc    next
        end-code

code ?text_enable
        cmp     &> g-enabled? # 0h word         \ were we using graphics?
    0<> if      mov     &> g-enabled? # 0h word \ clear the graphics flag
                mov     ax, # 0F02h             \ then enable text mask
                mov     dx, # 03C4h             \ mmr
                out     dx, ax                  \ enable all bit planes
                mov     dx, # 03CEh             \ ega register base
                mov     ax, # 0001h             \ enable set/reset enable
                out     dx, ax
                mov     ax, # FF08h             \ pixel mask and command
                out     dx, ax
        then
\tcom   ret
\fpc    next
        end-code

code vgaByte!    ( c1 a1 -- )   \ store byte c1 into display address a1.
        cmp &> g-enabled? # 0 word
     0= if      mov     &> g-enabled? # -1 word \ mark as enabled
                mov     ax, # 0F02h
                mov     dx, # 03C4h             \ mmr
                out     dx, ax                  \ enable all bit planes
                mov     dx, # 03CEh             \ ega register base
                mov     ax, # 0F01h             \ enable ega_sre
                out     dx, ax
                mov     ax, # FF08h             \ pixel mask and command
                out     dx, ax
        then
\tcom   mov     di, bx                  \ di=a1, the video display address
\tcom   load_bx                         \ bx=c1, the character mask
\fpc    pop     di                      \ di=a1
\fpc    pop     bx                      \ bx=character
        xchg    bl, bh                  \ mask into high byte of BX
        mov     bl, # 08                \ bh=mask, bl=8  (the command)
        push    es                      \ save es
        mov     es, &> vid.seg          \ use es to address graphic memory
        mov     dx, # 03CEh             \ ega register base
        xor     al, al                  \ al=0, ega_sr
        mov     ah, attrib              \ ah=color, al=0
        shr     ah, # 1                 \ shift the background color down
        shr     ah, # 1                 \ to the lower nibble
        shr     ah, # 1
        shr     ah, # 1
        out     dx, ax                  \ set color into register
        mov     ax, bx                  \ ah=mask, al=8
        xor     ah, # FFh               \ invert the bits of mask
        out     dx, ax                  \ set it into the register
        inc     es: 0 [di]              \ dummy read/write background bits
        xor     al, al                  \ al=0, ega_sr
        mov     ah, attrib              \ ah=color, al=0
        and     ah, # 0Fh               \ mask to lower nibble
        out     dx, ax                  \ set color into register
        mov     ax, bx                  \ ah=mask, al=8
        out     dx, ax                  \ set it into the register
        inc     es: 0 [di]              \ dummy read/write forground bits
        pop     es                      \ restore es
\tcom   load_bx
\tcom   ret
\fpc    next
        end-code


\ Text for Graphics Mode

$0F000 value charseg
$0F000 value charsegL
$0F000 value charsegH
$0FA6E value chartblL
$0FA6E value chartblH
0      value charadr
0      value g-X
0      value g-Y

: p-left        ( n -- ) \ move the text location n pixels to the left
                g-X swap -  0max   !> g-X ;
: p-right       ( n -- ) \ move the text location n pixels to the right
                g-X swap +  0max   !> g-X ;
: p-up          ( n -- ) \ move the text location n pixels up
                g-Y swap -  0max   !> g-Y ;
: p-down        ( n -- ) \ move the text location n pixels down
                g-Y swap +  0max   !> g-Y ;

: char-left     ( n -- ) \ move the text location n characters to the left
                t-width * p-left ;
: char-right    ( n -- ) \ move the text location n characters to the right
                t-width * p-right ;
: line-up       ( n -- ) \ move the text location n characters up
                t-height * p-up ;
: line-down     ( n -- ) \ move the text location n characters down
                t-height * p-down ;

: p-at ( x y -- ) \ pixel-specific AT
        !> g-Y !> g-X   ;

: p-at? ( -- x y ) \ pixel-specific AT?
        g-X  g-Y  ;

: g-at ( x y -- ) \ text AT for graphics
        dup !> #line t-height * !> g-Y
        dup !> #out  t-width  * !> g-X ;

: g-at? ( -- x y ) \ text AT? for graphics
        g-X t-width /  g-Y t-height /  ;

: g-cr ( -- ) \ carriage return in graphics mode
        g-Y t-height +
        vdots t-height -  min  !> g-Y off> g-X
        off> #out incr> #line ;

\tcom }         \ don't load this for TCOM
: g-typeL ( s a l -- )
        bounds ?do  dup i c@L emit  loop  drop ;

: ghide.mouse   ( -- )
                [ hidden ]
                hide.ms                 \ mdc
                off> g-enabled?
                off> mouseflg ;

switch hide.mouse ghide.mouse

: gshow.mouse   ( --- )                 \ enable display of mouse cursor
                [ hidden ]
                show.ms                 \ mdc
                off> g-enabled?
                havemouse =: mouseflg
                lastx lasty mousexy! ;

switch show.mouse gshow.mouse

FORTH

{

: g-type ( a l -- )
        bounds ?do  i c@ emit  loop  ;

: g-emit ( c -- ) \ plot out a character
\fpc    off> g-enabled?
        save> color
        dup $7F >
        if      $80 -
                t-height * chartblH +  !> charadr
                charsegH               !> charseg
        else    t-height * chartblL +  !> charadr
                charsegL               !> charseg
        then
        g-X 8 mod 0=            \ if on an 8bit boundry
        ?direct and             \ and plotting direct to memory
        if      g-X 8 / g-Y 80 * +
                t-height
                0 do    charseg charadr c@l over vgaByte!  \ store a byte
                        80 +                               \ next vid addr
                        incr> charadr                      \ next font byte
                  loop  drop
[Llong] else    t-height
                0 do    charseg charadr c@l  incr> charadr
                        t-width
                        0 do    dup $80 and
                                if      attrib c@ $F and
                                else    attrib c@ $10 /
                                then    color !
                                g-X i +  g-Y j +  plot
                                2*
                          loop
                        drop
                  loop
        then    restore> color
        t-width +!> g-X
        incr> #out
        hdots g-X - t-width <= if  g-cr  then
        ;

\fpc    0 value savetypeL
        0 value savetype
        0 value saveemit
        0 value saveat
        0 value saveat?
        0 value savecr

: gtext-on ( -- ) \ set the deferred words for graphics text
        off> g-enabled?                 \ mark as not yet enabled
        off> ?direct                    \ no direct video access
        savecr ?exit                    \ leave if already saved
\fpc    slow
\fpc    ['] g-typeL save!> typeL  restore> savetypeL
        ['] g-type  save!> type   restore> savetype
        ['] g-emit  save!> emit   restore> saveemit
        ['] g-at    save!> at     restore> saveat
        ['] g-at?   save!> at?    restore> saveat?
        ['] g-cr    save!> cr     restore> savecr
        saveemit  is primitive-emit
        8 !> t-width                    \ pixel width of text
        8 !> t-height   ;               \ pixel height of text

: CEMIT         ( char -- )
                ?text_enable    primitive-emit
                off> g-enabled? ?text_enable ;

: gtext-off ( -- ) \ restore deferred words for text mode
        savecr 0= ?exit         \ exit if nothing to restore
\fpc    savetypeL is typeL
        savetype  is type
        saveemit  is emit
        saveat    is at
        saveat?   is at?
        savecr    is cr
        off> savecr
        ;

CODE GET-FONT-TBL ( bx -- es bp )
\fpc            pop bx
                push es
                push bp
                mov bh, bl              \ put the BL request in BH
                sub bl, bl              \ and clear BL
                mov ax, # 1130h         \ get font information
                int 10h                 \ perform the interrupt
\tcom           mov bx, es
\tcom           save_bx                 \ es=segment of font table
\tcom           mov bx, bp              \ bp=offset of font table
\fpc            mov bx, es
\fpc            mov ax, bp
                pop bp
                pop es
\fpc            push bx
\fpc            1push
\tcom           ret
                end-code

: 8x14FONT      ( -- )          \ setup for 8 by 14 point font
                14 !> t-height
                2 get-font-tbl
                dup !> chartblL t-height $80 * + !> chartblH
                dup !> charsegL                  !> charsegH ;

: 8x8FONT       ( -- )          \ setup for 8 by 8 point font
                8 !> t-height
                3 get-font-tbl !> chartblL !> charsegL
                4 get-font-tbl !> chartblH !> charsegH ;

CODE CGA.PALETTE ( p# bcol -- ) \ p#=palette #, bcol=background color
\fpc    POP BX  POP AX
\fpc    MOV BH, AL
\fpc    MOV AH, # $0B
\fpc    PUSH BP  PUSH SI
\fpc    INT $10
\fpc    POP SI   POP BP
\fpc    NEXT

\tcom   LODSW           ( bh bl -- ) \ bh=palette #, bl=background color
\tcom   MOV BH, AL
\tcom   MOV AH, # $0B
\tcom   INT $10
\tcom   LOAD_BX
\tcom   RET
        END-CODE

CODE CPLOT      ( col row -- )
\fpc            POP BX
                MOV DX, BX              \ DX=row
\tcom           LODSW
\fpc            POP AX
                MOV CX, AX              \ CX=col
                OR  AX, BX
\tcom           CMP AX, BP      \ exit if either row or col is negative
\fpc            CMP AX, # 0h
              > IF      MOV AL, COLOR
                        MOV AH, # $0C
                        SUB BX, BX
                        PUSH DS
                        PUSH BP
                        PUSH SI
                        INT $10
                        POP SI
                        POP BP
                        POP DS
                THEN
\tcom           LOAD_BX
\tcom           RET
\fpc            NEXT
                END-CODE

: CPOINT    ( col row -- color )    \ get the color of a point on CGA
                                    \ graphics screen.
            SWAP 0 $0D00 VIDEO NIP $FF AND ;

: CTEXT         ( -- )  \ switch from color-graphics back to text mode
                gtext-off                       \ disable graphics text
\fpc            fast  >norm
                @> primitive-emit is emit       \ restore original emit
                VMODE-SAVE -1 <>
                if      VMODE-SAVE VMODE!
                then    -1 !> VMODE-SAVE
                AT? AT ;                        \ init cursor position

: (gmode) ( horiz vert colors seg len -- )
        VMODE-SAVE -1 =
        if      ?VMODE =: VMODE-SAVE
        then    !> VID.SIZE     !> VID.SEG
                !> #COLORS      !> VDOTS        !> HDOTS
        #COLORS 1- !> COLOR             \ default to highest color plotting
        gtext-on                        \ switch text words to graphics mode
        ['] CPLOT   IS PLOT
        ['] CPOINT  IS POINT
        ['] CTEXT   IS TEXT-MODE
        ;

: CMODE!        ( mode horiz vert colors seg len -- )
                (gmode) VMODE! ;

: V7CMODE!      ( mode horiz vert colors seg len -- )
                (gmode) V7VMODE! ;

\ Graph mode           Mode  Hor Ver Clrs Seg   Size
: 320x200x4             $04  320 200   4 $B800 $4000 CMODE! ;  \ CGA
: 320x200x4M            $05  320 200   4 $B800 $4000 CMODE! ;  \ CGA COMPOSITE
: 640x200x2             $06  640 200   2 $B800 $4000 CMODE! ;  \ CGA
: 320x200x16            $0D  320 200  16 $A000 $9600 CMODE! ;  \ EGA,VGA
: 640x200x16            $0E  640 200  16 $A000 $9600 CMODE! ;  \ EGA,VGA
: 640x350x2             $0F  640 350   2 $A000 $9600 CMODE! ;  \ EGA,VGA MONO
: 640x350x16            $10  640 350  16 $A000 $9600 CMODE!    \ EGA,VGA
                        ['] vgaCDot   is plot 8x14font on> ?direct ;
: 640x480x2             $11  640 480   2 $A000 $9600 CMODE! ;  \ EGA,VGA
: 640x480x16            $12  640 480  16 $A000 $9600 CMODE!    \ VGA
                        ['] vgaCDot   is plot 8x14font on> ?direct ;
: 320x200x256           $13  320 200 256 $A000 $FA00 CMODE! ;  \ VGA
: 800x600x16_OAK        $52  800 600  16 $A000 $FA00 CMODE! ;  \ OAK
: 800x600x16_TSENG      $29  800 600  16 $A000 $FA00 CMODE! ;  \ ORCHID TSENG
: 640x350x256_TSENG     $2D  640 350 256 $A000 $FA00 CMODE! ;  \ ORCHID TSENG
: 640x480x256_TSENG     $2E  640 480 256 $A000 $FA00 CMODE! ;  \ ORCHID TSENG
: 800x600x256_TSENG     $30  800 600 256 $A000 $FA00 CMODE! ;  \ ORCHID TSENG
: 1024x768x16_TSENG     $37 1024 768  16 $A000 $FA00 CMODE! ;  \ ORCHID TSENG
: 1024x768x256_TSENG    $38 1024 768 256 $A000 $FA00 CMODE! ;  \ ORCHID TSENG
: 640x400x256_VESA     $100  640 400 256 $A000 $FA00 CMODE! ;  \ VESA
: 640x480x256_VESA     $101  640 480 256 $A000 $FA00 CMODE! ;  \ VESA
: 800x600x16_VESA      $102  800 600  16 $A000 $FA00 CMODE! ;  \ VESA
: 800x600x256_VESA     $103  800 600 256 $A000 $FA00 CMODE! ;  \ VESA
: 1024x768x16_VESA     $104 1024 768  16 $A000 $FA00 CMODE! ;  \ VESA
: 1024x768x256_VESA    $105 1024 768 256 $A000 $FA00 CMODE! ;  \ VESA
: 640x400x256_VIDEO7    $66  640 400 256 $A000 $FA00 V7CMODE! ;  \ VIDEO7
: 640x480x256_VIDEO7    $67  640 480 256 $A000 $FA00 V7CMODE! ;  \ VIDEO7
: 800x600x16_VIDEO7     $62  800 600  16 $A000 $FA00 V7CMODE! ;  \ VIDEO7
: 800x600x256_VIDEO7    $69  800 600 256 $A000 $FA00 V7CMODE! ;  \ VIDEO7
: 1024x768x16_VIDEO7    $65 1024 768  16 $A000 $FA00 V7CMODE! ;  \ VIDEO7
: 640x480x256_ATI       $62  640 480 256 $A000 $FA00 CMODE! ;  \ ATI
: 800x600x16_ATI        $54  800 600  16 $A000 $FA00 CMODE! ;  \ ATI
: 800x600x256_ATI       $63  800 600 256 $A000 $FA00 CMODE! ;  \ ATI
: 1024x768x16_ATI       $67 1024 768  16 $A000 $FA00 CMODE! ;  \ ATI
: 640x480x256_GENOA     $5C  640 480 256 $A000 $FA00 CMODE! ;  \ GENOA
: 800x600x16_GENOA      $6A  800 600  16 $A000 $FA00 CMODE! ;  \ GENOA
: 800x600x256_GENOA     $6C  800 600 256 $A000 $FA00 CMODE! ;  \ GENOA
: 1024x768x16_GENOA     $5F 1024 768  16 $A000 $FA00 CMODE! ;  \ GENOA
: 640x480x256_TRIDENT   $5D  640 480 256 $A000 $FA00 CMODE! ;  \ TRIDENT
: 800x600x16_TRIDENT    $5B  800 600  16 $A000 $FA00 CMODE! ;  \ TRIDENT
: 1024x768x16_TRIDENT   $5F 1024 768  16 $A000 $FA00 CMODE! ;  \ TRIDENT
: 1024x768x256_TRIDENT  $62 1024 768 256 $A000 $FA00 CMODE! ;  \ TRIDENT
: 640x480x256_PARADISE  $5F  640 480 256 $A000 $FA00 CMODE! ;  \ PARADISE
: 800x600x16_PARADISE   $58  800 600  16 $A000 $FA00 CMODE! ;  \ PARADISE
: 1024x768x16_PARADISE  $5D 1024 768  16 $A000 $FA00 CMODE! ;  \ PARADISE


\\ LINE-DRAWING ALGORITHM  by  JOHNNY GRAVES     modified by Tom Zimmer

    This algorithm, LINE, is written in high-level FORTH, and thus is
    relatively slow. It has the advantage, however, that it works
    properly in the EGA, VGA, TSENG, VESA, ATI, GENOA, TRIDENT and
    VIDEO7 modes.

{

VARIABLE X1     VARIABLE X2
VARIABLE Y1     VARIABLE Y2
VARIABLE ERR
VARIABLE DELX   VARIABLE DELY
VARIABLE HALFX  VARIABLE HALFY
VARIABLE CHEC

: LINEINIT      ( -- )
        X1 @  X2 @ - ABS DUP DELX !  2/
        HALFX !  Y1 @ Y2 @ - ABS DUP DELY ! 2/ HALFY !   0 ERR !
        DELY @ DELX @ > CHEC ! ;

: X1=X2 (  -- f )    X1 @ X2 @ = ;
: Y1=Y2 (  -- f )    Y1 @ Y2 @ = ;

( LINE ALGORITHM )

: DO-1  X1 @ Y1 @ PLOT X1 INCR DELY @ ERR +!
        HALFX @ ERR @ < IF DELX @ NEGATE ERR +! Y1 INCR THEN ;

: DO-2  X1 @ Y1 @ PLOT X1 INCR DELY @ ERR +!
        HALFX @ ERR @ < IF DELX @ NEGATE ERR +! Y1 DECR THEN ;

: DO-3  X1 @ Y1 @ PLOT X1 DECR DELY @ ERR +!
        HALFX @ ERR @ < IF DELX @ NEGATE ERR +! Y1 INCR THEN ;

: DO-4  X1 @ Y1 @ PLOT X1 DECR DELY @ ERR +!
        HALFX @ ERR @ < IF DELX @ NEGATE ERR +! Y1 DECR THEN ;

: DO-1' X1 @ Y1 @ PLOT Y1 INCR DELX @ ERR +!
        HALFY @ ERR @ < IF DELY @ NEGATE ERR +! X1 INCR THEN ;

: DO-2' X1 @ Y1 @ PLOT Y1 DECR DELX @ ERR +!
        HALFY @ ERR @ < IF DELY @ NEGATE ERR +! X1 INCR THEN ;

: DO-3' X1 @ Y1 @ PLOT Y1 INCR DELX @ ERR +!
        HALFY @ ERR @ < IF DELY @ NEGATE ERR +! X1 DECR THEN ;

: DO-4' X1 @ Y1 @ PLOT Y1 DECR DELX @ ERR +!
        HALFY @ ERR @ < IF DELY @ NEGATE ERR +! X1 DECR THEN ;

: 1/1'   CHEC @ IF      BEGIN DO-1' Y1=Y2 UNTIL
                ELSE    BEGIN DO-1  X1=X2 UNTIL  THEN ;

: 2/2'   CHEC @ IF      BEGIN DO-2' Y1=Y2 UNTIL
                ELSE    BEGIN DO-2  X1=X2 UNTIL  THEN ;

: 3/3'   CHEC @ IF      BEGIN DO-3' Y1=Y2 UNTIL
                ELSE    BEGIN DO-3  X1=X2 UNTIL  THEN ;

: 4/4'   CHEC @ IF      BEGIN DO-4' Y1=Y2 UNTIL
                ELSE    BEGIN DO-4  X1=X2 UNTIL  THEN ;


: 2S-OR-3S      X1 @ X2 @ < IF  2/2'  ELSE  3/3'  THEN ;
: 1S-OR-4S      X1 @ X2 @ < IF  1/1'  ELSE  4/4'  THEN ;

: LINE?         X1 @ X2 @ <  Y1 @ Y2 @ <  XOR
                IF      2S-OR-3S
                ELSE    1S-OR-4S  THEN ;


: DO-I  BEGIN X1 @ Y1 @ PLOT X1 INCR X1=X2 UNTIL ;
: DO-II BEGIN X1 @ Y1 @ PLOT X1 DECR X1=X2 UNTIL ;
: DO-J  BEGIN X1 @ Y1 @ PLOT Y1 INCR Y1=Y2 UNTIL ;
: DO-JJ BEGIN X1 @ Y1 @ PLOT Y1 DECR Y1=Y2 UNTIL ;

: IORII?   X1 @ X2 @ < IF DO-I ELSE DO-II THEN ;
: JORJJ?   Y1 @ Y2 @ < IF DO-J ELSE DO-JJ THEN ;

: HOR-OR-VER?   X1 @ X2 @ = IF JORJJ? ELSE IORII? THEN ;

: LINETO        ( x y -- )              \ draw a line to x,y from previous
                                        \ LINETO, LINE or LINEFROM.
                2dup x1 @ y1 @ d=
                if      2drop exit
                then
                Y2 ! X2 ! LINEINIT
                X1 @ X2 @ = Y1 @ Y2 @ = XOR
                IF  HOR-OR-VER?  ELSE  LINE?  THEN
                X1 @ Y1 @ PLOT ;

: NLINE        ( x y -- )              \ draw a line to x,y from previous
                                        \ LINETO, LINE or LINEFROM.
                2dup x1 @ y1 @ d=
                if      2drop exit
                then
                Y2 ! X2 ! LINEINIT
                X1 @ X2 @ = Y1 @ Y2 @ = XOR
                IF  HOR-OR-VER?  ELSE  LINE?  THEN
                X1 @ Y1 @ PLOT ;

: LINEFROM      ( x y -- )              \ set origin of next LINETO.
                Y1 ! X1 ! ;

: MOVETO        ( x y -- )
                Y1 ! X1 ! ;

: LINE          ( x1 y1 x2 y2 -- )
                2SWAP LINEFROM LINETO ;

: VLINE         ( y1 y2 x -- )
                ROT Y1 ! DUP X1 ! SWAP LINETO ;

: HLINE         ( x1 x2 y -- )
                TUCK LINE ;

\ LINE ALGORITHM                                      23Jun88mds

comment:

        LINE ALGORITHM USER'S GUIDE
key in the endpoints of the segment you wish to draw
followed by the word LINE

        example....     1 2 3 4 LINE

a segment with endpoints [1,2] and [3,4] {unscaled} will be drawn.

If you wish to continue drawing from [3,4], simply key in the next
endpoint followed by the word LINETO

        example : to draw two segments from [1,2] to [3,4] to [7,8]
                key in....      1 2 3 4 LINE
                followed by...  7 8 LINETO

The primed ['] procedures draw non-horizontal, non-vertical segments
whose slopes are greater than one, and the corresponding unprimed
procedures draw non-horizontal, non-vertical lines whose slopes are
less than one. the "i" and "j" procedures take care of horizontal and
vertical lines, respectively. The commands: 1/1', 2/2', 3/3', 4/4',
2s-or-3s, 1s-or-4s, line?, iorii?, jorjj?, hor-or-ver? simply
determine which algorithm is to be used. Finally, unless otherwise
noted in the body of the program, commands in the program neither
expect or leave anything on the stack.

comment;

\tcom FORTH TARGET >TARGET


