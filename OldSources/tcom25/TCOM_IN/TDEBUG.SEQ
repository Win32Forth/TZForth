\\ CODEBUG.SEQ          A CODE debugger for F-PC        by Tom Zimmer

  This file contains a simple debugger for F-PC to allow debugging
CODE routines. Don't expect TOO MUCH from this debugger, it is still
in quite primitive form. It is useful though.

  The debugger can be invoked directly by:

        TRACE <forth_name> <enter>

  Each subsequent enter key press causes the debugger to step one
instruction through <forth_name>. Limited operations are supported while
in the debugger, read the screen while debugging and press F1 for some help.

  To set a break point that will invoke the debugger when a particular
word is executed, use:

        BREAKAT <forth_name> <enter>

  The first time this word is executed, the code debugger will be started.
If your break point is not ever executed, you should execute UNBREAK
before leaving F-PC to remove the break point from memory.

 ***************************************************************************

  To make a debugger for CODE, we needed to make an interrupt handler for
INT 1, and then enable the single step status flag bit TF.

{

\ **************************************************************************
\ variables to hold all needed registers
\ **************************************************************************

variable debugip
variable debugcs
variable debugflags
variable debugax
variable debugbx        variable forthbx
variable debugcx
variable debugdx
variable debugbp        variable forthbp
variable debugsi        variable forthsi
variable debugdi        variable forthdi
variable debuges        variable forthes
variable debugss        variable forthss
variable debugsp        variable forthsp
variable debugds        variable forthds

\ **************************************************************************
\ words to allow setting the debugging registers
\ **************************************************************************

:: reg!         ( a1 | <name> -- )      \ defining word to make register
                                        \ assignment words
                create , does> @ ! ;

debugcs    reg! =cs
debugip    reg! =ip
debugss    reg! =ss
debugsp    reg! =sp
debugds    reg! =ds
debuges    reg! =es
debugax    reg! =ax
debugbx    reg! =bx
debugcx    reg! =cx
debugdx    reg! =dx
debugsi    reg! =si
debugdi    reg! =di
debugbp    reg! =bp
debugflags reg! =fl

:: reg@         ( a1 | <name> -- )      \ defining word to make register
                                        \ fetch words
                create , does> @ @ ;

debugcs reg@ cs-@
debugip reg@ ip-@
debugss reg@ ss-@
debugsp reg@ sp-@
debugds reg@ ds-@
debuges reg@ es-@
debugax reg@ ax-@
debugbx reg@ bx-@
debugcx reg@ cx-@
debugdx reg@ dx-@
debugsi reg@ si-@
debugdi reg@ di-@
debugbp reg@ bp-@

\ **************************************************************************
\ Some handy debugging utilities
\ **************************************************************************

2               constant dbtop
rows 6 -        constant dbbot
0               value    dboff
0               value    dbto
0               value    dobreak
0               value    dbsave
0               value    keysave
0               value    spsave

: h.4           ( n1 -- )       \ display n1 in four digit hex
                $10 save!> base
                0 <# # # # # #> space type space
                restore> base ;

: sp>col        ( n1 -- )
                #out @ - 0max spaces ;

: dbeeol        ( -- )
                58 sp>col ;

: ?.cfa         ( a1 -- )
                >symbol
                if      count type
                else    drop
                then ;

: debug_depth   ( -- n1 )
                si-@ sp0 @ swap - 2/ 1- ;

: %debug.s      ( .. n1 -- )
                dup ."  [" 1 .r ." ]" 0 swap 8 min 1-
                do      sp@ si-@ swap - 2/ i + pick
                        7 u.r space
            -1 +loop    ;

: debug.s       ( -- )
                savecursor cursor-off
                0 dbtop cols 1- dbtop 2+ box
                debug_depth 0<
                if      ."   Data Stack INVALID !! "
                        cols 2- sp>col >norm
                else    debug_depth ?dup
                        if      %debug.s
                        else    ."  Stack Empty. "
                        then    cols 1- sp>col
                then    restcursor ;

: .dbheader     ( -- )
                0 dbtop 2- at
                ."  Enter or Space  = single step instruction
                ."  ESC  = Quit debugging  F1  = Help "
                cr
                ."  Use  to select line to (G)o to. "
                ."  Press (R) to change registers. " ;

: .dbfooter     ( -- )
                0 dbbot 1+ at
                ."  Debugger terminated, type `STEPS` to restart. "
                cols sp>col >norm cr ;

\ **************************************************************************
\ Display current instruction followed by data stack
\ **************************************************************************

0 value ipprev
0 value ipprev2

: .instruction  ( -- )          \ display one instruction
                save> base hex
                ip-@ ?.cfa 8 sp>col ."  >> "
                cs-@ !> ?disseg:
                ip-@ dup !> cptr =: ipprev
                inst dbeeol
                restore> base ;

: .ninst        ( n1 -- )
                save> base hex
                cptr ?.cfa 8 sp>col
                1+ dboff =
                if      cptr =: dbto
                        ."  ** "
                else    ."     "
                then
                inst dbeeol
                restore> base ;

: .pinst        ( -- )
                ipprev 0=
                if      dbeeol exit
                then
                save> base hex
                cs-@ !> ?disseg:
                ipprev dup !> cptr =: ipprev2
                cptr ?.cfa 12 sp>col
                inst dbeeol
                restore> base ;

\ **************************************************************************
\ Display the processor registers
\ **************************************************************************

: .regs         ( -- )
                key? ?exit
                savecursor cursor-off
                60 dbtop 3 + 79 dbtop 17 + box
                ."   Tom's Debugger " bcr 17 spaces bcr
                ."  CS" cs-@ h.4 ."  IP" ip-@ h.4   bcr
                ."  DS" ds-@ h.4 ."  SI" si-@ h.4   bcr
                ."  ES" es-@ h.4 ."  DI" di-@ h.4   bcr
                ."  SS" ss-@ h.4 ."  SP" sp-@ h.4   bcr
                        ."           BP" bp-@ h.4   bcr
                ."  AX" ax-@ h.4 09 SPACES          bcr
                ."  BX" bx-@ h.4 ."  FL" debugflags @ h.4
                                                    bcr
                ."  CX" cx-@ h.4 09 SPACES          bcr
                ."  DX" dx-@ h.4 09 SPACES          bcr
                ."  ----ODITsz-a-p-c"               bcr
                2 save!> base
                space
                debugflags @ 0 <# 16 0 do # loop #> type
                restore> base
                restcursor ;

\ **************************************************************************
\ This is the single step "receiver". It saves the debugging registers
\ and restores F-PC's registers then goes back to Forth.
\ **************************************************************************

label int1      ( -- )          \ preserve all registers
                push ds
                push ax
                mov ax, cs: $00FE       \ we hide DS value here at startup
                mov ds, ax
                pop debugax
                pop debugds
                pop debugip
                pop debugcs
                pop ax
                and ax, # $FEFF         \ clear TF flag bit
                mov debugflags ax
                mov debugbx bx  mov bx, forthbx
                mov debugcx cx
                mov debugdx dx
                mov debugbp bp  mov bp, forthbp
                mov debugsi si  mov si, forthsi
                mov debugdi di  mov di, forthdi
                mov debuges es  mov es, forthes
                mov debugss ss  mov ss, forthss
                mov debugsp sp  mov sp, forthsp
                ret     end-code

\ **************************************************************************
\ Routines to save, set & restore the number one & three interrupt vectors.
\ **************************************************************************

2variable int1save               \ a place to save the interrupt one vector

code save_int#  ( n1 --- )      \ save the current contents of interrupt one
                push es
                mov ax, # $3500
                or al, bl
                int $21
                mov int1save bx
                mov int1save 2+ es       \ save old vector
                pop es
                ret     end-code

code set_int#   ( n1 --- )      \ set interrupt one to our interrupt handler
                push es
                push ds
                mov ax, cs
                mov ds, ax
                mov dx, # int1
                mov ax, # $2500
                or al, bl
                int $21
                pop ds
                pop es
                ret     end-code

code rest_int#  ( n1 --- )      \ restore the contents of interrupt one
                push ds
                mov dx, int1save
                mov ds, int1save 2+
                mov ax, # $2500
                or al, bl
                int $21
                pop ds
                ret     end-code

\ **************************************************************************
\ initiate one single instruction step. Swaps registers, sets up the
\ hardware stack with processor status, code segment, and instruction
\ pointer then does an IRET to return to do a single step. The TF flag
\ is set in the status register to make the processor immediately perform
\ an INT1 after a single instruction has been executed. Execution then
\ returns to INT1 above, and consequently back to Forth.
\ **************************************************************************

code one_step   ( -- )          \ single step through one instruction as
                                \ already setup in the debugging recisters
                mov forthsp sp
                mov forthss ss
                mov forthbp bp
                mov forthbx bx
                mov forthsi si
                mov forthdi di
                mov forthds ds
                mov forthes es
                cmp debugsp # 0         \ give a default if needed.
             0= if      mov debugsp sp
                        mov debugss ss
                        mov debugds ds
                        mov debugcs cs
                        pushf
                        pop ax
                        and ax, # $FEFF         \ clear TF flag bit
                        mov debugflags ax
                then
                mov bx, debugbx
                mov cx, debugcx
                mov dx, debugdx
                mov bp, debugbp
                mov si, debugsi
                mov di, debugdi
                mov ss, debugss
                mov es, debuges
                mov sp, debugsp
                mov ax, debugflags
                or ax, # $100           \ set TF bit in flags
                push ax
                push debugcs
                push debugip
                mov ax, debugax
                mov ds, debugds
                iret            end-code

code one_break  ( -- )          \ go till the breakpoint we just installed
                mov forthsp sp
                mov forthss ss
                mov forthbp bp
                mov forthbx bx
                mov forthsi si
                mov forthdi di
                mov forthds ds
                mov forthes es
                mov bx, debugbx
                mov cx, debugcx
                mov dx, debugdx
                mov bp, debugbp
                mov si, debugsi
                mov di, debugdi
                mov ss, debugss
                mov es, debuges
                mov sp, debugsp
                mov ax, debugflags
                and ax, # $FEFF         \ CLEAR TF bit in flags
                push ax
                push debugcs
                push debugip
                mov ax, debugax
                mov ds, debugds
                iret            end-code

\ **************************************************************************
\ Set the single step interrupt, perform a single instruction step, and
\ then restore the single step interrupt.
\ **************************************************************************

: single_step   ( -- )                  \ perform one instruction step, and
                                        \ display registers with next
                                        \ instruction to be traced.
                1 save_int#             \ save existing interrupt vector
                1 set_int#              \ set to out interrupt routine
                one_step                \ do a single step trace of one inst
                1 rest_int#             \ restore the interrupt vector
                ;

: unbreak       ( -- )                  \ remove the break point
                dbto
                if      3 rest_int#
                        dbsave ?cs: dbto c!L    \ restore program byte
                then    ;

: break_point   ( -- )                  \ break point to offset specified
                dbto 0=
                if      one_break exit  \ just continue execution
                then
                ?cs: dbto c@L =: dbsave
                dboff
                if      $CC ?cs: dbto c!L \ only break if not zero
                then
                3 save_int#
                3 set_int#
                one_break
                3 rest_int#
                dbsave ?cs: dbto c!L    \ restore program byte
                ip-@ 1- =ip             \ backup IP one byte
                off> dbto
                off> dboff ;            \ reset break point offset

\ **************************************************************************
\ show the current registers, and a series of instructions as they will
\ be executed.
\ **************************************************************************

0 value tbline

: show_debug_init ( -- )
                savecursor cursor-off
                .dbheader
                0 dbtop 3 + 59 dbbot box
                ."  Name      Addr   Instruction                  Data      "
                bline =: tbline
                restcursor
                0 20 at ;

: show_debug    ( -- )
                savecursor cursor-off
                .regs
                debug.s
                tbline =: bline
                bcr .pinst bcr .instruction bcr
                dbbot dbtop 4 + - 3 - 0
                do      i .ninst bcr
                        key? ?leave
                loop    restcursor ;

: up_dbline     ( -- )
                ipprev2 =: ipprev
( up arrow )    dboff 1- 0max =: dboff ;

: down_dbline   ( -- )
                ipprev2 =: ipprev
( down arrow )  incr> dboff ;

\ **************************************************************************
\ Additional MINI help for the debugger.
\ **************************************************************************

: show_help     ( -- )
                ipprev2 =: ipprev
                savecursor cursor-off savescr
                0 5 59 19 box&fill
        bcr ."   Debugger commands:"
        bcr
        bcr ."      SPACE  = Do a single instruction step."
        bcr ."      ESC    = Done, terminate the debugger."
        bcr ."      G      = Go-till '**' line, or just continue program"
        bcr ."               execution if no Go-till line marked."
        bcr
        bcr ."        Press ANY key to continue debugging "
                key drop
                restscr restcursor show_debug_init ;

\ **************************************************************************
\ the main trace loop, walks through instructions until the ESC key is
\ pressed.
\ **************************************************************************

: do_dbkey      ( c1 -- f1 )
                case
( terminate )   $1B of                          true    endof
( enter )       $0D of  single_step             false   endof
( space )       $20 of  single_step             false   endof
( up arrow )    $C8 of  up_dbline               false   endof
( down arrow )  $D0 of  down_dbline             false   endof
( help )        $BB of  show_help               false   endof
                upc                 \ remaining tests are case insensitive
( Go )          'G' of  break_point             false   endof
                        ipprev2 =: ipprev
( all others )          drop beep               false
                endcase ;

: steps         ( -- )
                rp@      =sp
                rp@ 80 - rp!            \ move return stack out of the way
                =bx                     \ top of stack to debug BX
                sp@      =si            \ set debugger to Forth stack
                sp@ 20 - sp!
                dobreak 0=
                if      show_debug_init
                then
                begin   dobreak 0=
                        if      show_debug
                                key do_dbkey
                        else    dobreak =: dbto
                                off> dobreak
                                break_point
                                show_debug_init
                                false
                        then
                until   .dbfooter abort ;


\ **************************************************************************
\ setup for tracing a series of instructions, and call STEPS.
\ **************************************************************************

: %trace        ( a1 -- )
                ?dup 0= ?exit
                ?ds: ?cs: $00FE !L      \ a place to get the DS value later
                dup =ip =ax
                ?cs: dup =cs =es
                ?ds: dup =ds =ss
                off> ipprev
                steps ;

: $trace        ( a1 -- )               \ use as in: TRACE <word> <enter>
                                        \ sets up and displays first
                                        \ instruction with registers.
                off> dboff
                %trace ;

0 value interp

: $breakat      ( a1 -- )
                =: dobreak
                1 =: dboff
                interp %trace ;         \ set the breakpoint and interpret
                                        \ the rest of the line.

}

