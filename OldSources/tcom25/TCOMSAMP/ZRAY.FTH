\\ ZRAY.SEQ                 Memory display TSR              by Tom Zimmer

  An example of how to make a relatively simple terminate and stay
resident program using TCOM.  This TSR opens a window on memory, and
allows you to browse any segment or address in the lower 1 meg of memory.

  The Ctrl & Alt keys together are detected by looking at low memory
location 0000:0417h and testing the $0A weight bits.

  Other keys like LEFT SHIFT, RIGHT SHIFT, CONTROL, NUMBER LOCK or
CAPS LOCK can be detected by looking at other bits of the same location.

  Keys that generate characters can be detected by looking into the
keyboard buffer.  If a character generating key is used, then it should
be removed from the keyboard buffer with "KEY DROP" at the start of your
program in TSR-MAIN.

NOTE:   Some invocations of the hot key will be ignored if you are at the
        DOS commandline level, because DOS spends much of its time in DOS,
        which leaves the "inDOS" variable with a non-zero value.  The TSR
        ignores any keypresses when "inDOS" isn non-zero.

                .options /opt /noinit   \ compiler options
{

\ **********************************************************************
\ Some CODE memory resident variables needed by the interrupt 9 handler
\ **********************************************************************

$00EC constant inDOS            \ DOS variable pointer, 4 bytes as offset,seg
$00F0 constant sssave           \ save stack segment
$00F2 constant spsave           \ save stack pointer
$00F4 constant tsrsi            \ save the tsr SI reg
$00F6 constant tsrsp            \ save the tsr SP reg
$00F8 constant tsrds            \ save the tsr DS reg
$00FA constant inting           \ are we in the middle of an int9?
$00FC constant int9save         \ The last 4 bytes before code starts is used
                                \ to preserve the original INT 9h contents.

\ **********************************************************************
\ A routine to save and restore all registers when calling TSR-MAIN
\ **********************************************************************

label do-tsr    ( -- )
                push ax                         \ save all registers
                push ds         push es
                push di         push si
                push bx         push cx
                push dx
                push bp
                mov cs: spsave sp               \ save the stack pointer
                mov cs: sssave ss               \ save the stack segment
                mov ds, cs: tsrds               \     load the DS reg
                mov ss, cs: tsrds               \ and load the SS reg
                mov sp, cs: tsrsp               \ and load the SP reg
                mov si, cs: tsrsi               \ and load the SI reg
                mov bp, # 0                     \ BP should always be zero
                call TSR-MAIN                   \ OUR PROGRAM
                mov ss, cs: sssave              \ restore the stack segment
                mov sp, cs: spsave              \ restore the stack pointer
                pop bp                          \ restore all registers
                pop dx
                pop cx          pop bx
                pop si          pop di
                pop es          pop ds
                pop ax
                ret     end-code

\ **********************************************************************
\ The following string needs to be unique for each TSR you write!
\ **********************************************************************

HERE-T constant check-string
HERE-T ,"-T ZRAY MEMORY DUMP AND MONITOR PROGRAM" ,-T   \ MUST BE UNIQUE!

\ **********************************************************************
\ WARNING: THE ABOVE STRING MUST PRECEED THE INT9 HANDLER DIRECTLY, SO
\          THE CHECK FOR RESIDENCY WILL WORK PROPERLY!!!!!!!!!!!!!!!!!!
\ **********************************************************************

\ **********************************************************************
\ Here is the interrupt 9 handler code, it is invoked on each key press.
\ **********************************************************************

label int9      ( -- )          \ the TSR's interrupt 9 handler
                pushf
                cmp cs: inting # $A55A word     \ if already doing INT9
                je 1 $                          \ then branch to old INT9
                push ds                         \ save regs we will use
                push bx
                mov ds, cs: inDOS 2+            \ get seg:off of inDOS var
                mov bx, cs: inDOS
                cmp 0 [bx], # 0 byte            \ is inDOS variable zero?
                pop bx                          \ restore used registers
                pop ds
                jne 1 $                         \ if not go normal INT9
                mov cs: inting # $A55A word     \ mark as already in INT9
                popf
                int 09h                         \ recursively do INT9
                pushf                           \ save flags
                sti                             \ re-enable interrupts
                CALL DO-TSR                     \ call our TSR
                mov cs: inting # 0 word         \ clear the key test flag
                popf                            \ restore processor status
                iret                            \ return from interrupt
        1 $:    popf
                jmp far cs: [] int9save         \ jump to normal int9
                end-code

code save_int9  ( -- ) \ save the current contents of interrupt 9
                push es
                push bx
                mov ax, # $3509                 \ get interrupt vector 9
                int $21
                mov cs: int9save bx             \ special, in CS not DS
                mov cs: int9save 2+ es
                pop bx
                pop es
                ret     end-code

code set_int9   ( -- )  \ set interrupt 9 to our interrupt handler
                push es
                push ds
                push bx
                mov ax, cs
                mov ds, ax
                mov dx, # int9                  \ our interrupt vector address
                mov ax, # $2509                 \ set interrupt vector 9
                int $21
                pop bx
                pop ds
                pop es
                ret     end-code

code unhook_far_int9 ( -- )  \ restore interrupt 9 of far function
                push bx
                push ds
                mov ds, cs: int9save 2+
                mov dx,     int9save            \ far away address to restore
                mov ds,     int9save 2+
                mov ax, # $2509                 \ restore interrupt vector 9
                int $21
                pop ds
                pop bx
                ret     end-code

code set_inDOS  ( -- )  \ get the address of the "Are we in DOS?" variable
                save_bx
                push es
                mov ah, # 34h
                int 21h
                mov cs: inDOS 2+ es     \ save the pointer in my inDOS var
                mov cs: inDOS    bx
                pop es
                load_bx
                ret     end-code

code term&stay  ( n1 -- )               \ terminate and stay resident
                                        \ reserve n1 paragraphs for program
                mov dx, bx              \ move BX (top of stack) to DX
                mov ax, # $3100         \ func 31, return code 0
                int $21
                ret     end-code        \ never gets here I hope

: ?already_loaded ( -- )        \ check to see if we have already
                save> sseg      \ loaded this TSR into memory
                ?cs: check-string countl pad placel
                ?cs: int9save 2+ @L dup sseg !          \ set the segment
                ?cs: int9save    @L 2- @L >r            \ the offset
                pad r> over c@ 1+ comp 0=
                restore> sseg ;

: ?already_loaded_abort ( -- )          \ check to see if we have already
                ?already_loaded
        abort" ZRAY already loaded, 'Ctrl & Alt' opens, or ZRAY /R releases." ;

: ?/remove      ( -</r>- )              \ test for removing the TSR
                bl word ?uppercase 1+ " /R" comp 0=
                if      ?already_loaded 0=                     \ is it here?
                        abort" TSR not in memory!"             \ must be here
                        unhook_far_int9                        \ unhook int9
                        ?cs: int9save 2+ @L 44 @L dealloc      \ rel environ
                        ?cs: int9save 2+ @L       dealloc or   \ rel code
                        abort" Error releasing memory!"        \ error?
                        ." TSR memory Released!"               \ or all done
                        bye                                    \ terminate
                then    ;

\ **********************************************************************
\ **************** USERS APPLICATION WORDS START HERE ******************
\ **********************************************************************

\ Move video page zero to page one to save it and back to restore it.

: tsrsavescr    ( -- )  \ save the current text screen in a buffer
                video-seg @    0 over 4000 4000 cmovel ;

: tsrrestscr    ( -- )  \ retore the current text screen from a buffer
                video-seg @ 4000 over 0    4000 cmovel ;

\ **********************************************************************
\ TSR-MAIN is invoked on every keystroke, it can look at anything in DOS
\ memory, BUT, must leave the stacks unmodified on exit.
\ **********************************************************************

: ?keyboard     ( -- f1 )
                0 $41A c@L 0 $41C c@L - ;

0 value ?interrupted

: <zbox>        ( left top right bottom filled --- )
                =: fbx
                rows 1- min =: by
                cols 1- min =: bx
                =: ty =: tx
                tx ty at boxchars 1 TYPE        \ top left corner
                boxchars 1+ c@ bl <>
                if      boxchars 1+             \ top line character
                        bx tx - 1- 0MAX 0
                       ?do      dup 1 TYPE      \ top side of box
                        loop    drop
                else    bx ty at
                then
                boxchars 2+ 1 TYPE              \ top right corner
                tx by at
                boxchars 5 + 1 TYPE             \ bottom left corner
                boxchars 6 +
                bx tx - 1- 0MAX 0
               ?do      dup 1 TYPE              \ bottom side of box
                loop    drop
                boxchars 7 + 1 TYPE             \ bottom right corner
                boxchars 3 +                    \ left and right box chars
                by ty 1+ over min
[long]         ?do      tx i at dup 1 TYPE      \ left side of box
                        fbx                     \ fill the box?
                        if      bx tx - 1- spaces
                        then
                        bx i at dup 1+ 1 TYPE   \ right side of box
                        ?keyboard dup !> ?interrupted ?leave
                loop    drop
                tx 1+ ty 1+ dup =: bline at ;

: >ray          ( --- )
                " зд©ЁЁюды" drop !> boxchars ;

: zraybox&fill   ( left top right bottom --- )
                >ray true <zbox> ;

0 value dseg
0 value doff
0 value helptgl
3 value topline
4 value wheight

: set-start     ( -- )
                cursor-on
                save> base hex
                1 topline at 78 sp>col
                3 topline at ." New HEX address 'SEG OFF': " query
                esc_flg @ 0=            \ not canceled
                span @ 0> and           \ and user entered something
                if      bl word ?uppercase number? nip
                        if      !> dseg
                                bl word ?uppercase number? nip
                                if      !> doff
                                else    drop
                                        here c@ if beep then
                                then
                        else    drop beep
                        then
                then
                restore> base
                cursor-off ;

: .help         ( -- )
                2 topline wheight + 1+ at
                helptgl
if
." **** PgUp    PgDn,  ESC=Exit,  Enter=Set new address,  F1=more help **** "
else
." **** ^PgUp ^PgDn, -=Move window, ^-^=Resize window,  F1=more help **** "
then            ;

: draw_border   ( -- )
                0 topline 1- 78 topline wheight + 2+ zraybox&fill
                .help ;

: screen_line   ( n1 -- )       \ move up or down screen lines n1
                tsrrestscr
                topline + 1 max rows 3 - wheight - min !> topline
                draw_border
                ;

: win_height    ( n1 -- )       \ adjust height up or down lines n1
                dup 0<
                if      tsrrestscr
                then
                wheight + 1 max 21 min !> wheight
                topline rows 3 - wheight - min !> topline
                draw_border
                ;

: help_toggle   ( -- )
                helptgl 0= !> helptgl
                .help ;

: zray          ( -- )
                ?vmode                                  \ get the video mode
                dup  7 =                                \ allow MONO
                over 2 = or                             \ or    COLOR 2
                over 3 = or 0=                          \ or    COLOR 3 ONLY
                if      drop beep EXIT                  \ else beep & exit
                then    7 =                             \ if MONO?
                if      $B000                           \ use mono buffer
                else    $B800                           \ else use color buff
                then    video-seg !                     \ so TSRSAVESCR works
                at? 2dup 2>r at                         \ resync cursor pos
                savecursor cursor-on norm-cursor        \ save/set cursor
                tsrsavescr cursor-off                   \ save screen
                draw_border
                begin   ?interrupted
                        if      off> ?interrupted
                                draw_border
                        then     2 topline at ." Segment: " dseg h. 78 sp>col
                                25 topline at ."  ZRAY a Memory Monitor Program "
                        begin   1 topline 1+
                                dseg doff wheight 16 * 0
                                DO      2swap 2dup at 1+ 2swap
                                        DUMP_1LINE
                                        ?keyboard ?leave
                            16 +LOOP    2DROP 2drop
\                               3 0 do ?keyboard ?leave 1 tenths loop
                                ?keyboard
                        until   key
( Escape )              case     27 of                          true    endof
( Enter )                        13 of  set-start               false   endof
( Up   )                        200 of  -16 +!> doff            false   endof
( Down )                        208 of   16 +!> doff            false   endof
( PgUp )                        201 of  -64 +!> doff            false   endof
( PgDn )                        209 of   64 +!> doff            false   endof
( ^PgUp )                       132 of  -16 +!> dseg            false   endof
( ^PgDn )                       246 of   16 +!> dseg            false   endof
( left arrow )                  203 of  -1 screen_line          false   endof
( right arrow )                 205 of   1 screen_line          false   endof
( control left arrow )          243 of  -1 win_height           false   endof
( control right arrow )         244 of   1 win_height           false   endof
( F1 )                          187 of  help_toggle             false   endof
                                        drop false
                        endcase
                        begin ?keyboard while key drop repeat   \ empty kbd
                until
                tsrrestscr                                      \ restore screen
                restcursor                                      \ restore cursor loc
                2r> at ;

}       Bit assignments for memory location "0 $417":

        BIT         KEY                         TEST SEQUENCE
        $01     right Shift             0 $417 C@L $01 AND $01 <> ?EXIT
        $02     left Shift              0 $417 C@L $02 AND $02 <> ?EXIT
        $04     Ctrl                    0 $417 C@L $04 AND $04 <> ?EXIT
        $08     Alt                     0 $417 C@L $08 AND $08 <> ?EXIT
        $10     Scroll Lock toggle      0 $417 C@L $10 AND $10 <> ?EXIT
        $20     Number Lock             0 $417 C@L $20 AND $20 <> ?EXIT
        $40     Caps Lock               0 $417 C@L $40 AND $40 <> ?EXIT
        $80     Insert toggle           0 $417 C@L $80 AND $80 <> ?EXIT
        $06     Control & Left Shift    0 $417 C@L $06 AND $06 <> ?EXIT
        $0A     Left Shift & Alt        0 $417 C@L $0A AND $0A <> ?EXIT
        $0C     Ctrl & Alt              0 $417 C@L $0C AND $0C <> ?EXIT
        $0E     Left & Right Shift      0 $417 C@L $0E AND $0E <> ?EXIT

{

: TSR-MAIN      ( -- )  \ the MAIN for this TSR, must be named TSR-MAIN
                0 $417 c@L $0C and $0C <> ?exit         \ Ctrl & Alt
\                0 $417 C@L $10 and 0= ?EXIT             \ SCROLL LOCK pressed?
\                0 $417 c@L $EF and 0 $417 c!L           \ clear scroll lock
                zray
\                0 $417 c@L $EF and 0 $417 c!L           \ clear scroll lock
                ;

: .zray         ( -- )
                   ."   Usage:  ZRAY <option> <enter>"
cr ." Options:  /I      Install as memory resident,  Use Ctrl & Alt to POPUP."
cr ."           /R      Remove from memory" ;

: ?/install     ( -</i>- )     \ are we installing?
                ?already_loaded ?exit
                >in @ >r
                bl word ?uppercase 1+ " /I" comp \ if not then just run it
                if      zray
                        .zray
                        bye                                    \ terminate
                then    r> >in ! ;

\ **********************************************************************
\ TSR_INIT contains whatever portion of DEFINIT.SEQ is needed by your
\ application.
\ **********************************************************************

: TSR_INIT      ( -- )  \ perform whatever TCOM initialization is needed
                CAPS ON                         \ ignore cAsE
                INIT-CURSOR                     \ get intial cursor shape
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                0 SET_MEMORY                    \ default to min code space
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT ;                  \ init command specification

\ **********************************************************************
\ INIT-TSR initializes the application to run, saves and sets interrupt
\ vector 9, test to make sure we haven't already loaded this TSR and
\ invokes a DOS shell to make it easy for the user to unmount this TSR
\ by just typing EXIT at the DOS commandline.
\ **********************************************************************

: INIT-TSR      ( -- )  \ entry point, initializes, and shells to DOS
                tsr_init                        \ initialize TCOM application
                save_int9                       \ save current INT9 vector
                ?/install                       \ are we installing
                ?/remove                        \ are we removing the TSR?
                ?already_loaded_abort           \ check for already resident
                set_inDOS                       \ set the in DOS var pointer
                set_int9                        \ set INT9 to out handler
                ?ds:     ?cs: tsrds !L          \ init DS for tsr
                rp@ 32 - ?cs: tsrsp !L          \ init RP for tsr
                sp@ 20 - ?cs: tsrsi !L          \ init SP for tsr
   ." Press  'Ctrl & Alt'  to POPUP."
cr ." Type  ZRAY /R  at the DOS prompt to remove the TSR from resident memory."
                ?ds: ?cs: -             \ CODE space paragraphs needed
                memend @ paragraph +    \ DATA space paragraphs needed
                term&stay ;             \ terminate with needed paragraphs


