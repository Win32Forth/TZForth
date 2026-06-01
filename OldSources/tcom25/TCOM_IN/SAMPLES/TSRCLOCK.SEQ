\\ TSRCLOCK.SEQ   Sample Terminate and Stay Resident program   by Tom Zimmer

  An example of how to make a relatively simple terminate and stay
resident program using TCOM.  Displays the current time in hours:minutes
in the upper right corner of the screen.  It also detects when it is not
safe to open the window by looking at the INDOS flag.  When the current
video mode is not a text mode, then it will BEEP and refuse to popup.

NOTE:   Some invocations of the hot key will be ignored if you are at the
        DOS commandline level, because DOS spends much of its time in DOS,
        which leaves the "inDOS" variable with a non-zero value.  The TSR
        ignores any keypresses when "inDOS" isn non-zero.

                .options /opt /noinit   \ compiler options
{

\ **********************************************************************
\ Some CODE memory resident variables needed by the interrupt 8 handler
\ **********************************************************************

$00EA constant tsrticks         \ a tick counter
$00EC constant inDOS            \ DOS variable pointer, 4 bytes as offset,seg
$00F0 constant sssave           \ save stack segment
$00F2 constant spsave           \ save stack pointer
$00F4 constant tsrsi            \ save the tsr SI reg
$00F6 constant tsrsp            \ save the tsr SP reg
$00F8 constant tsrds            \ save the tsr DS reg
$00FA constant inting           \ are we in the middle of an int8?
$00FC constant int8save         \ The last 4 bytes before code starts is used
                                \ to preserve the original INT 8h contents.

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
HERE-T ,"-T A TCOM TSR CLOCK" ,-T \ must be unique!

\ **********************************************************************
\ WARNING: THE ABOVE STRING MUST PRECEED THE INT8 HANDLER DIRECTLY, SO
\          THE CHECK FOR RESIDENCY WILL WORK PROPERLY!!!!!!!!!!!!!!!!!!
\ **********************************************************************

\ **********************************************************************
\ Here is the interrupt 8 handler code, it is invoked on each key press.
\ **********************************************************************

label int8      ( -- )          \ the TSR's interrupt 8 handler
                pushf
                cmp cs: inting # $A508 word     \ if already doing int8
                je 1 $                          \ then branch to old int8
                inc cs: tsrticks word
                cmp cs: tsrticks # 36 word
                jnae 1 $
                push ds                         \ save regs we will use
                push bx
                mov ds, cs: inDOS 2+            \ get seg:off of inDOS var
                mov bx, cs: inDOS
                cmp 0 [bx], # 0 byte            \ is inDOS variable zero?
                pop bx                          \ restore used registers
                pop ds
                jne 1 $                         \ if not go normal int8
                mov cs: inting # $A508 word     \ mark as already in int8
                popf
                int 08h                         \ recursively do int8
                pushf                           \ save flags
                sti                             \ re-enable interrupts
                CALL DO-TSR                     \ call our TSR
                mov cs: tsrticks # 0 word       \ reset tick counter
                mov cs: inting # 0 word         \ clear the key test flag
                popf                            \ restore processor status
                iret                            \ return from interrupt
        1 $:    popf
                jmp far cs: [] int8save         \ jump to normal int8
                end-code

code save_int8  ( -- ) \ save the current contents of interrupt 8
                push es
                push bx
                mov ax, # $3508                 \ get interrupt vector 8
                int $21
                mov cs: int8save bx             \ special, in CS not DS
                mov cs: int8save 2+ es
                pop bx
                pop es
                ret     end-code

code set_int8   ( -- )  \ set interrupt 8 to our interrupt handler
                push es
                push ds
                push bx
                mov ax, cs
                mov ds, ax
                mov dx, # int8                  \ our interrupt vector address
                mov ax, # $2508                 \ set interrupt vector 8
                int $21
                pop bx
                pop ds
                pop es
                ret     end-code

code unhook_far_int8 ( -- )  \ restore interrupt 8 of far function
                push bx
                push ds
                mov ds, cs: int8save 2+
                mov dx,     int8save            \ far away address to restore
                mov ds,     int8save 2+
                mov ax, # $2508                 \ restore interrupt vector 8
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
                ?cs: int8save 2+ @L dup sseg !          \ set the segment
                ?cs: int8save    @L 2- @L >r            \ the offset
                pad r> over c@ 1+ comp 0=
                restore> sseg ;

: ?already_loaded_abort ( -- )          \ check to see if we have already
                ?already_loaded
         abort" This TSR is ALREADY RESIDENT, press SCROLL LOCK to open." ;

: ?/remove      ( -</r>- )              \ test for removing the TSR
                bl word ?uppercase 1+ " /R" comp 0=
                if      ?already_loaded 0=                     \ is it here?
                        abort" TSR not in memory!"             \ must be here
                        unhook_far_int8                        \ unhook int8
                        ?cs: int8save 2+ @L 44 @L dealloc      \ rel environ
                        ?cs: int8save 2+ @L       dealloc or   \ rel code
                        abort" Error releasing memory!"        \ error?
                        ." TSR memory Released!"               \ or all done
                        bye                                    \ terminate
                then    ;

\ **********************************************************************
\ **************** USERS APPLICATION WORDS START HERE ******************
\ **********************************************************************

\ **********************************************************************
\ TSR-MAIN is invoked on a count of timer ticks, it can look at anything
\ in DOS memory, BUT, must leave the stacks unmodified on exit.
\ **********************************************************************

: TSR-MAIN      ( -- )  \ the MAIN for this TSR, must be named TSR-MAIN
                ?vmode                                  \ get the video mode
                dup  2 =                                \ or    COLOR 2
                swap 3 = or 0=                          \ or    COLOR 3 ONLY
                if      EXIT                            \ else exit
                then
                at?     74 0 at space gettime form-time count 5 min type
                at ;

\ **********************************************************************
\ TSR_INIT contains whatever portion of DEFINIT.SEQ is needed by your
\ application.
\ **********************************************************************

: TSR_INIT      ( -- )  \ perform whatever TCOM initialization is needed
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                0 SET_MEMORY                    \ default to min code space
                DOS_TO_TIB                      \ move command tail to TIB
                ;

\ **********************************************************************
\ INIT-TSR initializes the application to run, saves and sets interrupt
\ vector 8, test to make sure we haven't already loaded this TSR and
\ invokes a DOS shell to make it easy for the user to unmount this TSR
\ by just typing EXIT at the DOS commandline.
\ **********************************************************************

: INIT-TSR      ( -- )  \ entry point, initializes, and shells to DOS
                tsr_init                        \ initialize TCOM application
                save_int8                       \ save current int8 vector
                ?/remove                        \ are we removing the TSR?
                ?already_loaded_abort           \ check for already resident
                set_inDOS                       \ set the in DOS var pointer
                set_int8                        \ set int8 to our handler
                ?ds:     ?cs: tsrds !L          \ init DS for tsr
                rp@ 32 - ?cs: tsrsp !L          \ init RP for tsr
                sp@ 20 - ?cs: tsrsi !L          \ init SP for tsr
                0        ?cs: tsrticks !L       \ reset tsr counter
   ." Type  TSRCLOCK /R  at the DOS prompt to remove the TSR from resident memory."
                ?ds: ?cs: -             \ CODE space paragraphs needed
                memend @ paragraph +    \ DATA space paragraphs needed
                term&stay ;             \ terminate with needed paragraphs


