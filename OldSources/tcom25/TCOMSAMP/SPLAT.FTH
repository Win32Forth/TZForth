\\ SPLAT.SEQ     A simple graphic demo, draws lines on CGA/EGA/VGA or HERCULES
.options /opt /noinit

  Here is an example file that will work on either CGA/EGA/VGA or HERCULES.

        Compile with the following command line:

                TCOM SPLAT <Enter>

  Use the compiled SPLAT.COM program as follows:

        SPLAT /<starting_mode> <optional_password>

  SPLAT then displays a pseudo random series of dots, until the correct
password is entered. Type in the <optional_password> and press
Control-Enter to terminate SPLAT.   If the password is not entered when
SPLAT is started, then a simple ESC key will terminate the program.

  All printable keys typed are accumulated into the password check
buffer, so you may have to press Control-Enter before entering your
password to clear the check buffer before entering your correct password
for verification.

  During graphics display the following keys are active:

        ENTER           select a new graphics mode
        SPACE           restart with same graphics mode
        TAB             increments the erase mode color
        Shift-TAB       decrements the erase mode color
        INSERT          starts auto erase color bump
        ^P              Portrait screen dump to Epson printer
        ^L              Landscape screen dump to epson printer

        Press a key to select a video mode:

1 - 320x200x4   CGA    D - 640x350x256  TSENG    R - 640x400x256  VESA
2 - 640x200x2   CGA    E - 640x480x256  TSENG    S - 640x480x256  VESA
3 - 320x200x16  EGA    F - 800x600x16   TSENG    T - 800x600x16   VESA
4 - 640x200x16  EGA    G - 800x600x256  TSENG    U - 800x600x256  VESA
5 - 640x350x16  EGA    H - 1024x768x16  TSENG    V - 1024x768x16  VESA
6 - 640x480x2   VGA    I - 1024x768x256 TSENG    W - 1024x768x256 VESA
7 - 640x480x16  VGA    J - 640X400X256  VIDEO7   X - 640x480x256  TRIDENT
8 - 320x200x256 VGA    K - 800x600x16   VIDEO7   Y - 800x600x16   TRIDENT
9 - 800x600x16  OAK    L - 800X600X256  VIDEO7   Z - 1024x768x16  TRIDENT
0 - 640x480x256 ATI    M - 1024x768x16  VIDEO7   [ - 1024x768x256 TRIDENT
A - 800x600x16  ATI    N   640x480x256  GENOA    \ - 640x480x256  PARADISE
B   800x600x256 ATI    O   800x600x16   GENOA    ] - 800x600x16   PARADISE
C   1024x768x16 ATI    P   800x600x256  GENOA    ^ - 1024x768x16  PARADISE
                       Q   1024x768x16  GENOA

{

\tcom   needs graph.seq         \ we need color graphics support
\tcom   needs herc.seq         \ we need hercules graphics support

\fpc    needs \tcom\graph.seq
\fpc    needs \tcom\herc.seq

\ \tcom   needs \tcom\tgsdump.seq \ screen dump utility
\ \fpc    needs \tcom\gsdump.seq

create bootsave 0 , 0 ,         \ a place to save the old boot interrupt

label noboot    ( -- )          \ no boot interrupt routine
                push ax
                push ds
                mov ax, # $40
                mov ds, ax
                test $17 # $08 byte
                je 0 $
                test $17 # $04 byte
                je 0 $
                and  $17 # $F3 byte
           0 $: pop ds
                pop ax
                jmp far $F000 $E987     end-code

code set_noboot ( -- )          \ install out reboot interrupt routine
                mov cx, ds
                mov ax, cs
                mov ds, ax
                mov dx, # noboot
                mov ax, # $2509
                int $21
                mov ds, cx
\tcom           ret
\fpc            next
                end-code

code save_boot  ( -- )          \ save the old reboot interrupt handler
                mov dx, bx
                mov cx, es
                MOV AX, # $3509
                INT $21
                MOV bootSAVE BX
                MOV bootSAVE 2+ ES      \ Save old vector
                mov es, cx
                mov bx, dx
\tcom           RET
\fpc            next
                END-CODE

code rest_boot  ( -- )          \ restore the old reboot interrupt handler
                mov cx, ds
                MOV DX, bootSAVE
                MOV DS, bootSAVE 2+
                MOV AX, # $2509
                INT $21
                mov ds, cx
\tcom           ret
\fpc            next
                END-CODE

\ ***************************************************************************
\       Some words to provide a random nubmer generator
\ ***************************************************************************

0 value SEED1
0 value SEED2
0 value SEED3
0 value SEED1A
0 value SEED2A
0 value SEED3A

CODE (RANDOMIZE) ( -- u )       \ a randomizer for the random number generator
\tcom           save_bx
                MOV AH, # 0
                INT 26
\tcom           mov bx, dx
\tcom           ret
\fpc            push dx
\fpc            next
                END-CODE

: RANDOMIZE     ( -- )          \ randomize the random number generator
                (RANDOMIZE)        DUP !> SEED1 !> SEED1A
                (RANDOMIZE) 2* 1-  DUP !> SEED2 !> SEED2A
                (RANDOMIZE) 2/ 1+  DUP !> SEED3 !> SEED3A ;

: RNDSWAP       ( -- )          \ exchange the random seed set
                   SEED1     SEED2     SEED3
                   SEED1A    SEED2A    SEED3A
                !> SEED3  !> SEED2  !> SEED1
                !> SEED3A !> SEED2A !> SEED1A ;

: RND           ( n1 -- n2 )    \ generate a random number in the range
                                \ 0 to n1-1
                DUP 0= ?EXIT
                SEED1 177 /MOD  2*    SWAP  171 *  SWAP  - DUP  !> SEED1
                SEED2 176 /MOD  35 *  SWAP  172 *  SWAP  - DUP  !> SEED2
                SEED3 178 /MOD  63 *  SWAP  170 *  SWAP  - DUP  !> SEED3
                +  +  SWAP MOD ;

 0 value lastx
 0 value lasty
 0 value lastxa
 0 value lastya
 0 value pcnt
 0 value erasecolor
-1 value drawing
256 array password              \ buffer for password
256 array passcheck             \ buffer for typed in password

0 value auto_erase              \ automatically bump erase color flag
0 value autocnt
0 value speckle
0 value start_key
0 value ?snake

: draw1         ( -- )          \ draw one dot on the screen
                lasty       0< if vdots         +!> lasty then
                lasty vdots >= if vdots negate  +!> lasty then
                lastx       0< if hdots         +!> lastx then
                lastx hdots >= if hdots negate  +!> lastx then
                lastx lasty plot
                drawing                         \ if drawing, pick color
                speckle and                     \ and speckle is on
                if      #colors rnd color !
                then
                3 rnd 1- +!> lastx              \ pick next location to plot
                3 rnd 1- +!> lasty
                incr> pcnt                      \ bump plot counter
                pcnt 0=                 \ if 65k dots, toggle draw/erase mode
                if      drawing dup 0= !> drawing
                        if      erasecolor #colors 1- and color !
                        then
                else    auto_erase
                        if      pcnt autocnt 1- and 0=
                                if      incr> erasecolor
                                        erasecolor #colors 1- and color !
                                then
                        then
                then    ;

: swap_points   ( -- )
                   lastx     lasty
                   lastxa    lastya
                !> lasty  !> lastx
                !> lastya !> lastxa ;

: erase1        ( -- )
                ?snake 0= ?exit
                pcnt 500 u>
                if      rndswap
                        swap_points
                        drawing speckle and
                        if      #colors rnd drop
                        then
                        false save!> drawing
                        erasecolor save!> color
                        draw1
                        restore> color
                        restore> drawing
                        swap_points
                        rndswap
                then    ;

: bump_erasecolor ( -- )        \ use the next erase color
                incr> erasecolor
                on> drawing
                off> auto_erase
                -1 !> pcnt ;

: -bump_erasecolor ( -- )        \ use the previous erase color
                decr> erasecolor
                on> drawing
                off> auto_erase
                -1 !> pcnt ;

: auto_erasecolor ( -- )        \ automatically bump erase color periodically
                on> auto_erase
                off> drawing ;

: .spinfo       ( -- )          \ display an information screen
                text-mode cls 0 0 at
cr ."  SPLAT is a public domain program."
cr
cr ."      SPLAT is a combination screen saver (destroyer) and password protection"
cr ."   program. When invoked without a password following, it may be terminated"
cr ."   by pressing the ESC key. If you startup with a password as in:
cr
cr ."            SPLAT </starting_mode> <password> <enter>
cr
cr ."      Then you can only get out of SPLAT by entering the password followed by"
cr ."   Control-Enter."
cr
cr ."      Press Enter while in the graphics mode to select a new graphics mode."
cr
cr ."      SPLAT was written by Tom Zimmer using TCOM, a public domain optimizing"
cr ."   Forth compiler for the 80x86 family of processors. Other target processors"
cr ."   are available. Password protection was suggested by Steve Toh."
cr
cr ."      SPLAT, TCOM and F-PC Forth are available for a $60 donation from:
cr
cr ."           Tom Zimmer                      Please specify 5 1/4 HD or 3.5 HD"
cr ."           292 Falcato Drive               Hm (408) 263-8859"
cr ."           Milpitas, CA. 95035             Wk (415) 327-8800"
cr ;

: exit_check    ( -- )          \ check for correct password entered
                password passcheck
                over c@ 1+ caps-comp 0=
                if      rest_boot
                        .spinfo
\tcom                   bye
\fpc                    fast quit
                then    passcheck off ;

0 value vmode#          \ the current graphics mode number value

: do_vmode      ( -- )  \ select the proper graphics mode as specified
                ?vmode 7 = ?exit
                vmode# dup 0 39 between 0= ?exit
                exec:
                640x480x256_ATI         \ 0
                320x200x4               \ 1 - CGA
                640x200x2               \ 2 - CGA
                320x200x16              \ 3 - EGA,VGA
                640x200x16              \ 4 - EGA,VGA
                640x350x16              \ 5 - EGA,VGA
                640x480x2               \ 6 - EGA,VGA
                640x480x16              \ 7 - VGA
                320x200x256             \ 8 - VGA
                800x600x16_OAK          \ 9
                800x600x16_ATI          \ A
                800x600x256_ATI         \ B
                1024x768x16_ATI         \ C
                640x350x256_TSENG       \ D
                640x480x256_TSENG       \ E
                800x600x16_TSENG        \ F
                800x600x256_TSENG       \ G
                1024x768x16_TSENG       \ H
                1024x768x256_TSENG      \ I
                640x400x256_VIDEO7      \ J
                800x600x16_VIDEO7       \ K
                800x600x256_VIDEO7      \ L
                1024x768x16_VIDEO7      \ M
                640x480x256_GENOA       \ N
                800x600x16_GENOA        \ O
                800x600x256_GENOA       \ P
                1024x768x16_GENOA       \ Q
                640x400x256_VESA        \ R
                640x480x256_VESA        \ S
                800x600x16_VESA         \ T
                800x600x256_VESA        \ U
                1024x768x16_VESA        \ V
                1024x768x256_VESA       \ W
                640x480x256_TRIDENT     \ X
                800x600x16_TRIDENT      \ Y
                1024x768x16_TRIDENT     \ Z
                1024x768x256_TRIDENT    \ [
                640x480x256_PARADISE    \ \
                800x600x16_PARADISE     \ ]
                1024x768x16_PARADISE    \ ^
                ;

: video_restart ( -- )          \ select the next graphics mode in list
                do_vmode                        \ select that mode
                hdots 2/ !> lastx               \ recenter plot point
                vdots 2/ !> lasty
                lastx !> lastxa
                lasty !> lastya
                seed1 !> seed1a
                seed2 !> seed2a
                seed3 !> seed3a
                off> pcnt                       \ reset plot counter
                on> drawing  ;                  \ turn on drawing

: set_video_mode ( c1 -- )
                dup     '0' '9' between
                if      dup '0' - !> vmode#             \ set the mode 0 - 9
                then
                dup upc 'A' '^' between
                if      dup upc 'A' - 10 + !> vmode#    \ 10 - 39
                then    video_restart ;                 \ ( -- c1 )
                                                        \ return a key

: .help_key     ( -- c1 )
                cr
                cr ."  During graphics display the following keys are active:"
                cr ."    ENTER   select a new graphics mode         TAB        incr erase mode color"
                cr ."    SPACE   restart with same graphics mode    Shift-TAB  decr erase mode color"
                cr ."    INSERT  starts auto erase color bump       DEL        snake eraser toggle"
                cr ."    ^Portrait Print, ^Landscape Print (Epson)  +/-        +/- erase color size"
                cr ."  Press a key to select a video mode:"
                cr ."  ****** WARNING, USING AN INCORRECT VIDEO MODE CAN DAMAGE YOUR MONITOR ******"
cr ."   1 - 320x200x4   CGA    D - 640x350x256  TSENG    R - 640x400x256  VESA"
cr ."   2 - 640x200x2   CGA    E - 640x480x256  TSENG    S - 640x480x256  VESA"
cr ."   3 - 320x200x16  EGA    F - 800x600x16   TSENG    T - 800x600x16   VESA"
cr ."   4 - 640x200x16  EGA    G - 800x600x256  TSENG    U - 800x600x256  VESA"
cr ."   5 - 640x350x16  EGA    H - 1024x768x16  TSENG    V - 1024x768x16  VESA"
cr ."   6 - 640x480x2   VGA    I - 1024x768x256 TSENG    W - 1024x768x256 VESA"
cr ."   7 - 640x480x16  VGA    J - 640X400X256  VIDEO7   X - 640x480x256  TRIDENT"
cr ."   8 - 320x200x256 VGA    K - 800x600x16   VIDEO7   Y - 800x600x16   TRIDENT"
cr ."   9 - 800x600x16  OAK    L - 800X600X256  VIDEO7   Z - 1024x768x16  TRIDENT"
cr ."   0 - 640x480x256 ATI    M - 1024x768x16  VIDEO7   [ - 1024x768x256 TRIDENT"
cr ."   A - 800x600x16  ATI    N   640x480x256  GENOA    \ - 640x480x256  PARADISE"
cr ."   B   800x600x256 ATI    O   800x600x16   GENOA    ] - 800x600x16   PARADISE"
cr ."   C   1024x768x16 ATI    P   800x600x256  GENOA    ^ - 1024x768x16  PARADISE"
cr ."                          Q   1024x768x16  GENOA    "
                key
cr ." !! Graphics mode selected, if you see this message, press Enter and try again !"
                set_video_mode ;

: exit_nopass   ( -- )          \ leave if no password was entered, or
                                \ if it was, then bump to next graphics mode
                .spinfo
                password c@ 0=
                if      rest_boot
\tcom                   bye
\fpc                    fast quit
                else
cr ." !! ENTERED WITH PASSWORD !! Type in the password and press Enter: "
                        query bl word count passcheck place
                        exit_check              \ correct password entered?
                        video_restart           \ if not, start over
                then    passcheck off ;         \ in any case, clear pass buf

: set_vmode     ( -- )  \ select the proper graphics mode as specified
                text-mode cls 0 0 at
                password c@
                if      ."   Press any key to continue, then,"
                        cr ."   Type in your PASSWORD and press Control-Enter to exit. "
                        .help_key drop
                else    ."   Press ESC to quit, or Enter to continue. "
                        .help_key $1B = if exit_nopass then
                then    passcheck off ;

: ?keycheck     ( -- )          \ did we see a key press?
                pcnt 31 and ?exit
                key? 0= ?exit
                key
                case
( linefeed )            $0A of  exit_check                      endof
( carraige return )     $0D of  set_vmode                       endof
( escape )              $1B of  exit_nopass                     endof
( space )               $20 of  video_restart                   endof
( tab )                 $09 of  bump_erasecolor                 endof
( shift tab )           $8F of  -bump_erasecolor                endof
( insert )              $D2 of  auto_erasecolor on> speckle     endof
( Del )                 $D3 of  ?snake 0= !> ?snake             endof
                        '+' of  autocnt $4000 umin dup + !> autocnt
                                auto_erasecolor off> speckle    endof
                        '-' of  autocnt u2/       1 umax !> autocnt
                                auto_erasecolor off> speckle    endof
\                        ^P  of  portrait-dump                   endof
\                        ^L  of  landscape-dump                  endof
( accumulated others )          passcheck count + c!
                                1 passcheck c+!
                endcase ;

: get_password  ( -- )          \ get and verify the password
                                \ password must be printable characters
                bl word count password place    \ install password
                password count bounds
                ?do     i c@ $21 $7E between 0= abort" Invalid password"
                                \ abort if any password characters
                                \ aren't in the set of printable characters
                loop    ;

: get_vmode     ( -- )
                off> start_key
                >in @ bl word 1+ c@ '/' =
                if      drop here 2+ c@ !> start_key
                else    >in !
                then    ;

: splat         ( -- )          \ main program entry point
\tcom           CAPS ON                         \ ignore cAsE
\tcom           ?DS: SSEG !                     \ init search segment
\tcom           DOSIO_INIT                      \ init EMIT, TYPE & SPACES
\tcom           $FFF0 SET_MEMORY                \ default to 64k code space
\tcom           DOS_TO_TIB                      \ move command tail to TIB
\tcom           COMSPEC_INIT                    \ init command specification
\fpc            slow
                get_vmode                       \ get the video mode
                get_password                    \ get cmdline password
                ?vmode 7 <>                     \ select color or herc graph
                if      320x200x4               \ if color, use low res
                        1 !> vmode#             \ defautl to a CGA mode
                else    hercules                \ else use hercules graphics
                then    2 color !               \ start with color 2
                hdots 2/ !> lastx               \ center plot point
                vdots 2/ !> lasty
                1024 !> autocnt                 \ set auto count to 1k
                on> speckle
                randomize                       \ randomize generator
                save_boot                       \ save reboot int
                set_noboot                      \ install out reboot int
                start_key ?dup
                if      set_video_mode
                then
                begin   draw1                   \ loop, drawing for ever
                        erase1
                        ?keycheck               \ till user terminates
                again   ;

}

