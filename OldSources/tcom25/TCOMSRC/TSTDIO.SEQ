\\ TSTDIO.SEQ           Target Compiler Standard I/O    by Tom Zimmer

  Redirectable I/O      * STDIO *

  GETCHAR can be told to get its input from a pipe, or redirected input
  with either the "|" or "<" symbols at the DOS command line. These two
  symbols are used to redirect the STDIN handle to a file from the normal
  keyboard. STDIN is normally buffered, that is it reads a line at a time,
  then returns one character at a time till all characters of the line
  have been passed out. If you are using GETCHAR for its redirectability,
  and you want to use keyboard input as well, then you will probably want
  to tell DOS to use "raw" or "uncooked" I/O processing. This can be done
  with the RAW_I/O word at the beginning of your program to tell DOS to
  read characters one at a time, rather than a line at a time.


{

FORTH DECIMAL TARGET >LIBRARY       \ A library file

ICODE RAW_STDIN ( -- )          \ make DOS read STDIN one char    * STDIO *
                                \ at a time rather than a line at a time.
                MOV AX, # $4400
                MOV BX, # $00
                INT $21         \ get device information for STDIN
                MOV DH, # 0
                OR  DL, # $20   \ set RAW bit in control byte
                MOV AX, # $4401 \ set device information for STDIN
                INT $21
                RET             END-ICODE

ICODE GETCHAR   ( -- c1 )       \ c1 = char read from stdin       * STDIO *
                                \ return -1 if at end of file
                [ASSEMBLER]
                DEC SI
                DEC SI
                MOV 0 [SI], BX
                MOV CX, # 1             \ read one character
                MOV AH, # $3F           \ with a function $3F
                DEC SI
                DEC SI
                MOV DX, SI              \ room for char to be read
                MOV BX, # 0             \ from handle 0, stdin
                INT $21
             U< IF      LODSW                   \ if CF true
                        MOV BX, # -1            \ then return -1
                ELSE    CMP AX, # 0
                     0= IF      LODSW           \ if read no characters
                                MOV BX, # -1    \ then return -1
                        ELSE    LODSW           \ otherwise
                                MOV BX, AX      \ return AL on stack, in BX
                                SUB BH, BH
                        THEN
                THEN
                RET             END-ICODE

: STDIN_INIT    ( -- )          \ initialize input to use STDIN   * STDIO *
                RAW_STDIN
                ['] GETCHAR !> KEY ;

\ ***************************************************************************
\ un-buffered character output to STDIO.

ICODE PUTCHAR   ( c1 -- )       \ put one char to STDOUT          * STDIO *
                MOV DX, BX
                MOV AH, # 06
                INT $21
                LOAD_BX
                RET             END-ICODE

\ ***************************************************************************
\ Buffered character input. Use BUFIO_INIT before using GETCHAR_B OR
\ PUTCHAR_B, it initializes values, and allocated needed buffer space.

\ Performance is significantly affected by the size of the read and write
\ buffers. The default size works well, but a considerable improvement
\ in throughput can be obtained by increasing GCH.MAX and or PCH.MAX to
\ around 2000.  This will of course use more DS: memory.

\ If you are using PUTCHAR_B, be sure to use FLUSH_B before leaving to
\ return to DOS, it will flush any extra characters in the write buffer
\ to disk.

32 VALUE GCH.MAX       32 VALUE PCH.MAX
 0 VALUE GCH.OFF        0 VALUE GCH.LEN         0 VALUE GCH.BUF
 0 VALUE PCH.OFF                                0 VALUE PCH.BUF
  HANDLE GCH.HNDL        HANDLE PCH.HNDL

: BUFIO_INIT    ( -- )          \ Init buffered character I/O
                0 GCH.HNDL >HNDLE !
                1 PCH.HNDL >HNDLE !
                OFF> GCH.LEN    OFF> GCH.OFF
                                OFF> PCH.OFF
                GCH.MAX 1+ DS:ALLOC =: GCH.BUF   \ allocate at runtime
                PCH.MAX 1+ DS:ALLOC =: PCH.BUF ; \ allocate at runtime

: GETCHAR_B     ( -- c1 )       \ c1 = char read from stdin buffered   STDIO
                                \ return -1 if at end of file
                GCH.OFF GCH.LEN =
                IF      GCH.BUF GCH.MAX GCH.HNDL HREAD =: GCH.LEN
                        OFF> GCH.OFF
                THEN    GCH.LEN
                IF      GCH.BUF GCH.OFF + C@    \ return a character
                        INCR> GCH.OFF
                ELSE    -1                      \ return -1 if no characters
                THEN    ;




: FLUSH_B       ( -- )
                PCH.OFF ?DUP
                IF      PCH.BUF SWAP PCH.HNDL HWRITE DROP
                        OFF> PCH.OFF
                THEN    ;

: PUTCHAR_B     ( c1 -- )       \ buffered write of a character to STDIO
                PCH.BUF PCH.OFF + C!
                INCR> PCH.OFF
                PCH.OFF PCH.MAX >=
                IF      FLUSH_B
                THEN    ;


FORTH DECIMAL TARGET >TARGET

}
