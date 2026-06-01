\\ TSR.SEQ      Sample Terminate and Stay Resident program      by Tom Zimmer

  An example of how to make a relatively simple terminate and stay
resident program using TCOM.  This TSR pops up a window and allows entry
and conversion of DECIMAL number to HEX.  It also detects when it is not
safe to open the window by looking at the INDOS flag.  When the current
video mode is not a text mode, then it will BEEP and refuse to popup.

  The SCROLL LOCK key is detected by looking at low memory location
0000:0417h and testing the $10 weight bit for the scroll lock key.

  Other keys like LEFT SHIFT, RIGHT SHIFT, CONTROL, NUMBER LOCK or
CAPS LOCK can be detected by looking at other bits of the same location.

  Keys that generate characters can be detected by looking into the
keyboard buffer.  If a character generating key is used, then it should
be removed from the keyboard buffer with "KEY DROP" at the start of your
program in TSR-MAIN.

NOTE:   Some invocations of the hot key will be ignored if you are at the
        DOS commandline level, because DOS spends much of its time in DOS,
        which leaves the "inDOS" variable with a non-zero value.  The TSR
        ignores any keypresses when "inDOS" is non-zero.

                .options /opt /noinit   \ compiler options
{

\ **********************************************************************
\ Some CODE memory resident variables needed by the interrupt 9 handler
\ **********************************************************************

$00EC constant inDOS      \ DOS variable pointer, 4 bytes for offset,seg
$00F0 constant sssave     \ save stack segment
$00F2 constant spsave     \ save stack pointer
$00F4 constant tsrsi      \ save the tsr SI reg
$00F6 constant tsrsp      \ save the tsr SP reg
$00F8 constant tsrds      \ save the tsr DS reg
$00FA constant inting     \ are we in the middle of an int9?
$00FC constant int9save   \ The last 4 bytes before code starts is used
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
HERE-T ,"-T A SIMPLE TCOM TSR NUMBER CONVERTER" ,-T     \ must be unique!

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
         abort" This TSR is ALREADY RESIDENT, press SCROLL LOCK to open." ;

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

: TSR-MAIN      ( -- )  \ the MAIN for this TSR, must be named TSR-MAIN
                0 $417 C@L $10 and 0= ?EXIT             \ SCROLL LOCK pressed?
                0 $417 c@L $EF and 0 $417 c!L           \ clear scroll lock
                ?vmode                                  \ get the video mode
                dup  7 =                                \ allow MONO
                over 2 = or                             \ or    COLOR 2
                over 3 = or 0=                          \ or    COLOR 3 ONLY
                if      drop beep EXIT                  \ else beep & exit
                then    7 =                             \ if MONO?
                if      $B000                           \ use mono buffer
                else    $B800                           \ else use color buff
                then    video-seg !                     \ so TSRSAVESCR works
                at? at                                  \ resync cursor pos
                savecursor cursor-on norm-cursor        \ save/set cursor
                tsrsavescr                              \ save screen
                18 3 60 17 box&fill                     \ clear screen
                bcr ."     A Simple number converter."
                bcr
                bcr ."     Enter a Number: " at?
                bcr ."     (trailing h=hex, b=binary)"
                bcr
                bcr ."     DECIMAL:"
                bcr ."     HEX    :"
                bcr ."     BINARY :"
                bcr bcr
                bcr ."     Press ESC to close this window "
                begin   2dup at 19 spaces 2dup at
                        tib 19 expect span @ #tib ! >in off
                        esc_flg @ 0=
        [long]  while   bl word ?uppercase count + 1- c@
                        case    'H' of  hex     true endof      \ hex
                                'B' of  binary  true endof      \ binary
                                        drop                    \ else decimal
                                        decimal false
                        endcase \ -- f1=true if trailing letter found
                        if      -1 here c+!
                                bl here count + c!
                        then    here number? drop 2>r   \ convert number
                        2dup 4 + swap 7 - swap at
                        hex                             \ show it in HEX
                        2r@ ?dup
                        if      <# # # # # ':' hold # # # # #> type
                        else  0 <# # # # # #> type 5 spaces
                        then
                        decimal                         \ show it in DECIMAL
                        2dup 3 + swap 7 - swap 2dup at 12 spaces at
                        2r@ ud.
                        2dup 5 + swap 7 - swap 2dup at 16 spaces 2dup 1+ at
                        16 spaces 2dup at
                        2 base !                        \ show it in BINARY
                        2r> ?dup
                        if    0 <# 16 0 do # loop #> type >r 2dup 1+ at r>
                        then  0 <# 16 0 do # loop #> type    2drop
                        decimal
                repeat  2drop                           \ repeat till done
                tsrrestscr                              \ restore screen
                restcursor                              \ restore cursor loc
                0 $417 c@L $EF and 0 $417 c!L ;         \ clear scroll lock


\ **********************************************************************
\ This version of TSR-MAIN toggles a message on and off the screen using
\ the SCROLL LOCK key.  Useful for displaying a table, with no interaction.
\ **********************************************************************

\ **********************************************************************
\
\ 0 value tsrtgl
\
\ : TSR-MAIN      ( -- )          \ the MAIN for this TSR
\                0 $417 C@L $10 and              \ test for SCROLL LOCK
\                if      tsrtgl 0=
\                        if      at?
\                                tsrsavescr
\                                cls
\                                24 10 at
\                                ."  Hi, this is a TCOM TSR! "
\                                on> tsrtgl
\                                at
\                        then
\                else    tsrtgl
\                        if      tsrrestscr
\                                off> tsrtgl
\                        then
\                then    ;
\
\ **********************************************************************

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
                ?/remove                        \ are we removing the TSR?
                ?already_loaded_abort           \ check for already resident
                set_inDOS                       \ set the in DOS var pointer
                set_int9                        \ set INT9 to out handler
                ?ds:     ?cs: tsrds !L          \ init DS for tsr
                rp@ 32 - ?cs: tsrsp !L          \ init RP for tsr
                sp@ 20 - ?cs: tsrsi !L          \ init SP for tsr
   ." Press SCROLL LOCK to popup the simple DECIMAL to HEX converter."
cr ." Type  TSR /R  at the DOS prompt to remove the TSR from resident memory."
                ?ds: ?cs: -             \ CODE space paragraphs needed
                memend @ paragraph +    \ DATA space paragraphs needed
                term&stay ;             \ terminate with needed paragraphs


