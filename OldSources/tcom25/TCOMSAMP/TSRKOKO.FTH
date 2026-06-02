\\ TSRKOKO.SEQ  A TSR Version of Konrad Kollers Fractal Program

  An example of how to make a relatively simple terminate and stay
resident program using TCOM.  This TSR is a graphics mode line dtawing
screen saver,  after a 10 (ten) minute no keypress delay.   It also
detects when it is not safe to invoke the batch file by looking at the
INDOS flag. When the current video mode is not a text mode, then it will
BEEP and refuse to popup.


        SPACE           Redraws the screen with a new set of parameters.
        SCROLL LOCK     Controls either repeated redraw with different
                        patterns, or continued drawing on the current
                        pattern.

                .options /opt /noinit   \ compiler options
{

\ **********************************************************************
\ Some CODE memory resident variables needed by the interrupt 8 handler
\ **********************************************************************

$00E6 constant int9save         \ four bytes to save original int9
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
HERE-T ,"-T KOKO FRACTAL GRAPHICS GENERATOR" ,-T \ must be unique!

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
\                cmp cs: tsrticks # 183 word    \ 18.3/sec, 1098/minute
                cmp cs: tsrticks # 10980 word   \ 18.3/sec, 1098/minute
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

label int9      ( -- )          \ the TSR's interrupt 8 handler
                pushf
                mov cs: tsrticks # 0 word       \ reset tick counter
                push ds
                push bx
                sub bx, bx
                mov ds, bx
                test $417 # $10                 \ test Scroll Lock bit
                jz 0 $
                mov cs: tsrticks # 32767 word   \ load with a big number
\               and $417 # $EF                  \ clear scroll lock bit
        0 $:    pop bx
                pop ds
                popf
                jmp far cs: [] int9save         \ jump to normal int9
                end-code

code save_int8/9 ( -- ) \ save the current contents of interrupt 8
                push es
                push bx
                mov ax, # $3508                 \ get interrupt vector 8
                int $21
                mov cs: int8save bx             \ special, in CS not DS
                mov cs: int8save 2+ es
                mov ax, # $3509                 \ get interrupt vector 8
                int $21
                mov cs: int9save bx             \ special, in CS not DS
                mov cs: int9save 2+ es
                pop bx
                pop es
                ret     end-code

code set_int8/9 ( -- )  \ set interrupt 8 to our interrupt handler
                push es
                push ds
                push bx
                mov ax, cs
                mov ds, ax
                mov dx, # int8                  \ our interrupt vector address
                mov ax, # $2508                 \ set interrupt vector 8
                int $21
                mov dx, # int9                  \ our interrupt vector address
                mov ax, # $2509                 \ set interrupt vector 9
                int $21
                pop bx
                pop ds
                pop es
                ret     end-code

code unhook_far_int8/9 ( -- )  \ restore interrupt 8 of far function
                push bx
                push ds
                mov ds, cs: int8save 2+
                mov dx,     int8save            \ far away address to restore
                mov ds,     int8save 2+
                mov ax, # $2508                 \ restore interrupt vector 8
                int $21
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

: ?already_loaded ( -- f1 )     \ check to see if we have already
                save> sseg      \ loaded this TSR into memory
                ?cs: check-string countl pad placel
                ?cs: int8save 2+ @L dup sseg !          \ set the segment
                ?cs: int8save    @L 2- @L >r            \ the offset
                pad r> over c@ 1+ comp 0=
                restore> sseg ;

: ?already_loaded_abort ( -- )          \ check to see if we have already
                ?already_loaded
        if      ." This TSR is ALREADY RESIDENT, press SCROLL LOCK to open."
             cr ." Use:  TSRLINES /R  to remove this TSR from memory."
                abort
        then    ;

: ?/remove      ( -</r>- )              \ test for removing the TSR
                >in @ >r
                bl word ?uppercase 1+ " /R" comp 0=
                if      ?already_loaded 0=                     \ is it here?
                        abort" TSR not in memory!"             \ must be here
                        unhook_far_int8/9                      \ unhook int8/9
                        ?cs: int8save 2+ @L 44 @L dealloc      \ rel environ
                        ?cs: int8save 2+ @L       dealloc or   \ rel code
                        abort" Error releasing memory!"        \ error?
                        ." TSR memory Released!"               \ or all done
                        bye                                    \ terminate
                then    r> >in ! ;

\ **********************************************************************
\ **************** USERS APPLICATION WORDS START HERE ******************
\ **********************************************************************

\ Move video page zero to page one to save it and back to restore it.

4000 array tsrbuf

: tsrsavescr    ( -- )  \ save the current text screen in a buffer
                video-seg @ 0 ?ds: tsrbuf 4000 cmovel ;

: tsrrestscr    ( -- )  \ retore the current text screen from a buffer
                ?ds: tsrbuf video-seg @ 0 4000 cmovel ;

\ **********************************************************************
\ TSR-MAIN is invoked on every keystroke, it can look at anything in DOS
\ memory, BUT, must leave the stacks unmodified on exit.
\ **********************************************************************

needs tfloat.seq
needs graph.seq

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
0 value frac-scale

32767 constant #iterationen

create paltable 0 c, 15 allot 0 c,

code set-pal    ( -- )
                push es
                mov ax, # $1002
                push ds
                pop es
                mov dx, # paltable
                int $10
                pop es
                ret
                end-code

: set-paltable 16 1 do 63 rnd 1+ paltable i + c! loop set-pal ;

code in-bounds? ( x y -- x y true | false)
                mov dx, bx
                load_bx
                mov cx, bx
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
                mov bx, cx
                save_bx
                mov bx, dx
                save_bx
        1 $:
                mov bx, ax
                ret
                end-code

: "f#in         ( D: a1 n1 --   F:--r)
                2>r
                begin   2r@ type
                        pad 1+ 12 expect
                        esc_flg @ if koko-abort then    \ leave if requested
                        bl pad 1+ span @ + c!  span @ pad c!
                        pad (fnumber?) ?dup 0=
                while   ."  <- BAD INPUT!" cr
                repeat  0< if float then
                2r> 2drop ;

: koko-abort    ( -- )
                text-mode bye ;

: fsign         ( F:r--1.0|-1.0)
                f0< if [F#] -1.0e0 else f1.0 then ;

: graphics-mode ( -- )
                640x350x16 ;

: ?keyboard     ( -- f1 )
                0 $41A c@L 0 $41C c@L - ;

: ?already_loaded_frac-scale ( -- f1 )  \ readjust frac-scale
                ?already_loaded
        if      frac-scale              \ get new frac-scale value
                ?cs: int8save 2+ @L     \ get the code segment
                ?ds: ?cs: - +           \ adjust to the data segment
                &> frac-scale !L        \ set into the memory resident copy
                ." This TSR is ALREADY RESIDENT, press SCROLL LOCK to open."
             cr ." Fractal scaling set to: " frac-scale .
             cr ." Use:  TSRLINES /R  to remove this TSR from memory."
                abort
        then    ;

: koko
        [F#] 57.23e0  a f!
        [F#] 12.3e0  bb f!
        [F#] 43.23e0  c f!
        graphics-mode
        vdots 2/ 0 float fheight/2 f!
        hdots 2/ 0 float fwid/2 f!
        begin   f0.0 x f!  f0.0 y f!
                graphics-mode
                0 color !
                set-paltable
                 15 frac-scale * rnd 1+ 0 float  a f!
                 19 frac-scale * rnd 1+ 0 float bb f!
                  7 frac-scale * rnd 1+ 0 float  c f!
            begin
            begin
                #iterationen 0
                do      i 1023 and 0=
                        if      color incr
                        then
                        fheight/2 f@ y f@ f+ fix drop !> iy
                        fwid/2    f@ x f@ f+ fix drop !> ix
                        ix iy in-bounds?
                        if      plot
                        else    i 1023 and 0=
                                if      set-paltable
                                then
                        then
                        x f@  bb f@
                        y f@  f*  c f@  f-  fabs  fsqrt
                        y f@  fsign  f*  f- yy f!
                        a f@  y f@  f-  x f!  yy f@  y f!
                        c f@  fnegate  c f!
                        ?keyboard ?leave
                loop    c f@ fabs c f!
                0 $417 c@L $10 and ?keyboard or
            until
                50 0
                do      1 tenths
                        ?keyboard ?leave
                loop
                0 $417 c@L $10 and ?keyboard or
            until
                ?keyboard
                if      key upc
                        case
                        bl  of                   false  endof
                        '+' of  incr> frac-scale false  endof
                        '-' of  decr> frac-scale false  endof
                                drop             true
                        endcase
                else    false
                then
        until   text-mode ;

: ?line_length  ( -- )
                bl word ?uppercase number? nip
                if      dup 1 max 20 min !> frac-scale
                else    10 !> frac-scale
                then    drop ;

: TSR-MAIN      ( -- )  \ the MAIN for this TSR, must be named TSR-MAIN
                ?vmode                                  \ get the video mode
                dup  2 =                                \ or    COLOR 2
                swap 3 = or 0=                          \ or    COLOR 3 ONLY
                if      beep EXIT                       \ else beep & exit
                then
                $B800 video-seg !                       \ so TSRSAVESCR works
                at? at savecursor
                tsrsavescr                              \ save screen
                koko
                tsrrestscr                              \ restore screen
                restcursor
                blinkoff
                0 $417 c@L $EF and 0 $417 c!L ;         \ clear scroll lock

: ?/non-resident ( -</n>- )     \ test for NON resident program
                >in @ >r
                bl word ?uppercase 1+ " /N" comp 0=
                if      ?line_length
                        tsr-main
                        bye                                    \ terminate
                then    r> >in ! ;

\ **********************************************************************
\ TSR_INIT contains whatever portion of DEFINIT.SEQ is needed by your
\ application.
\ **********************************************************************

: TSR_INIT      ( -- )  \ perform whatever TCOM initialization is needed
                CAPS ON                         \ ignore cAsE
                INIT-CURSOR                     \ init cursor words
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                0 SET_MEMORY                    \ default to min code space
                DOS_TO_TIB                      \ move command tail to TIB
                COMSPEC_INIT                    \ init command specification
                ;

\ **********************************************************************
\ INIT-TSR initializes the application to run, saves and sets interrupt
\ vector 8, test to make sure we haven't already loaded this TSR and
\ invokes a DOS shell to make it easy for the user to unmount this TSR
\ by just typing EXIT at the DOS commandline.
\ **********************************************************************

: INIT-TSR      ( -- )  \ entry point, initializes, and shells to DOS
                tsr_init                        \ initialize TCOM application
                randomize
                ?vmode 7 = abort" Requires EGA/VGA color!"
                save_int8/9                     \ save current int8/9 vector
                ?/remove                        \ are we removing the TSR?
                ?/non-resident                  \ run as a program not TSR
                ?line_length
                ?already_loaded_frac-scale      \ readjust frac-scale
                set_inDOS                       \ set the in DOS var pointer
                set_int8/9                      \ set int8/9 to our handler
                ?ds:     ?cs: tsrds !L          \ init DS for tsr
                rp@ 32 - ?cs: tsrsp !L          \ init RP for tsr
                sp@ 20 - ?cs: tsrsi !L          \ init SP for tsr
                0        ?cs: tsrticks !L       \ reset tsr counter
   ." TSRKOKO, EGA mode screen saver, draws fractals after no keys for 10 minutes."
cr ."           Start TSRKOKO immediately by pressing Scroll Lock."
cr ." Type: TSRKOKO /R                  Remove the TSR from resident memory"
cr ."       TSRKOKO <size{1-20 [10] }>  Control the size of the fractals"
cr ."       TSRKOKO /N <size>           Run KOKO NON-resident as a program"
                ?ds: ?cs: -             \ CODE space paragraphs needed
                memend @ paragraph +    \ DATA space paragraphs needed
                term&stay ;             \ terminate with needed paragraphs




