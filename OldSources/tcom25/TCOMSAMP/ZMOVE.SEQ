\\ ZMOVE.SEQ            Move a file over the serial link        Tom ZImmer

.options /opt /noinit /tailopton        \ compile options for ZMOVE

  This file implements a simple file transfer protocol between two
computers connected by a cable on COM1:.

Usage:

  Type: ZMOVE <enter>   Waits for a file to be received at 38k baud, cancel
                        by pressing any key.

  Type: ZMOVE /19200 <enter>
                        Waits for a file to be received at 19.2k baud, cancel
                        by pressing any key.

  Type: ZMOVE /9600 <enter>
                        Waits for a file to be received at 9600 baud, cancel
                        by pressing any key.

  Type: ZMOVE <filename> <enter>
                        Send <filename> to the other computer from this
                        computer.

  Type: ZMOVE /19200 <filename> <enter>
                        Send <filename> to the other computer from this
                        computer at 19.2k baud.

  Type: ZMOVE /9600 <filename> <enter>
                        Send <filename> to the other computer from this
                        computer at 9600 baud.

  Type: ZMOVE <filename> <filename> .. <enter>
                        Send a series of files from this computer to the
                        other computer.

Compiling:

  TCOM ZMOVE <enter>

  Will build the file ZMOVE.COM which will be about 8.5k bytes.

{

$0A0D constant crlf

here-t constant cs:help$
        ,line"-t  "
        ,line"-t    What?:  ZMOVE is a simple COM1: serial file transfer program, written in"
        ,line"-t            Forth and compiled with TCOM.  TCOM is an optimizing compiler for"
        ,line"-t            Forth programs. "
        ,line"-t  "
        ,line"-t   Author:  Tom Zimmer              TCOM & ZMOVE are public domain.  The"
        ,line"-t            292 Falcato Drive       source for this and 70+ other example"
        ,line"-t            Milpitas, Ca. 95035     programs are available for a US$60.00"
        ,line"-t            (408) 263-8859 eve      donation.  TCOM is also included."
        ,line"-t  "
        ,line"-t  Receive:  ZMOVE <enter>                     at 38k   baud"
        ,line"-t            ZMOVE /19200 <enter>              at 19.2k baud"
        ,line"-t            ZMOVE /9600  <enter>              at 9600  baud"
        ,line"-t  "
        ,line"-t     Send:  ZMOVE <filename> <enter>          at 38k   baud"
        ,line"-t            ZMOVE /19200 <filename> <enter>   at 19.2k baud"
        ,line"-t            ZMOVE /9600  <filename> <enter>   at 9600  baud"
        ,line"-t "

fload rs232ib.seq       \ need the serial routines

: COMM1:        ( -- )
                1 =: commport
                $10 imask !
                $64 comEOI !
                clr-buf
                comsave1 2@ d0=
                if      save_com1:
                        set_com1:       \ set our com1 interrupt vector
                        parity&bits rate 0 com-init     \ init the port 1
                then    ;

: ?kbdabort     ( -- )
                0 $41A @L 0 $41C @L <>
                if      key drop abort
                then    ;

257 array data_buf

: com-rec       ( -- char )     \  get a character from the buffer
                begin   ?kbdabort               \ poll for abort
                        com-cnt                 \ is buffer empty?
                until   bufout c@ 1+ 255 and
                combuf + c@                     \ get the byte
                1 bufout +! ;                   \ and increment the pointer

: com-put       ( char -- )     \ put one character to serial port
                com-out ;

handle rshndl
0 value blnk

: blink_it      ( -- )
                blnk 7 and 0=
                if      at? blnk 15 and 0=
                        if      ." ESC"
                        else    3 spaces
                        then    at
                then    incr> blnk ;

: 0blnk         ( -- )
                8 !> blnk blink_it ;

: shand_shake   ( -- )          \ try upto three times to get in sync with
                clr-buf         \ remote computer
                10 0                            \ wait upto 10 seconds
                do      drop
                        $A5 com-put
                        10 0                    \ wait 1 second
                        do      com-cnt ?leave
                                1 tenths
                                ?kbdabort
                        loop    com-cnt
                        if      com-rec $5A =
                                if      undo exit       \ leave, we linked up
                                else    clr-buf
                                then
                        then
                loop    true abort" Couldn't get in sync with remote" ;

: rhand_shake   ( -- f1 )       \ f1=true if got a file to transfer
                clr-buf
                begin   com-cnt 0=
                        if      1 tenths
                                blink_it
                                ?kbdabort
                        else    com-rec $A5 =
                                if      $5A com-put
                                        0blnk
                                        true exit       \ have a file
                                else    $FF com-put     \ keep trying
                                then
                        then
                again   ;

: ">send        ( a1 n1 -- f1 ) \ send a string to remote
                dup com-put     \ return f1=true on error
                swap over bounds
                ?do     i c@ +
                        i c@ com-put            \ send the characters
                loop    $FF and dup com-put     \ and send the checksum
                com-rec <> ;                    \ return true if error

: rec>receive   ( -- )       \ receive data into a buffer
                0 com-rec dup>r 1+ 1
                ?do     com-rec dup i data_buf + c! +
                        i data_buf c!
                loop    r> + $FF and com-rec dup com-put <>
                abort" Received bad checksum" ;

: name>send     ( a1 -- )       \ send string a1 as the filename
                $A1 com-put com-rec $1A =       \ send the command type
                if      dup count cr ."  Sending: " type space
                        >pathend" ">send
                else    drop true
                then    abort"  Failed to send name" ;

: name>receive  ( -- )
                com-rec $A1 =
                if      $1A com-put
                        rec>receive
                        cr ."  Receiving: " data_buf count type space
                        data_buf rshndl $>handle
                else    $FF com-put
                        true abort"  Failed to receive name"
                then    ;

: ?read_error   ( f1 -- )
                abort" Error reading file" ;

: ?send_error   ( f1 -- )
                abort" Error while sending a record" ;

: rec>send      ( n1 -- )
                ?dup 0= ?exit           \ leave if null length
                >r
                $A2 com-put
                data_buf r@ rshndl hread r@ <>  ?read_error
                com-rec $2A <>                  ?send_error
                data_buf r> ">send              ?send_error
                com-rec $2A <>                  ?send_error
                ;

0 value rcnt
0 value rtotal

: ?.recs        ( -- )
                rcnt 7 and 0=
                if      at? rcnt 8 / 1 .r ." k of " rtotal 1 .r ." k"
                        at
                then    incr> rcnt ;

: ?.recr        ( -- )
                rcnt 7 and 0=
                if      at? rcnt 8 / 1 .r ." k" at
                then    incr> rcnt ;

: data>send     ( -- )          \ send all contents of file
                rshndl endfile 128 um/mod dup 8 / !> rtotal 0
                0.0 rshndl movepointer
                do      ?.recs
                        i 128 um* rshndl movepointer    \ position into file
                        128 rec>send
                loop    ?.recs rec>send ;

: data>receive  ( -- )          \ receive all contents of file
                begin   com-rec dup $A3 <>
        [long]  while   $A2 =
        [long]          if      $2A com-put
                                ?.recr
                                rec>receive
                                data_buf count tuck rshndl hwrite <>
                                if      $FF com-put
                                        true abort" Write error"
                                then    $2A com-put
                        else    $FF com-put
                                true abort" Invalid transfer command"
                        then
                repeat  drop $3A com-put ;

: send_file     ( -- )  \ send one or more files to remote computer
        begin   off> rcnt                       \ reset record counter
                here rshndl $>handle            \ emplace name to our handle
                rshndl hopen abort"  Couldn't open file"
                shand_shake
                rshndl name>send
                $A4 com-put com-rec $4A <> abort" Failed to create file"
                data>send
                rshndl hclose drop
                $A3 com-put com-rec $3A <>      \ send end of transfer command
                abort" End of transfer error"
                bl word c@ 0=
        until   ;

: receive_file  ( -- )  \ receive one or more files from remote computer
        begin   off> rcnt                       \ reset record counter
                rhand_shake                     \ f1=true of another file
        while   name>receive
                com-rec $A4 <> abort" Failed to receive the create command"
                rshndl hcreate
                if      $FF com-put
                        true abort" Failed to create file"
                then    $4A com-put
                data>receive
                rshndl hclose drop
                at? swap 4 + swap at ."  DONE "
        repeat  ;

: zmove_abort   ( -- )          \ dis-connect serial interrupts and leave
                ?rest_com1:
                bye ;

: ??            ( -- )          \ ? display options
                >in @ bl word 1+ c@ '?' =
                here 1+ " /?" caps-comp 0= or
        [long]  if      drop
                        2000 0
                        do      ?cs: cs:help$ i + c@L
                                dup '' =
                                if      drop leave
                                then    dup $20 >=
                                if      emit
                                else    0Dh =
                                        if      cr
                                        then
                                then
                        loop    bye
                else    >in !
                then    ;

: ?/19200       ( -- )          \ /19200 display option
                >in @ bl word 1+ " /1" caps-comp 0=
                if      drop 19200 baud
                else    >in !
                then    ;

: ?/9600        ( -- )          \ /9600 display option
                >in @ bl word 1+ " /9" caps-comp 0=
                if      drop 9600 baud
                else    >in !
                then    ;

: .baud         ( -- )
                rate    ." at "
                case    3 of    38400   endof
                        6 of    19200   endof
                       12 of    9600    endof
                                drop
                endcase u. ." baud " ;

: main          ( -<filename>- )        \ send file to remote
                DECIMAL                         \ always select decimal
                INIT-CURSOR                     \ get intial cursor shape
                MARGIN_INIT                     \ initialize margins & TAB
                CAPS ON                         \ ignore cAsE
                ?DS: SSEG !                     \ init search segment
                DOSIO_INIT                      \ init EMIT, TYPE & SPACES
                $FFF0 SET_MEMORY                \ default to 64k code space
                DOS_TO_TIB                      \ move command tail to TIB
                38400 BAUD
                ??                              \ look for help request
                ?/19200
                ?/9600
                COMM1:                          \ initialize the ports speed
                ['] zmove_abort is abort_func   \ my abort function
                bl word c@
                if      ." Sending a file to COM1: " .baud
                        send_file
                else    ." Type:   ZMOVE /?   for more info, ESC=cancel" cr
                        ." Waiting for a file from COM1: " .baud
                        receive_file
                then    zmove_abort ;           \ restore vectors & leave

