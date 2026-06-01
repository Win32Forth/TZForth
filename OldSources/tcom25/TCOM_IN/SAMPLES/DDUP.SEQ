\\ ZDUP.SEQ     Zimmers Disk Duplicator                 by Tom Zimmer

  This program allows easy duplication of 5 1/4 inch and 3 1/2 inch
floppy disks.  The source disk is read into the computers memory and is
saved in a disk file on the hard disk.  The temporary hard disk file is
then used to write one or more identical copies of the source disk.

  This program can be loaded on either F-PC or compiled with TCOM.

        .options /opt /noinit
{

\f anew dupper

\f ' noop alias [long] immediate

\f 18432 array %tbuffer

\f ' ud.r alias ud,.r

0 value ?format
0 value tbuffer
0 value tbuffer0
0 value tbuffer1
0 value #sectors
0 value #sec-bytes
0 value #top-cylinder
0 value disk#

                \ 0=A:, 1=B:
code dreset     ( drive -- error-code ) \ reset drive
\f              pop bx
                mov dl, bl
                mov ax, # 0000h
                int 13h
                jnc 0 $                 \ jump if no error
                mov al, ah              \ else move error to AL
                sub ah, ah              \ and clear AH
                jmp 1 $                 \ and jump to exit
        0 $:    mov ax, # 0             \ if no error, clear AX
        1 $:    mov bx, ax
\f              push bx
\f              next
\t              ret
                end-code

code dinfo      ( drive -- top-cylinder sectors )
\f              pop bx
                push es
                mov dl, bl
                mov ax, # 0800h         \ get drive information
                int 13h
                pop es
                sub bx, bx
                mov bl, ch              \ get cylinders
\f              push bx
\t              save_bx
                sub ax, ax
                mov al, cl              \ and sectors
                mov bx, ax
\f              push bx
\f              next
\t              ret
                end-code

                                \ read an entire cylinder at head
code rtrack     ( head cylinder -- error-code )
\fpc            pop bx
                mov ch, bl              \ cylinder
                mov bx, &> tbuffer      \ buffer
                mov dl, &> disk#        \ drive         0=A:, 1=B: ect..
                mov cl, # 1             \ sector        1=first_sector
\f              pop ax
\t              lodsw
                mov dh, al              \ head          0 or 1 for floppy
                push es
                mov ax, ds
                mov es, ax
                mov al, &> #sectors     \ # or sectors
                mov ah, # 02h
                int 13h
                jnc 0 $                 \ jump if no error
                mov al, ah              \ else move error to AL
                sub ah, ah              \ and clear AH
                jmp 1 $                 \ and jump to exit
        0 $:    mov ax, # 0             \ if no error, clear AX
        1 $:    pop es
                mov bx, ax
\f              push bx
\f              next
\t              ret
                end-code

                                \ write an entire cylinder at head
code wtrack     ( head cylinder -- error-code )
\fpc            pop bx
                mov ch, bl              \ cylinder
                mov bx, &> tbuffer      \ buffer
                mov dl, &> disk#        \ drive         0=A:, 1=B: ect...
                mov cl, # 1             \ sector        1=first_sector
\f              pop ax
\t              lodsw
                mov dh, al              \ head          0 or 1 for floppy
                push es
                mov ax, ds
                mov es, ax
                mov al, &> #sectors     \ # or sectors
                mov ah, # 03h
                int 13h
                jnc 0 $                 \ jump if no error
                mov al, ah              \ else move error to AL
                sub ah, ah              \ and clear AH
                jmp 1 $                 \ and jump to exit
        0 $:    mov ax, # 0             \ if no error, clear AX
        1 $:    pop es
                mov bx, ax
\f              push bx
\f              next
\t              ret
                end-code

80 array abuffer

                                \ format an entire track at head
code %ftrack    ( head track -- error-code )
\fpc            pop bx
                mov ch, bl              \ cylinder
                mov bx, # abuffer       \ buffer
                mov dl, &> disk#        \ drive         0=A:, 1=B: ect..
                mov cl, # 1             \ sector        1=first_sector
\f              pop ax
\t              lodsw
                mov dh, al              \ head          0 or 1 for floppy
                push es
                mov ax, ds
                mov es, ax
                mov al, &> #sectors     \ # or sectors
                mov ah, # 05h
                int 13h
                jnc 0 $                 \ jump if no error
                mov al, ah              \ else move error to AL
                sub ah, ah              \ and clear AH
                jmp 1 $                 \ and jump to exit
        0 $:    mov ax, # 0             \ if no error, clear AX
        1 $:    pop es
                mov bx, ax
\f              push bx
\f              next
\t              ret
                end-code

                                \ format an entire track at head
: ftrack        ( head track -- error-code )
                #sectors 0
                do      dup      abuffer i 4 * + c!
                        over     abuffer i 4 * + 1+ c!
                        i 1+     abuffer i 4 * + 2+ c!
                        2 ( 512) abuffer i 4 * + 3 + c!
                loop    %ftrack ;

handle temphndl

: open_temp_disk ( -- )
                temphndl hopen abort" Failed to open temp disk file" ;

: close_temp_disk ( -- )
                temphndl hclose drop ;

: alert         ( -- )
\                3000 1 tone
                2000 1 tone ;

: alert_bye     ( -- )
                alert bye ;

: ddup-key      ( -- c1 )
                key dup 27 =
                if      close_temp_disk
                        cr ." Disk duplication was user terminated!"
                        bye
                then    upc dup bl max emit ;

0 value ?noread
0 value ?writing

: make_temp_disk ( -- )
                " TEMPDISK.$$$" temphndl ">handle
                temphndl hopen 0=
                if      cr ." Temp file: " temphndl count type ."  of "
                        temphndl endfile 1 ud,.r ."  bytes"
                        0.0 temphndl movepointer  \ back to start of file
                        cr ." A temp disk file already exists, use it (Y/N/ESC) [N] ? "
                        ddup-key 'Y' =
                        if      on> ?noread
                                EXIT            \ ***** EXITS HERE *****
                        then
                then
                temphndl hcreate abort" Failed to create temp disk file" ;

: del_temp_disk ( -- )
                cr ." Save the temp disk file for use later (Y/N/ESC) [N] ? "
                ddup-key 'Y' <>
                if      temphndl hdelete drop
                then    ;

: disk-reset    ( -- )
                disk# dreset ?dup
                if      dup h. abort" Disk error"
                then    ;

: .info         ( -- )          \ display program information
cr ." Usage: DDUP <A: or B:> </f> <enter>"
cr ."                         /f = format destination disk(s) during write"
cr ." DDUP.COM is a public domain Disk Duplicator program written by Tom Zimmer."
cr ." DDUP was written in Forth and compiled with the TCOM Target Compiler."
cr
cr ." If you would like to have the source for DDUP and other TCOM example"
cr ." programs, send a check for $60.00 US to:"
cr
cr ." Address: Tom Zimmer            Phone: (408) 263-8859 evenings (7pm-9pm pst)"
cr ."          292 Falcato Drive            (415) 327-8800 days     (9am-5pm pst)"
cr ."          Milpitas, Ca. 95035   Outside US orders add 20 dollars."
cr
cr ." You will receive the TCOM compiler, its source, the source for DDUP and"
cr ." the source for a many other TCOM example programs on 3.5 inch 1.44 meg disks."
cr
cr ." Example programs include:
cr ."   ZLIST  file viewer       SZ    small editor      VED    Virtual Editor"
cr ."   LOOK   file searcher     ZTREE disk space util   TIMEIT elapse timer"
cr ."   MANGEN Mandelbrot draw   TETRA a game            VMODE  video mode set"
cr
cr ." and several others, plus F-PC, the FULL Forth system on which TCOM is built."
cr ." This package totals almost five megabytes installed, with full source."
cr              ;

: tcom_init     ( -- )
\t              INIT-CURSOR                     \ get intial cursor shape
\t              MARGIN_INIT                     \ initialize margins & TAB
\t              50 FUDGE !                      \ init MS timer, GUESS!!
\t              CAPS ON                         \ ignore cAsE
\t              ?DS: SSEG !                     \ init search segment
\t              VMODE.SET                       \ init EMIT, TYPE & SPACES
\t              $FFF0 SET_MEMORY                \ default to 64k code space
\t              DOS_TO_TIB                      \ move command tail to TIB
\t              COMSPEC_INIT                    \ init command specification
                ;

: DDUP          ( -<A|B>- )
                tcom_init
\f              %tbuffer        !> tbuffer0
\t              32768 ds:alloc  !> tbuffer0
\ **********************************************************************
\ The following eight lines correct for a feature of DOS that causes it
\ to perform INT 13h reads and writes at half of the normal speed when
\ the program being run is executing within the first 64k bytes of DOS's
\ program memory.  My solution is to simply shell to myself again until
\ the code segment is above $1000 (64k) bytes.  If you don't believe me,
\ try compiling this program again with the following lines commented
\ out. Note that your computer MUST have more than 590k of available
\ program memory as shown by MEM (after DOS boots and your terminate and
\ stay loaded programs are already loaded) for this problem to ever show
\ up on your computer.
\ **********************************************************************
\t              ?cs: $2000 u<           \ if in first 64k bytes of memory
\t      [long]  if      $2000 alloc drop 2drop          \ consume some space
\t                      me@ me$ count   pad  place      \ run MYSELF again
\t                      "  "            pad +place
\t                      tib #tib @      pad +place
\t                      cr ." ->" pad count type
\t                      pad $sys drop
\t                      bye                             \ and terminate
\t              then
\ **********************************************************************
                temphndl clr-hcb
\t              ['] alert_bye is abort_func     \ init error handler
                bl word c@ 0=
                if      .info
                        cr ." Disk drive to use for duplication (A/B/ESC) [A] ? "
                        ddup-key
                else    here 1+ c@ upc
                then    'B' =
                if      1 !> disk#      \ select physical disk B:
                else    0 !> disk#      \ select physical disk A:
                then
                bl word 1+ " /f" caps-comp 0= !> ?format
                disk-reset              \ reset the disk sub system
                disk# dinfo             \ set the tracks and sectors
                !> #sectors !> #top-cylinder
                cr ." Drive " disk# 'A' + emit
                ." : has " #top-cylinder . ." cylinders and "
                #sectors . ." sectors"
\f              #sectors 18 > abort" Can't handle more than 18 sectors!"
                #sectors 512 * !> #sec-bytes
                tbuffer0 #sec-bytes + !> tbuffer1       \ second buffer
                tbuffer0 !> tbuffer
                make_temp_disk          \ make a temporary disk file
                ?noread 0=
[long]  if      cr ." Insert disk to READ in drive " disk# 'A' + emit
                ." : and ENTER to READ or ESC to cancel."
                begin ddup-key 13 - while alert repeat
                cr time-reset
                on> ?writing
                tbuffer0 !> tbuffer 0 0 rtrack drop  \ dummy read first time
                ." Reading track: " at?
                #top-cylinder 1+ 0
        [long]  ?do     2dup at i .
                        tbuffer0 !> tbuffer 0 i rtrack abort"  Read error!"
                        tbuffer1 !> tbuffer 1 i rtrack abort"  Read error!"
                        tbuffer0 #sec-bytes 2* dup>r temphndl hwrite r> -
                        abort"  Write error to temp disk file!"
                        ?keypause
                loop    2drop
                ."   [Read time (min:sec) : "
                time-elapsed b>t ttime 2@ form-time
                count 3 /string 5 min type ." ]"
                close_temp_disk
                open_temp_disk
        else    cr ." ***** SKIPPING THE READ, USING THE EXISTING TEMP DISK FILE *****"
        then
        begin   cr ." Insert the disk to !*WRITE*! to and press ENTER to !*WRITE*! or ESC to cancel."
                begin ddup-key 13 - while alert repeat
                cr time-reset
                off> ?writing
                disk-reset
                ." Writing track: " at?
                0.0 temphndl movepointer       \ back to start of temp file
                tbuffer #sec-bytes temphndl hread drop
                0 0 wtrack drop
                0 0 wtrack ?format 0= and
        [long]  if      2drop
                        ."  !** WRITE ERROR ON TRACK ZERO **!" alert
                        cr ." Format during write (Y/N/ESC) [Y] ? "
                        ddup-key 'N' <> dup !> ?format
                        if      ."  ** Formatting with Write **"
                        then    cr ." Writing track: " at?
                        4 0     \ try to format track zero 4 times
                        do      0 0 ftrack drop
                                0 0 wtrack 0= ?leave
                                i 3 = abort" Bad track zero!"
                        loop
                then
                0.0 temphndl movepointer       \ back to start of temp file
                #top-cylinder 1+ 0
        [long]  ?do     2dup at cols 1- sp>col
                        2dup at i .
                        tbuffer0 #sec-bytes 2* dup>r temphndl hread r> -
                        abort" Temp file read error"
                        ?format
                        if      ." - Formatting"
                                0 i ftrack abort" Format error!"
                                1 i ftrack abort" format error!"
                                ."  - Writing"
                        then
                        tbuffer0 !> tbuffer 0 i wtrack abort"  Write error!"
                        tbuffer1 !> tbuffer 1 i wtrack abort"  Write error!"
                        ?keypause
                loop    2drop
\                ?format if cr then
                ."   [Write time (min:sec) : "
                time-elapsed b>t ttime 2@ form-time
                count 3 /string 5 min type ." ]"
                cr ." Write to another disk? (Y/N/ESC) [Y] ? "
                ddup-key 'N' =
        until   close_temp_disk
                del_temp_disk           \ discard the temporary disk file
                ;

\f cr .( Type DDUP to run the disk duplicator. )

