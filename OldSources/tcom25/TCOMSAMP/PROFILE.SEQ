\\ PROFILE.SEQ     Profiler for TCOM programs              by Tom Zimmer
.options /opt

  This file provides the ability to profile a TCOM application. Words
that consume large amounts of execution time are detected, and
accumulated into buckets in 16 byte buckets.

  The operation of this profiler is almost completely transparent to
the operation of your program.  A change is made to the DOS system clock,
to accumulate counts of where an application is each time a clock tick
occurs. PROFILE.SEQ saves a count of each occurance of a particular "PC"
(the Program Counter) on each clock tick.  After the application
terminates, the accumulated results are written to a file called
PROFILE.TXT.  The file will contain the bucket address accumulated, the
count of how many times the code in the bucket address was encountered.

The primary use of PROFILE.SEQ is to detect algorithm problems in your
program.  Since counts are only performed at 18 times a second, you will
need to profile a fairly long (in execution time) program to get useful
results.

  INCLUDE PROFILE.SEQ in your program, then the profiler can then be used
as follows:

: MAIN          ( -- )
                prostart
                ......          \ your program code
                proend ;

  Include PROSTART at the beginning of the program or area where you want
profiling to be performed, and include PROEND at the end of your program
or area where profiling is to be done.

  This will profile the TCOM program, and  write results to PROFILE.TXT.

  A companion program for F-PC also called PROFILE.SEQ allows high usage
colon definitions to be detected and accumulated.

NOTE:   When running, the profiler needs to walk the interrupt stack to
        find out where your program is running.  To do this, you need to
        include the statment:  STACKS=0,0  in your CONFIG.SYS.  If you have
        something like STACKS=9,256, then the profiler won't work because
        DOS will switch the stack segment to some other area of memory.


{

cr beep
cr .(           ***********************************************************)
cr .(           ****  WARNING! For Profile to work properly, you MUST  ****)
cr .(           ****  include:   STACKS=0,0   in your CONFIG.SYS file, ****)
cr .(           ****  and then YOU MUST REBOOT YOUR COMPUTER  !!!!!!!  ****)
cr .(           ***********************************************************)
cr .(           ****   After profiling, restore any previous stacks    ****)
cr .(           ****   statment you may have had in your CONFIG.SYS    ****)
cr .(           ***********************************************************)
cr beep cr cr

here-t constant TIMERSAVE   4 allot-t   \ vector in CODE space
here-t constant PROF_SEG    2 allot-t   \ the profiler buffer DATA segment
here-t constant PROG_SEG    2 allot-t   \ the program segment
here-t constant IOFF        2 allot-t   \ offset into stack for our program

$800 ARRAY PROF_BUF

LABEL MYTIMER   ( -- )          \ Timer interrupt routine
                PUSH DS
                PUSH BX
                PUSH di
                MOV DS, CS: PROF_SEG    \ DS = profile buffer segment
                MOV di, SP
                CMP CS: IOFF # 0 WORD   \ does IOFF=ZERO?
                JE 2 $                  \ then go calculate the stack offset
                ADD di, CS: IOFF        \ else just adjust for stack offset
                MOV BX, SS: 2 [di]      \ index into stack & get routine's CS
                CMP BX, CS: PROG_SEG    \ compare to our program segment
                JNE 0 $                 \ exit if not equal
                MOV BX, SS: 0 [di]      \ index into stack & get routine's IP
                SHR BX, # 1             \ accumulate into 16 byte bucket
                SHR BX, # 1
                SHR BX, # 1
                SHR BX, # 1
                add bx, # prof_buf      \ offset to start of profile buffer
                CMP 0 [BX], # $FF       \ is bucket full?
                JAE 0 $                 \ if so, skip the increment
                INC 0 [BX] BYTE         \ bump count of this segment
        0 $:    POP di
                POP BX
                POP DS
                JMP FAR CS: [] TIMERSAVE
\ Scan the hardware stack looking for our CODE segment
        2 $:    push ax
                push cx
                push es
                push dx
                pushf
                mov dx, di
                mov ax, ss
                mov es, ax              \ set ES=SS
                MOV CX, # $20           \ scan up stack 32 words
                add di, # 6
                mov ax, cs: prog_seg
                clc
                repnz scasw
                jnz 5 $                 \ exit if failed
                dec di
                dec di
                DEC di                  \ backup to IP from CS
                DEC di
                sub di, dx
                MOV CS: IOFF di         \ set the stack offset variable
        5 $:    popf
                pop dx
                POP es                  \ exit point, good or bad
                pop cx
                POP ax
                JMP 0 $         END-CODE

CODE SAVE&SET_VECS ( -- )       \ save and set some vectors
                PUSH ES
                MOV AX, # $351C         \ Get the interupt vector for
                INT $21                 \ BIOS timer vector
                MOV CS: TIMERSAVE BX
                MOV CS: TIMERSAVE 2+ ES \ Save old vector
                POP ES
                                        \ Setup timer vector to our routine
                PUSH DS                 \ save data segment
                MOV AX, CS
                MOV DS, AX              \ set DS to CS
                MOV DX, # MYTIMER       \ the new timer tick interrupt
                MOV AX, # $251C
                INT $21
                POP DS                  \ recover the data segment
                RET     END-CODE

CODE REST_VECS  ( -- )                  \ Restore the vectors
                PUSH DS
                MOV DX, CS: TIMERSAVE
                MOV DS, CS: TIMERSAVE 2+
                MOV AX, # $251C
                INT $21
                POP DS
                ret     END-CODE

defer proend_vector

\ This new BYE version MUST be loaded BEFORE BYE or ABORT or ABORT" is
\ used in the application.

M: probye       ( -- )          \ new BYE function
                proend_vector
                0 0 bdos
                ;

\ Patch the new BYE into the library version of BYE.

|| target f' bye >execute forth ' probye >execute switch_bodies

    handle profhndl                                 \ save filename handle
    create crlf$    $0D c, $0A c,                   \ a CRLF string
    create blanks   $20 c, $20 c, $20 c, $20 c,     \ some spaces

: saveprof      ( -- )          \ display the profile results
                cr ." Saving profile in: PROFILE.TXT "
                " PROFILE.TXT" profhndl ">handle
                profhndl hcreate abort" Failed to create profile save file"
                prof_buf $0800
                begin   0 skip dup
        [long]  while   true \ over c@ 2 >
        [long]          if      crlf$ 2 profhndl hwrite drop
                                hex over prof_buf - 16 * \ convert to offset
                                0 <# # # # # #> profhndl hwrite drop
                                decimal
                                over c@ (u.) 4 over -
                                blanks swap profhndl hwrite drop  \ spaces
                                            profhndl hwrite drop  \ use count
                        then    1 /string
                repeat  2drop
                decimal
                crlf$ 2 profhndl hwrite drop    \ append a pair of CRLF's
                crlf$ 2 profhndl hwrite drop
                profhndl hclose drop ;

0 value ?vectors_set

: proend        ( -- )
                ?vectors_set 0= ?exit   \ only if set
                rest_vecs
                off> ?vectors_set
                cr ." Program Segment: " ?cs: prog_seg @L h.
                cr ."    Stack Offset: " ?cs: ioff     @L h.
                prof_buf 80 dump
                saveprof
                ;

' proend is proend_vector               \ fill in vector

: prostart      ( -- )
                prof_buf $0800 erase    \ fill array with zeros
                ?cs: ?cs: prog_seg !L
                0    ?cs: IOFF !L       \ clear the stack offset counter
                ?ds: ?cs: prof_seg !L   \ init the profile buffer segment
                save&set_vecs
                on> ?vectors_set ;

\S      ********** END of included profiler code **********

: main          ( -- )
                prostart        \ starts profiling
                1000 0
                do      1000 0
                        do      noop noop noop noop noop
                        loop
                loop
                proend ;        \ stops profiling and saves results


