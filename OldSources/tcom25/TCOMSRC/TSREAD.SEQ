\\ TSREAD.SEQ    Target sequential LINEREAD support

  LINEREAD support for TCOM. Be sure to use LINEREAD_INIT before trying
to use the LINEREAD function. Some extra DOS memory must be allocated for
the line read buffer which currently defaults to 8000 bytes.

  LINEREAD reads a line into the buffer OUTBUF, and can be upto 255
characters in length. If you lineread a file that does not contain LF
characters, then LINEREAD will automatically break up the file into
255 character lines. Not wonderful perhaps, but better than crashing.

  The read lines will still contain the CRLF character pairs at the
end of the line buffer. You will thus need to remove them before using
the line.

{

FORTH DECIMAL TARGET >LIBRARY   \ A Library file

8000 VALUE IBLEN                \ current input buffer length
 $0A CONSTANT DELIMITER
 255 CONSTANT OBLEN             \ output buffer length
  VARIABLE INSTART
  VARIABLE INLENGTH
  VARIABLE INBSEG               \ the input buffer
  VARIABLE LOADLINE
 2VARIABLE FILEPOINTER          \ most recent read
  VARIABLE LINE_LIMIT           \ line read limit of no LF detected

handle hndls                    \ only one "handles" for TCOM

b/hcb constant maxnest          \  maximum of 1 hcb's

0 value seqhandle

 oblen 1+ array outbuf

: .seqhandle   ( --- )
                seqhandle count type ;

: memchk        ( f1 -- )
                if      ." Insufficient Memory"
                        bye
                then ;

: IBRESET       ( --- )
                instart OFF
                inlength OFF
                loadline OFF ;

}

 Perform the following function, and then open a file on the handle
seqhandle. LINEREAD will read lines from this handle into the buffer called
OUTBUF. The address of OUTBUF is also returned by LINEREAD.

{

: LINEREAD_INIT ( -- )          \ initialize the LINEREAD system.
                seqhandle 0=
                if      hndls =: seqhandle
                        seqhandle clr-hcb
                        255 line_limit !
                then
                inbseg @ 0=
                if      iblen paragraph alloc 8 = memchk nip inbseg !
                then    ;

CODE CURPOINTER ( handle --- double-current )
                add bx, # hndloffset
                mov bx, 0 [bx]
                sub cx, cx
                mov dx, cx
                mov ax, # $4201  \ from end of file
                int $21
                dec si
                dec si
                mov 0 [si], ax
                mov bx, dx
                ret             end-code

: savepointer   ( --- )
                seqhandle curpointer inlength @ 0 d- filepointer 2! ;

code get_aline  ( --- a1 )
                save_bx
                push es                         \ Save ES for later restoral
                mov di, instart                 \ Searching from INSTART
                mov ax, # DELIMITER             \ Searching for line delimiter
                mov cx, inlength                \ for INLENGTH clipped to OBLEN
                cmp cx, line_limit              \ if INLENGTH > OBLEN
              > if      mov cx, line_limit      \ clip search to line_limit
                then    mov dx, cx              \ save search length in DX
          cx<>0 if      mov es, inbseg          \ searching INBSEG segment
                        repnz  scasb            \ Scan for Linefeed char
                then    sub dx, cx              \ DX = length of line
                sub inlength dx                 \ subtract line from remaining
                mov outbuf dl byte              \ set the length of OUTBUF
                mov bx, si                      \ save IP for later restoral
                mov si, instart                 \ moving from INSTART
                add instart dx                  \ set start to after line
                mov cx, dx                      \ cx = length to move
                mov di, # outbuf 1+             \ moving to OUTBUF
                mov dx, ds
                mov ds, inbseg                  \ from INBSEG segment
                mov es, dx
                TEST DI, # 1
                JZ 0 $
                JCXZ 0 $
                MOVSB
                DEC CX
        0 $:    SHR CX, # 1
                REPNZ           MOVSW
                RCL CX, # 1
                REPNZ           MOVSB
                mov ds, dx                      \ restore DS
                mov si, bx                      \ restore IP
                inc loadline word               \ bump line counter
                pop es                          \ restore ES
                mov bx, # outbuf                \ return address of buffer
                ret             end-code

: fillbuff      ( --- )         \ Refill the input buffer.
                inbseg @ instart @ over 0 inlength @ cmovel
                instart OFF
                inlength @ iblen inlength @ -
                seqhandle inbseg @ exhread      \ perform the actual read
                inlength +!                   \ adjust buffer length
                savepointer ;

code ?fillbuff  ( --- f1 )              \ f1 = true if refill needed
                save_bx
                mov cx, line_limit              \ get longest allowed line
                cmp inlength cx
            u>= if      mov di, # filepointer   \ Set BX to point to FILEPOINTER
                        sub cx, cx              \ clear CX
                        mov cl, outbuf          \ read byte length of OUTBUF
                        add 2 [di], cx          \ Add to 32bit contents
                        adc 0 [di], # 0
                        mov bx, # 0
                        ret
                then                            \ If we got here, then
                mov bx, # -1                    \ go and re-fill the buffer
                ret     end-code

: LINEREAD      ( --- a1 )      \ read a line delimited by crlf
                ?fillbuff       \ re-fill buffer if needed.
                if      fillbuff
                then
                get_aline ;     \ returns line including CRLF

: SEQUP         ( --- )
                lineread_init
                true abort" No more handles available!" ;

: "HOPEN        ( a1 n1 --- f1 ) \ Returns a boolean FALSE for open successful
                lineread_init
                seqhandle hclose drop
                seqhandle ">handle
                seqhandle hopen
                ibreset ;

: $HOPEN        ( a1 -- f1 )    \ Open a file for line reading
                count "hopen ;

: $FILE         ( A1 --- F1 )
                count "hopen
                0.0 seqhandle movepointer       \ reset to beginning of file
                0.0 filepointer 2!
                loadline off                    \ reset file offset
                ibreset ;

: ?OPEN.ERROR   ( f1 --- )
                abort" Open Error!" ;

: SEQDOWN       ( --- )
                lineread_init
                seqhandle hclose drop           \ close the file
                seqhandle clr-hcb ;             \ clear the handle

: CLOSE         ( --- )
                seqdown ;

: ?FILEOPEN     ( --- )                 \ Verify a file is open.
                seqhandle >hndle @ 0<
                abort" A file MUST be open to perform this operation." ;

FORTH TARGET >TARGET

}

